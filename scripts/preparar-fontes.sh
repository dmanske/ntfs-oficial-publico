#!/bin/bash
# Prepara os fontes de terceiros em build/src, sem tocar em terceiros/:
# 1. copia osxfuse (common, kext, fuse, support) e ntfs-3g
# 2. troca os nomes do osxfuse pelos de scripts/config.sh (o mesmo nome no kext, na libfuse e nas ferramentas)
# 3. aplica as correções em kext/patches/*.patch e driver/patches/*.patch
set -euo pipefail
source "$(dirname "$0")/config.sh"

OSX="${FONTES}/osxfuse"
NTFS="${FONTES}/ntfs-3g"
MAIUSC="$(echo "${NOME}" | tr '[:lower:]' '[:upper:]')"

echo "==> Copiando fontes para ${FONTES}"
mkdir -p "${FONTES}"
rsync -a --delete --exclude .git "${TERCEIROS}/osxfuse/" "${OSX}/"
rsync -a --delete --exclude .git "${TERCEIROS}/ntfs-3g/" "${NTFS}/"

echo "==> Trocando nomes: osxfuse -> ${NOME}"
# Nomes centrais (dispositivo, tipo do sistema de arquivos, sysctl, volume, identificador, versão)
V="${OSX}/common/fuse_version.h"
sed -i '' \
    -e "s/^#define OSXFUSE_NAME_LITERAL .*/#define OSXFUSE_NAME_LITERAL                ${NOME}/" \
    -e "s/^#define OSXFUSE_DISPLAY_NAME_LITERAL .*/#define OSXFUSE_DISPLAY_NAME_LITERAL        ${NOME_EXIBICAO}/" \
    -e "s/^#define OSXFUSE_IDENTIFIER_LITERAL .*/#define OSXFUSE_IDENTIFIER_LITERAL          ${IDENTIFICADOR}/" \
    -e "s/^#define OSXFUSE_VERSION_LITERAL .*/#define OSXFUSE_VERSION_LITERAL             ${VERSAO}/" \
    -e "s/^#define OSXFUSE_TIMESTAMP .*/#define OSXFUSE_TIMESTAMP                   \"sem data\"/" \
    "${V}"
# Sem __DATE__/__TIME__ no kext: o mesmo código gera o mesmo kext (mesmo CDHash), e o macOS não pede
# nova aprovação + reinício só porque foi recompilado.
# Caminhos do pacote, do kext e dos programas de carregar e montar.
# Os auxiliares do FUSE ficam em Contents/Resources/Support/ (como o Tuxera: Support/10.9/mount_tuxera_ntfs),
# porque Contents/Resources/mount_ntfsoficial é o nosso despachante, que o macOS chama para montar.
P="${OSX}/common/fuse_param.h"
sed -i '' \
    -e "s#/Library/Filesystems/osxfuse.fs#${PACOTE_FS}#" \
    -e "s#\"osxfuse.kext\"#\"${NOME}.kext\"#" \
    -e "s#/load_osxfuse\"#/Support/load_${NOME}\"#" \
    -e "s#/mount_osxfuse\"#/Support/mount_${NOME}\"#" \
    "${P}"
# Identificador do kext
PBX="${OSX}/kext/osxfuse.xcodeproj/project.pbxproj"
sed -i '' -e "s/MODULE_NAME = com.github.osxfuse.filesystems.osxfuse;/MODULE_NAME = ${IDENTIFICADOR}.filesystems.${NOME};/" "${PBX}"
# Mensagens de log e grupos de trava do kext (para não confundir com o macFUSE instalado)
sed -i '' -e "s/\"osxfuse/\"${NOME}/g" "${OSX}"/kext/osxfuse/*.c "${OSX}"/kext/osxfuse/*.h
# Variáveis de ambiente entre a libfuse e o mount (o Tuxera usa MOUNT_TUXERA_NTFS_*) e sysctl fixo
for f in "${OSX}"/fuse/lib/*.c "${OSX}"/support/mount_osxfuse/*.c "${OSX}"/support/load_osxfuse/*.c; do
    sed -i '' \
        -e "s/MOUNT_OSXFUSE_/MOUNT_${MAIUSC}_/g" \
        -e "s/vfs\.generic\.osxfuse\./vfs.generic.${NOME}./g" \
        "$f"
done

# Confere se a troca pegou (se o osxfuse mudar o formato, o script para aqui)
grep -q "OSXFUSE_NAME_LITERAL *${NOME}$" "${V}" || { echo "ERRO: nome não trocado em ${V}"; exit 1; }
grep -q "${PACOTE_FS}" "${P}" || { echo "ERRO: caminho não trocado em ${P}"; exit 1; }
grep -q "MODULE_NAME = ${IDENTIFICADOR}" "${PBX}" || { echo "ERRO: MODULE_NAME não trocado"; exit 1; }
if grep -rq -E 'MOUNT_OSXFUSE_|vfs\.generic\.osxfuse\.' "${OSX}/fuse/lib" "${OSX}/support"; then
    echo "ERRO: sobrou nome do osxfuse na libfuse ou nas ferramentas"; exit 1
fi

# Macros do autoconf que o NTFS-3G pede e que não precisamos instalar (ver driver/m4/)
cp "${RAIZ}"/driver/m4/*.m4 "${NTFS}/m4/"

shopt -s nullglob
for p in "${RAIZ}"/kext/patches/*.patch; do
    echo "==> Aplicando $(basename "$p")"
    patch -d "${OSX}" -p1 --forward --silent < "$p"
done
for p in "${RAIZ}"/driver/patches/*.patch; do
    echo "==> Aplicando $(basename "$p")"
    patch -d "${FONTES}" -p1 --forward --silent < "$p"
done
echo "==> Fontes prontos em ${FONTES}"
