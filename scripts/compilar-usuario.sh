#!/bin/bash
# Compila a parte que roda fora do kernel, com os nomes de scripts/config.sh:
#   libfuse 2 (osxfuse/fuse) estática -> driver lowntfs-3g e ntfsprogs (NTFS-3G) -> load_ e mount_ntfsoficial
# Universal (ARQUITETURAS_USUARIO em config.sh). Instala só dentro de build/ (nada no sistema). Precisa de: autoconf automake libtool pkg-config (Homebrew).
set -euo pipefail
source "$(dirname "$0")/config.sh"
[ "${PULAR_PREPARO:-0}" = 1 ] || bash "${RAIZ}/scripts/preparar-fontes.sh"

# gnu17: o código de 2018 usa casts no estilo antigo (int(*)()), que no C23 (padrão do clang novo) viram erro
CFLAGS_COMUM="-std=gnu17 -mmacosx-version-min=${MACOS_MINIMO} -O2"

rodar() {  # rodar <log> <comando...>: mostra só os erros se falhar
    local log="$1"; shift
    if ! "$@" >> "${log}" 2>&1; then
        echo "ERRO em: $*  (log: ${log})"
        grep -E '(error|ERROR)[: ]' "${log}" | grep -v -E '^\s*(/\S+/clang|builtin-|cd )' | cut -c1-300 | sort -u | tail -20
        exit 1
    fi
}

# O autotools não aceita vários -arch no configure, então libfuse + NTFS-3G são compilados uma vez por
# arquitetura, em cópias separadas dos fontes (build/src-<arq>) e com prefixo próprio (build/prefix-<arq>).
# --host diz ao configure que é compilação cruzada: ele não tenta rodar os programas de teste (que, para
# x86_64, só rodariam via Rosetta).
LOG_FUSE="${BUILD}/libfuse.log"; : > "${LOG_FUSE}"
LOG_NTFS="${BUILD}/ntfs-3g.log"; : > "${LOG_NTFS}"
BUILD_TRIPLA="$(uname -m | sed 's/arm64/aarch64/')-apple-darwin"
for ARQ in ${ARQUITETURAS_USUARIO}; do
    HOST="$(echo "${ARQ}" | sed 's/arm64/aarch64/')-apple-darwin"
    SRC="${BUILD}/src-${ARQ}"
    PREFIXO="${BUILD}/prefix-${ARQ}"
    CFLAGS_BASE="${CFLAGS_COMUM} -arch ${ARQ}"
    echo "==> [${ARQ}] copiando fontes para ${SRC}"
    mkdir -p "${SRC}"
    rsync -a --delete "${FONTES}/osxfuse/" "${SRC}/osxfuse/"
    rsync -a --delete "${FONTES}/ntfs-3g/" "${SRC}/ntfs-3g/"
    rm -rf "${PREFIXO}"

    echo "==> [${ARQ}] libfuse (estática)"
    cd "${SRC}/osxfuse/fuse"
    # O makeconf.sh do osxfuse cria um config.rpath vazio que o gettext novo recusa; os passos dele, com -fi:
    rodar "${LOG_FUSE}" glibtoolize -c
    rodar "${LOG_FUSE}" autoreconf -fi
    rodar "${LOG_FUSE}" env CFLAGS="${CFLAGS_BASE} -D_DARWIN_USE_64_BIT_INODE -I${SRC}/osxfuse/common" LDFLAGS="-arch ${ARQ}" \
        ./configure --build="${BUILD_TRIPLA}" --host="${HOST}" --prefix="${PREFIXO}" \
        --disable-dependency-tracking --enable-static --disable-shared --disable-example
    rodar "${LOG_FUSE}" make -j8
    rodar "${LOG_FUSE}" make install

    echo "==> [${ARQ}] NTFS-3G (driver lowntfs-3g + ntfsprogs)"
    cd "${SRC}/ntfs-3g"
    rodar "${LOG_NTFS}" ./autogen.sh
    # A libfuse entra estática (como o Tuxera faz com a libtuxera_ntfs); por isso as variáveis
    # FUSE_MODULE_* no lugar do pkg-config. Sem criptografia e sem plugins.
    rodar "${LOG_NTFS}" env \
        FUSE_MODULE_CFLAGS="-I${PREFIXO}/include/osxfuse/fuse -D_FILE_OFFSET_BITS=64 -D_DARWIN_USE_64_BIT_INODE" \
        FUSE_MODULE_LIBS="${PREFIXO}/lib/libosxfuse.a -liconv" \
        CFLAGS="${CFLAGS_BASE}" LDFLAGS="-arch ${ARQ}" \
        ./configure --build="${BUILD_TRIPLA}" --host="${HOST}" --prefix="${PREFIXO}" \
        --disable-shared --enable-static --disable-ldconfig --disable-mtab \
        --disable-plugins --enable-extras --with-fuse=external
    rodar "${LOG_NTFS}" make -j8
