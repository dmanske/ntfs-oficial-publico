#!/bin/bash
# Mede gravação e leitura num volume NTFS montado (sem sudo). Grava um arquivo de teste, confere o hash e apaga.
#   bash scripts/medir-velocidade.sh /Volumes/Filmes [tamanho_em_MB]
# A leitura é medida depois de desmontar e montar de novo (para não ler do cache da memória).
set -euo pipefail
source "$(dirname "$0")/config.sh"

PONTO="${1:?informe o ponto de montagem, ex.: /Volumes/Filmes}"
MB="${2:-2048}"
T="${BUILD}/teste"; ORIGEM="${T}/vel-${MB}m.bin"; DESTINO="${PONTO}/_teste_velocidade_${NOME}.bin"
mkdir -p "${T}"
agora() { python3 -I -c 'import time; print(time.time())'; }
taxa()  { python3 -I -c "import sys; d=float(sys.argv[2])-float(sys.argv[1]); print(f'{int(sys.argv[3])/d:7.1f} MB/s  ({d:.1f} s)')" "$1" "$2" "$MB"; }

DISCO="$(mount | awk -v p="${PONTO}" '$3==p {print $1}')"
[ -n "${DISCO}" ] || { echo "ERRO: nada montado em ${PONTO}"; exit 1; }
echo "Volume: ${PONTO} (${DISCO}) — $(mount | grep " on ${PONTO} " | sed 's/.*(//;s/)//')"

[ -f "${ORIGEM}" ] || dd if=/dev/urandom of="${ORIGEM}" bs=1m count="${MB}" 2>/dev/null
HASH="$(shasum -a 256 "${ORIGEM}" | cut -c1-16)"

t0="$(agora)"; cp "${ORIGEM}" "${DESTINO}"; sync; t1="$(agora)"
echo "Gravação ${MB} MB: $(taxa "$t0" "$t1" )"

diskutil unmount "${DISCO}" >/dev/null && diskutil mount "${DISCO}" >/dev/null
t0="$(agora)"; cat "${DESTINO}" > /dev/null; t1="$(agora)"
echo "Leitura  ${MB} MB: $(taxa "$t0" "$t1")"

DEPOIS="$(shasum -a 256 "${DESTINO}" | cut -c1-16)"
[ "${HASH}" = "${DEPOIS}" ] && echo "Hash: igual (${HASH})" || echo "ERRO: hash diferente (${HASH} != ${DEPOIS})"
rm "${DESTINO}"
echo "Arquivo de teste apagado."
