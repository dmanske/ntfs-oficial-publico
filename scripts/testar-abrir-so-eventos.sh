#!/bin/bash
# Testa a abertura "só para eventos" que o compartilhamento de arquivos (smbd) faz nos discos NTFS quando outro Mac
# abre o disco pela rede: O_EVTONLY | O_SYMLINK com a política que tira a leitura e a escrita (o VNOP_OPEN chega ao
# kext com 0x208000). A política pede um entitlement da Apple, então o teste soma O_EXEC, que também chega sem leitura
# nem escrita (0x40208000) e cai no mesmo ramo do kext. Até o kext 0.1.1 isso era panic; o patch 0007 (kext 0.1.2)
# trata como só leitura, como o Tuxera.
# ATENÇÃO: com o kext 0.1.1 carregado o teste derruba o Mac. Por isso só roda se o kext carregado for o VERSAO_KEXT
# do config.sh (instalar com scripts/instalar.sh --kext-novo, aprovar em Ajustes e reiniciar antes).
# Usa uma imagem de disco em build/teste (nada de disco real), sem sudo. Programa: scripts/diagnostico/abrir_so_eventos.c.
set -euo pipefail
source "$(dirname "$0")/config.sh"

CARREGADA="$(sysctl -n "vfs.generic.${NOME}.version.number" 2>/dev/null || true)"
if [ "${CARREGADA}" != "${VERSAO_KEXT}" ]; then
    echo "ERRO: kext carregado '${CARREGADA:-nenhum}', este teste pede o ${VERSAO_KEXT}. Com o 0.1.1 ele causa panic; não rodei."
    exit 1
fi

T="${BUILD}/teste"; M="${T}/montar-evtonly"; PROG="${T}/abrir_so_eventos"
mkdir -p "${T}" "${M}"
clang -std=gnu17 -O2 -Wall -Werror "${RAIZ}/scripts/diagnostico/abrir_so_eventos.c" -o "${PROG}"

echo "==> Criando e montando o disco de teste"
hdiutil create -quiet -size 100m -layout GPTSPUD -partitionType "Microsoft Basic Data" -ov "${T}/evtonly.dmg"
P="$(hdiutil attach -nomount "${T}/evtonly.dmg" 2>/dev/null | awk '/Microsoft Basic Data/ {print $1}')"
trap 'umount "${M}" 2>/dev/null || true; hdiutil detach -quiet "${P%s*}" 2>/dev/null || true' EXIT
"${SAIDA}/bin/mkntfs" -Q -L "TESTE EVTONLY" "$P" > /dev/null 2>&1
"${SAIDA}/bin/${NOME}" "$P" "${M}" -o local,uid="$(id -u)",gid="$(id -g)" > /dev/null 2>&1; sleep 1
mount | grep -qF " on ${M} (" || { echo "ERRO: o disco de teste não montou em ${M}"; exit 1; }
printf 'ntfs oficial\n' > "${M}/arquivo.txt"; mkdir "${M}/pasta"; ln -s arquivo.txt "${M}/atalho"

echo "==> Abrindo como o smbd"
INICIO="$(date '+%Y-%m-%d %H:%M:%S')"
FALHOU=0
"${PROG}" "${M}/arquivo.txt" "${M}/pasta" || FALHOU=1
echo "    link simbólico (só mostra; o driver pode recusar o open do próprio link):"
"${PROG}" -i "${M}/atalho"
[ "$(cat "${M}/arquivo.txt")" = "ntfs oficial" ] || { echo "FALHA: o conteúdo do arquivo mudou"; FALHOU=1; }

# open e close no mesmo fufh: se não casarem, o kext reclama no fechamento
AVISOS="$(log show --start "${INICIO}" --style compact --predicate "eventMessage CONTAINS \"${NOME}: fufh invalid\"" 2>/dev/null \
    | grep -c "fufh invalid" || true)"
if [ "${AVISOS}" != 0 ]; then echo "FALHA: ${AVISOS} avisos 'fufh invalid' do kext no log"; FALHOU=1; fi

[ "${FALHOU}" = 0 ] && echo "==> Passou: nenhuma abertura derrubou o kext" || { echo "==> Falhou"; exit 1; }