done
cd "${RAIZ}"

echo "==> load_${NOME} e mount_${NOME}"
for p in load_osxfuse mount_osxfuse; do
    LOG="${BUILD}/${p}.log"; : > "${LOG}"
    rodar "${LOG}" xcodebuild -project "${FONTES}/osxfuse/support/${p}.xcodeproj" -target "${p}" -configuration Release \
        ARCHS="${ARQUITETURAS_USUARIO}" VALID_ARCHS="${ARQUITETURAS_USUARIO}" ONLY_ACTIVE_ARCH=NO MACOSX_DEPLOYMENT_TARGET="${MACOS_MINIMO}" \
        CODE_SIGN_IDENTITY="${ASSINATURA}" PRODUCT_NAME="${p/osxfuse/${NOME}}" OTHER_CFLAGS='$(inherited) -std=gnu17' \
        SYMROOT="${SAIDA}/support" OBJROOT="${BUILD}/obj/support" build
done

echo "==> ${NOME}.util (detecção e montagem pelo macOS)"
mkdir -p "${SAIDA}/bin"
ARCHS_CLANG=(); for ARQ in ${ARQUITETURAS_USUARIO}; do ARCHS_CLANG+=(-arch "${ARQ}"); done
clang -std=gnu17 -O2 -Wall -Wextra -Werror "${ARCHS_CLANG[@]}" -mmacosx-version-min="${MACOS_MINIMO}" \
    -DNOME="\"${NOME}\"" -DIDENTIFICADOR="\"${IDENTIFICADOR}\"" \
    -DPACOTE_FS="\"${PACOTE_FS}\"" -DPREFERENCIAS="\"${PREFERENCIAS}\"" \
    "${RAIZ}"/ferramentas/ntfsoficial_util/*.c -framework CoreFoundation -o "${SAIDA}/bin/${NOME}.util"

echo "==> Juntando em ${SAIDA}/bin (lipo -create das arquiteturas: ${ARQUITETURAS_USUARIO})"
mkdir -p "${SAIDA}/bin"
universal() {  # universal <caminho relativo ao src-<arq>> <nome de saída>
    local entradas=()
    for ARQ in ${ARQUITETURAS_USUARIO}; do entradas+=("${BUILD}/src-${ARQ}/$1"); done
    lipo -create "${entradas[@]}" -output "${SAIDA}/bin/$2"
}
universal ntfs-3g/src/lowntfs-3g "${NOME}"
for f in mkntfs ntfsfix ntfslabel ntfsls ntfsinfo; do universal "ntfs-3g/ntfsprogs/${f}" "${f}"; done
universal ntfs-3g/src/ntfs-3g.probe ntfs-3g.probe
cp "${SAIDA}/support/Release/load_${NOME}" "${SAIDA}/support/Release/mount_${NOME}" "${SAIDA}/bin/"
# lipo invalida a assinatura: assinar de novo, sempre depois de juntar
for f in "${SAIDA}"/bin/*; do codesign -f -s "${ASSINATURA}" "$f" 2>/dev/null; done
ls -1 "${SAIDA}/bin"
