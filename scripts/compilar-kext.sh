#!/bin/bash
# Compila o kext ntfsoficial (osxfuse 3 renomeado) universal (arm64e + x86_64) e assina ad-hoc.
# Não carrega nada no kernel. Os fontes vêm de scripts/preparar-fontes.sh.
set -euo pipefail
source "$(dirname "$0")/config.sh"
[ "${PULAR_PREPARO:-0}" = 1 ] || bash "${RAIZ}/scripts/preparar-fontes.sh"

ORIGEM="${FONTES}/osxfuse"

# Avisos novos do clang do Xcode 27 que o código de 2018 dispara sem ser erro de verdade.
# O projeto trata aviso como erro (-Werror), então cada um é desligado aqui com o motivo:
#   uninitialized-const-pointer: fuse_device.c passa &ohead para uiomove(), que é quem preenche
AVISOS_DESLIGADOS="-Wno-uninitialized-const-pointer"

# Um xcodebuild por arquitetura: com várias de uma vez o Xcode recusa o Info.plist do kext, porque o
# pré-processador (que puxa os cabeçalhos do kernel) gera texto diferente em arm64e e x86_64.
# O kext final é o da primeira arquitetura da lista, com o executável trocado por um "lipo -create"
# dos executáveis de todas, e assinado de novo.
mkdir -p "${SAIDA}/kext"
LOG="${BUILD}/kext-build.log"; : > "${LOG}"
PRIMEIRA=""; EXECUTAVEIS=()
for ARQ in ${ARQUITETURAS_KEXT}; do
    echo "==> Compilando kext (${ARQ}, macOS ${MACOS_MINIMO}+)"
    if [ -z "${PRIMEIRA}" ]; then PRIMEIRA="${ARQ}"; DESTINO="${SAIDA}/kext"; else DESTINO="${BUILD}/obj/kext-saida-${ARQ}"; fi
    # Sempre do zero: o Info.plist do kext pega a versão de um cabeçalho (#include <fuse_version.h>) e o Xcode não
    # refaz o Preprocessed-Info.plist quando só o cabeçalho muda (18/10/2026: kext 0.1.1 saiu com CFBundleVersion 0.1.0)
    rm -rf "${BUILD}/obj/kext-${ARQ}"
    mkdir -p "${BUILD}/obj/kext-${ARQ}"
    if ! xcodebuild -project "${ORIGEM}/kext/osxfuse.xcodeproj" -target osxfuse -configuration Release \
            ARCHS="${ARQ}" VALID_ARCHS="${ARQ}" ONLY_ACTIVE_ARCH=NO \
            MACOSX_DEPLOYMENT_TARGET="${MACOS_MINIMO}" OSXFUSE_VERSION="${VERSAO_KEXT}" \
            PRODUCT_NAME="${NOME}" CODE_SIGN_IDENTITY="${ASSINATURA}" \
            WARNING_CFLAGS="\$(inherited) ${AVISOS_DESLIGADOS}" \
            SYMROOT="${DESTINO}" OBJROOT="${BUILD}/obj/kext-${ARQ}" build >> "${LOG}" 2>&1; then
        echo "ERRO na compilação. Erros (log completo em ${LOG}):"
        grep -E 'error:' "${LOG}" | sed -E "s#${ORIGEM}/##" | sort -u | head -40
        exit 1
    fi
    EXECUTAVEIS+=("${DESTINO}/Release/${NOME}.kext/Contents/MacOS/${NOME}")
done
KEXT="${SAIDA}/kext/Release/${NOME}.kext"
if [ "${#EXECUTAVEIS[@]}" -gt 1 ]; then
    echo "==> Juntando as arquiteturas (lipo) e assinando"
    lipo -create "${EXECUTAVEIS[@]}" -output "${BUILD}/obj/${NOME}-universal"
    cp "${BUILD}/obj/${NOME}-universal" "${KEXT}/Contents/MacOS/${NOME}"
    codesign -f -s "${ASSINATURA}" "${KEXT}"
fi
echo "==> Pronto: ${KEXT} ($(lipo -archs "${KEXT}/Contents/MacOS/${NOME}"))"
