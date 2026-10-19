#!/bin/bash
# Gera o instalador build/out/NTFS-Oficial-<VERSAO>.pkg para instalar em outro Mac.
# Só ferramentas do macOS (pkgbuild + productbuild). Não instala nada e não assina (não há certificado):
# no Mac de destino o macOS avisa que o instalador não é de um desenvolvedor identificado.
# Antes: bash scripts/compilar.sh && bash scripts/montar-pacote.sh && bash scripts/montar-app.sh
set -euo pipefail
source "$(dirname "$0")/config.sh"

ID_RECIBO="${IDENTIFICADOR}.pacote"   # o desinstalar-ntfs-oficial.command usa o mesmo valor (pkgutil --forget)
SERVICO="${IDENTIFICADOR}.desmontar"
APP="${SAIDA}/NTFS Oficial.app"
PACOTE="${SAIDA}/${NOME}.fs"
TRABALHO="${BUILD}/instalador"
RAIZ_PKG="${TRABALHO}/raiz"
DESTINO="${SAIDA}/NTFS-Oficial-${VERSAO}.pkg"

[ -d "${PACOTE}" ] || { echo "ERRO: falta ${PACOTE} (bash scripts/montar-pacote.sh)"; exit 1; }
[ -d "${APP}" ] || { echo "ERRO: falta ${APP} (bash scripts/montar-app.sh)"; exit 1; }

echo "==> Montando a raiz do instalador em ${RAIZ_PKG}"
rm -rf "${TRABALHO}"
mkdir -p "${RAIZ_PKG}/Library/Filesystems" "${RAIZ_PKG}/Library/LaunchDaemons" "${RAIZ_PKG}/Applications" \
         "${TRABALHO}/scripts" "${TRABALHO}/recursos"
ditto "${PACOTE}" "${RAIZ_PKG}${PACOTE_FS}"
ditto "${APP}" "${RAIZ_PKG}/Applications/NTFS Oficial.app"
cp "${RAIZ}/pacote/${SERVICO}.plist" "${RAIZ_PKG}/Library/LaunchDaemons/"
chmod 644 "${RAIZ_PKG}/Library/LaunchDaemons/${SERVICO}.plist"
cp "${RAIZ}/pacote/instalador/preinstall" "${RAIZ}/pacote/instalador/postinstall" "${TRABALHO}/scripts/"
chmod 755 "${TRABALHO}/scripts/"*
cp "${RAIZ}/pacote/instalador/boas-vindas.html" "${RAIZ}/pacote/instalador/conclusao.html" "${TRABALHO}/recursos/"

# Sem "relocável" (o app sempre vai para /Applications, mesmo que exista outra cópia em outro lugar) e sem
# checagem de versão (reinstalar a mesma versão, ou voltar a uma anterior, também troca os arquivos)
echo "==> pkgbuild"
pkgbuild --analyze --root "${RAIZ_PKG}" "${TRABALHO}/componentes.plist" >/dev/null
PB=/usr/libexec/PlistBuddy
i=0
while "${PB}" -c "Print :${i}:RootRelativeBundlePath" "${TRABALHO}/componentes.plist" >/dev/null 2>&1; do
    "${PB}" -c "Delete :${i}:BundleIsRelocatable" "${TRABALHO}/componentes.plist" 2>/dev/null || true
    "${PB}" -c "Add :${i}:BundleIsRelocatable bool false" "${TRABALHO}/componentes.plist"
    "${PB}" -c "Set :${i}:BundleIsVersionChecked false" "${TRABALHO}/componentes.plist"
    i=$((i + 1))
done
pkgbuild --root "${RAIZ_PKG}" --component-plist "${TRABALHO}/componentes.plist" \
    --identifier "${ID_RECIBO}" --version "${VERSAO}" --install-location / --ownership recommended \
    --scripts "${TRABALHO}/scripts" "${TRABALHO}/${NOME}-componente.pkg" >/dev/null

echo "==> Distribution"
cat > "${TRABALHO}/distribution.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>NTFS Oficial</title>
    <options customize="never" require-scripts="false" hostArchitectures="x86_64,arm64"/>
    <welcome file="boas-vindas.html" mime-type="text/html"/>
    <conclusion file="conclusao.html" mime-type="text/html"/>
    <volume-check>
        <allowed-os-versions>
            <os-version min="${MACOS_PKG_MINIMO}"/>
        </allowed-os-versions>
    </volume-check>
    <domains enable_anywhere="false" enable_currentUserHome="false" enable_localSystem="true"/>
    <choices-outline>
        <line choice="padrao"/>
    </choices-outline>
    <choice id="padrao" title="NTFS Oficial" description="Driver NTFS, serviço de desmontagem e aplicativo.">
        <pkg-ref id="${ID_RECIBO}"/>
    </choice>
    <pkg-ref id="${ID_RECIBO}" version="${VERSAO}" onConclusion="none">${NOME}-componente.pkg</pkg-ref>
</installer-gui-script>
XML
mkdir -p "${SAIDA}"
rm -f "${DESTINO}"
productbuild --distribution "${TRABALHO}/distribution.xml" --resources "${TRABALHO}/recursos" \
    --package-path "${TRABALHO}" "${DESTINO}" >/dev/null
echo "==> Pronto: ${DESTINO} ($(du -h "${DESTINO}" | cut -f1))"
