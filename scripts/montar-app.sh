#!/bin/bash
# Compila o app (app/) e monta build/out/NTFS Oficial.app com assinatura ad-hoc.
# Não copia para /Applications nem instala nada (o instalador cuida disso depois).
set -euo pipefail
source "$(dirname "$0")/config.sh"

NOME_APP="NTFS Oficial"
APP="${SAIDA}/${NOME_APP}.app"
ID_APP="${IDENTIFICADOR}.app"

echo "==> Compilando o app (release, universal: ${ARQUITETURAS_USUARIO})"
ARGS_ARQ=(); for ARQ in ${ARQUITETURAS_USUARIO}; do ARGS_ARQ+=(--arch "${ARQ}"); done
( cd "${RAIZ}/app" && swift build -c release "${ARGS_ARQ[@]}" )
# Com várias --arch o executável sai em .build/apple/Products/Release, não em .build/release
BIN="$(cd "${RAIZ}/app" && swift build -c release "${ARGS_ARQ[@]}" --show-bin-path)/NTFSOficial"
[ -x "${BIN}" ] || { echo "ERRO: executável não encontrado em ${BIN}"; exit 1; }

echo "==> Montando ${APP}"
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"
cp "${BIN}" "${APP}/Contents/MacOS/NTFSOficial"

# Recursos de identidade (ícone do app, símbolo da barra de menus e símbolo colorido da lateral).
# Ficam em Contents/Resources e o app os carrega do Bundle.main (nada de recursos do SwiftPM).
for arquivo in AppIcon.icns BarraTemplate.png BarraTemplate@2x.png simbolo-colorido.png; do
  [ -f "${RAIZ}/identidade/${arquivo}" ] || { echo "ERRO: falta identidade/${arquivo}"; exit 1; }
  cp "${RAIZ}/identidade/${arquivo}" "${APP}/Contents/Resources/${arquivo}"
done

cat > "${APP}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key><string>${ID_APP}</string>
	<key>CFBundleName</key><string>${NOME_APP}</string>
	<key>CFBundleDisplayName</key><string>${NOME_APP}</string>
	<key>CFBundleExecutable</key><string>NTFSOficial</string>
	<key>CFBundleIconFile</key><string>AppIcon</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>${VERSAO}</string>
	<key>CFBundleVersion</key><string>${VERSAO}</string>
	<key>CFBundleDevelopmentRegion</key><string>pt-BR</string>
	<key>CFBundleLocalizations</key><array><string>pt-BR</string><string>en</string></array>
	<key>LSUIElement</key><true/>
	<key>LSMinimumSystemVersion</key><string>14.0</string>
	<key>NSHumanReadableCopyright</key><string>Daniel Manske</string>
	<key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

plutil -lint "${APP}/Contents/Info.plist"
codesign -f -s "${ASSINATURA}" --deep "${APP}"
echo "==> Pronto: ${APP}"
