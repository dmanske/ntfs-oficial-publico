#!/bin/bash
# Testa um pedido interrompido antes de o driver recebê-lo (kext 0.1.2, patch 0008): um programa espera o disco NTFS,
# é encerrado (kill -9) e tem que sair na hora, e o disco tem que continuar funcionando depois.
# Até o kext 0.1.1 isso girava para sempre dentro do kext, segurando a trava do pedido, e o disco inteiro travava até
# reiniciar (Hackintosh, MirrorDisplays, 20/10/2026; docs/correcoes/2026-10-20_disco-travado-ao-encerrar-programa.md).
# ATENÇÃO: com o kext 0.1.1 carregado este teste trava o disco de teste e um núcleo do processador até reiniciar. Por
# isso só roda se o kext carregado for o VERSAO_KEXT do config.sh.
#   bash scripts/testar-interrupcao.sh            o teste
#   bash scripts/testar-interrupcao.sh --ensaio   tudo menos o kill -9 (confere o roteiro; serve com qualquer kext)
#   DRV=<driver>                                  outro driver (padrão: build/out/bin/ntfsoficial)
# Como: pausa o driver (kill -STOP); o stat A pode ainda ser entregue ao driver antes de ele parar; o stat B fica
# garantidamente na fila, sem ser enviado. Mata o B, confere que saiu, solta o driver e confere que o disco responde.
# Usa uma imagem de disco em build/teste (nada de disco real), sem sudo. Monta sem "local" e com "nobrowse" para o
# Spotlight e o Finder não pedirem nada ao disco enquanto o driver está pausado.
set -euo pipefail
source "$(dirname "$0")/config.sh"
ENSAIO=0; [ "${1:-}" = "--ensaio" ] && ENSAIO=1

CARREGADA="$(sysctl -n "vfs.generic.${NOME}.version.number" 2>/dev/null || true)"
if [ "${ENSAIO}" = 0 ] && [ "${CARREGADA}" != "${VERSAO_KEXT}" ]; then
    echo "ERRO: kext carregado '${CARREGADA:-nenhum}', este teste pede o ${VERSAO_KEXT}. Com o 0.1.1 ele trava o disco de teste; não rodei."
    echo "      (--ensaio roda tudo menos o kill -9)"
    exit 1
fi

# Vivo = existe e não é zumbi. Preso no kext depois do kill -9 aparece como E ("trying to exit") no ps.
vivo() { local s; s="$(ps -o stat= -p "$1" 2>/dev/null | tr -d ' ')"; [ -n "$s" ] && [[ "$s" != Z* ]]; }
esperar_sair() { for _ in $(seq 1 "$2"); do vivo "$1" || return 0; sleep 0.2; done; ! vivo "$1"; }

T="${BUILD}/teste"; M="${T}/montar-interrupcao"; DRV="${DRV:-${SAIDA}/bin/${NOME}}"
mkdir -p "${T}" "${M}"
DRV_PID=""; A_PID=""; B_PID=""
limpar() {
    [ -n "${DRV_PID}" ] && kill -CONT "${DRV_PID}" 2>/dev/null || true
    for p in ${A_PID} ${B_PID}; do wait "$p" 2>/dev/null || true; done
    umount "${M}" 2>/dev/null || diskutil unmount force "${M}" > /dev/null 2>&1 || true
    [ -n "${P:-}" ] && hdiutil detach -quiet "${P%s*}" 2>/dev/null || true
}
trap limpar EXIT

echo "==> Criando e montando o disco de teste (kext carregado: ${CARREGADA:-nenhum})"
hdiutil create -quiet -size 100m -layout GPTSPUD -partitionType "Microsoft Basic Data" -ov "${T}/interrupcao.dmg"
P="$(hdiutil attach -nomount "${T}/interrupcao.dmg" 2>/dev/null | awk '/Microsoft Basic Data/ {print $1}')"
"${SAIDA}/bin/mkntfs" -Q -L "TESTE INTERRUPCAO" "$P" > /dev/null 2>&1
"${DRV}" "$P" "${M}" -o nobrowse,uid="$(id -u)",gid="$(id -g)" > /dev/null 2>&1; sleep 1
mount | grep -qF " on ${M} (" || { echo "ERRO: o disco de teste não montou em ${M}"; exit 1; }
printf 'ntfs oficial\n' > "${M}/arquivo.txt"
DRV_PID="$(pgrep -f -- "${P} ${M}" || true)"
[ "$(echo "${DRV_PID}" | wc -w | tr -d ' ')" = 1 ] || { echo "ERRO: não achei um driver só para ${M} (${DRV_PID:-nenhum})"; exit 1; }

echo "==> Pausando o driver (${DRV_PID}) e pedindo ao disco"
kill -STOP "${DRV_PID}"
stat "${M}/nao-existe-a-$$" > /dev/null 2>&1 & A_PID=$!
sleep 1
stat "${M}/nao-existe-b-$$" > /dev/null 2>&1 & B_PID=$!
sleep 1
FALHOU=0
if ! vivo "${B_PID}"; then
    echo "FALHA: o stat B não ficou esperando o driver (o teste não passou pelo caminho do travamento)"; FALHOU=1
elif [ "${ENSAIO}" = 1 ]; then
    echo "ok    stat B esperando o driver (ensaio: não mato)"
else
    kill -9 "${B_PID}" 2>/dev/null || true
    if esperar_sair "${B_PID}" 10; then
        echo "ok    stat B encerrado saiu na hora, com o pedido ainda na fila do driver"
    else
        echo "FALHA: o stat B encerrado continua preso no kext depois de 2 s (ps: $(ps -o stat= -p "${B_PID}"))"; FALHOU=1
    fi
fi

echo "==> Soltando o driver"
kill -CONT "${DRV_PID}"; SOLTO="${DRV_PID}"; DRV_PID=""
for nome in A B; do
    pid="$([ "$nome" = A ] && echo "${A_PID}" || echo "${B_PID}")"
    [ "$nome" = B ] && [ "${ENSAIO}" = 0 ] && continue
    if esperar_sair "${pid}" 25; then echo "ok    stat ${nome} respondido"; else echo "FALHA: o stat ${nome} não terminou depois de soltar o driver"; FALHOU=1; fi
done
if [ "$(cat "${M}/arquivo.txt" 2>/dev/null)" = "ntfs oficial" ] && ls "${M}" > /dev/null 2>&1; then
    echo "ok    disco responde depois (driver ${SOLTO})"
else
    echo "FALHA: o disco não responde depois de soltar o driver"; FALHOU=1
fi

[ "${FALHOU}" = 0 ] && echo "==> Passou" || { echo "==> Falhou"; exit 1; }
