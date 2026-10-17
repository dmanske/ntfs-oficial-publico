#!/bin/bash
# Teste da montagem automática (fase 1), imitando plugar um HD NTFS. Não usa disco de verdade.
# 1. cria uma imagem GPT com partição de dados do Windows, formatada com o nosso mkntfs
# 2. anexa normalmente: o macOS escolhe quem monta (esperado: ntfsoficial, em /Volumes/TESTE OFICIAL)
# 3. grava, ejeta e confere o volume
set -euo pipefail
source "$(dirname "$0")/config.sh"

T="${BUILD}/teste"; IMG="${T}/auto.dmg"; ROTULO="TESTE OFICIAL"; PONTO="/Volumes/${ROTULO}"
mkdir -p "${T}"
passo() { echo; echo "==> $*"; }

passo "Criando imagem de teste (GPT + Microsoft Basic Data, NTFS \"${ROTULO}\")"
hdiutil create -quiet -size 200m -layout GPTSPUD -partitionType "Microsoft Basic Data" -ov "${IMG}"
PART="$(hdiutil attach -nomount "${IMG}" 2>/dev/null | awk '/Microsoft Basic Data/ {print $1}')"
"${SAIDA}/bin/mkntfs" -Q -L "${ROTULO}" "${PART}" > /dev/null 2>&1
hdiutil detach -quiet "${PART%s*}"

passo "Anexando como um HD plugado"
INICIO="$(date '+%Y-%m-%d %H:%M:%S')"
hdiutil attach "${IMG}" > /dev/null
for _ in $(seq 1 20); do mount | grep -q "on ${PONTO} " && break; sleep 1; done
LINHA="$(mount | grep "on ${PONTO} " || true)"
echo "${LINHA:-não montou em ${PONTO}}"
/usr/bin/log show --start "${INICIO}" --style compact --predicate "subsystem == \"${IDENTIFICADOR}\"" 2>/dev/null | tail -n +2 | cut -c1-220

case "${LINHA}" in
    *"(${NOME},"*) echo "OK: montado pelo NTFS Oficial" ;;
    *) echo "FALHOU: não foi o NTFS Oficial que montou"; hdiutil detach -quiet "${PART%s*}" || true; exit 1 ;;
esac

passo "Gravando como usuário comum (sem sudo)"
echo "ola" > "${PONTO}/teste.txt"
mkdir "${PONTO}/pasta acentuação"
dd if=/dev/urandom of="${T}/auto.bin" bs=1m count=30 2>/dev/null
cp "${T}/auto.bin" "${PONTO}/pasta acentuação/"
cmp "${T}/auto.bin" "${PONTO}/pasta acentuação/auto.bin" && echo "cópia de 30 MB idêntica"
ls -la "${PONTO}"

passo "Ejetando como no Finder"
diskutil eject "${PART%s*}"

passo "Conferindo o volume"
PART="$(hdiutil attach -nomount "${IMG}" 2>/dev/null | awk '/Microsoft Basic Data/ {print $1}')"
"${SAIDA}/bin/ntfsls" -R "${PART}" | head -20
CK=0; "${BUILD}/rea/bin/ntfsck_2027.0.1_arm64" -s -P "${PART}" > "${T}/ntfsck-auto.txt" 2>&1 || CK=$?
grep -E 'journal|rror|orrupt|Done' "${T}/ntfsck-auto.txt" || true
echo "ntfsck do Tuxera: código ${CK} (101 = sem erro, só mudaria o journal)"
hdiutil detach -quiet "${PART%s*}"
echo; echo "Teste concluído."
