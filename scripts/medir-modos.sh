#!/bin/bash
# Compara gravação assíncrona (padrão: EnableCaching = 1 -> nosyncwrites) e síncrona (como o Tuxera monta: o kext
# só liga MNT_ASYNC com nosyncwrites, e nenhum programa do Tuxera passa essa opção; REA, 18/10/2026).
# Sem sudo: o modo síncrono é ligado pelo arquivo de controle /.NTFS-Oficial/disable-caching no próprio disco,
# que é apagado no fim.
#   bash scripts/medir-modos.sh /Volumes/Filmes [MB_do_arquivo_grande] [quantidade_de_arquivos_pequenos]
set -euo pipefail
source "$(dirname "$0")/config.sh"

PONTO="${1:?informe o ponto de montagem, ex.: /Volumes/Filmes}"
MB="${2:-2048}"; N="${3:-3000}"
DISCO="$(mount | awk -v p="${PONTO}" '$3==p {print $1}')"
[ -n "${DISCO}" ] || { echo "ERRO: nada montado em ${PONTO}"; exit 1; }
CONTROLE="${PONTO}/.NTFS-Oficial/disable-caching"
remontar() { diskutil unmount "${DISCO}" >/dev/null && diskutil mount "${DISCO}" >/dev/null; }
modo() { mount | grep " on ${PONTO} " | grep -o -E 'asynchronous|synchronous' | head -1; }
[ -e "${CONTROLE}" ] && { echo "ERRO: ${CONTROLE} já existe; apague antes"; exit 1; }
trap 'rm -f "${CONTROLE}"; rmdir "${PONTO}/.NTFS-Oficial" 2>/dev/null || true' EXIT

medir() {
    echo; echo "######## $(modo) ########"
    bash "${RAIZ}/scripts/medir-velocidade.sh" "${PONTO}" "${MB}"
    bash "${RAIZ}/scripts/medir-arquivos-pequenos.sh" "${PONTO}" "${N}"
}

medir
mkdir -p "${PONTO}/.NTFS-Oficial"; : > "${CONTROLE}"; remontar
[ "$(modo)" = synchronous ] || { echo "ERRO: não montou síncrono (modo: $(modo))"; exit 1; }
medir
rm -f "${CONTROLE}"; rmdir "${PONTO}/.NTFS-Oficial" 2>/dev/null || true; remontar
echo; echo "Volta ao padrão: $(modo)"
