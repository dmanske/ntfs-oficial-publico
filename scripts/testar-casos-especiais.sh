#!/bin/bash
# Testa os casos especiais da montagem automática com discos de teste (nada de disco real), sem sudo:
#   hibernado  -> NTFS Oficial monta SÓ LEITURA e mostra o aviso "montado só para leitura"
#   sujo       -> idem (journal pendente; com EnableAutomaticRecovery = 0, o padrão)
#   controle   -> /.NTFS-Oficial/disable-driver: o disco fica para o NTFS só leitura da Apple
# Cada disco é anexado como um HD plugado (o macOS decide quem monta) e depois ejetado.
# Atenção: nos dois primeiros aparece a janela de aviso na tela (clicar OK).
set -euo pipefail
source "$(dirname "$0")/config.sh"

T="${BUILD}/teste"; M="${T}/montar-caso"; DRV="${SAIDA}/bin/${NOME}"
mkdir -p "${T}" "${M}"

criar() {  # criar <nome> <rótulo> -> imprime a partição (anexada sem montar)
    hdiutil create -quiet -size 100m -layout GPTSPUD -partitionType "Microsoft Basic Data" -ov "${T}/$1.dmg"
    local p; p="$(hdiutil attach -nomount "${T}/$1.dmg" 2>/dev/null | awk '/Microsoft Basic Data/ {print $1}')"
    "${SAIDA}/bin/mkntfs" -Q -L "$2" "$p" > /dev/null 2>&1
    echo "$p"
}
com_volume() {  # com_volume <partição> <comando python sobre o ponto em sys.argv[1]>
    "${DRV}" "$1" "${M}" -o local,uid="$(id -u)",gid="$(id -g)",norecover > /dev/null 2>&1; sleep 1
    python3 -I -c "$2" "${M}"; umount "${M}"; sleep 1
}

echo "==> Criando os discos de teste"
P="$(criar hibernado "TESTE HIBERNADO")"
com_volume "$P" "import sys,os; open(os.path.join(sys.argv[1],'hiberfil.sys'),'wb').write(b'hibr'+bytes(8188))"
hdiutil detach -quiet "${P%s*}"

P="$(criar sujo "TESTE SUJO")"
LCN="$("${SAIDA}/bin/ntfsinfo" -v -F '$LogFile' "$P" 2>/dev/null | awk '/Runlist/ {getline; if (!achou) {print $2; achou = 1}}')"
python3 -I -c "import os,sys; f=os.open(sys.argv[1],os.O_RDWR); os.pwrite(f,b'RSTR'+os.urandom(8188),int(sys.argv[2],16)*4096); os.close(f)" "$P" "$LCN"
hdiutil detach -quiet "${P%s*}"

P="$(criar controle "TESTE CONTROLE")"
com_volume "$P" "import sys,os; os.makedirs(os.path.join(sys.argv[1],'.NTFS-Oficial')); open(os.path.join(sys.argv[1],'.NTFS-Oficial','disable-driver'),'w').close()"
hdiutil detach -quiet "${P%s*}"

FALHAS=0
for caso in "hibernado:${NOME}:ro" "sujo:${NOME}:ro" "controle:ntfs:ro"; do
    IFS=: read -r nome tipo_esperado modo <<< "${caso}"
    ROT="$(echo "TESTE ${nome}" | tr '[:lower:]' '[:upper:]')"; PONTO="/Volumes/${ROT}"
    INICIO="$(date '+%Y-%m-%d %H:%M:%S')"
    hdiutil attach "${T}/${nome}.dmg" > /dev/null 2>&1 || true
    for _ in $(seq 1 15); do mount | grep -q "on ${PONTO} " && break; sleep 1; done
    LINHA="$(mount | grep "on ${PONTO} " || true)"
    TIPO="$(echo "${LINHA}" | sed -n 's/.*(\([^,]*\),.*/\1/p')"
    if echo x > "${PONTO}/t.txt" 2>/dev/null; then GRAVA="gravou"; else GRAVA="não gravou"; fi
    AVISO="$(/usr/bin/log show --start "${INICIO}" --style compact --predicate "subsystem == \"${IDENTIFICADOR}\"" 2>/dev/null | grep -c 'caiu para só leitura\|montando só para leitura' || true)"
    OK="ok"; { [ "${TIPO}" = "${tipo_esperado}" ] && [ "${GRAVA}" = "não gravou" ]; } || { OK="FALHOU"; FALHAS=$((FALHAS + 1)); }
    echo "== ${nome}: montado por '${TIPO:-ninguém}' (esperado '${tipo_esperado}'), ${GRAVA}, aviso registrado: ${AVISO} -> ${OK}"
    DISCO="$(echo "${LINHA}" | awk '{print $1}')"
    [ -n "${DISCO}" ] && { diskutil eject "${DISCO%s*}" > /dev/null 2>&1 || hdiutil detach -quiet "${PONTO}" || true; }
    sleep 2
done
echo; [ "${FALHAS}" = 0 ] && echo "Todos os casos ok." || { echo "${FALHAS} caso(s) falharam."; exit 1; }
