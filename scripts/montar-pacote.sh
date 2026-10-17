#!/bin/bash
# Monta o pacote ntfsoficial.fs em build/out/ (não instala nada; instalar: scripts/instalar.sh).
#
# Contents/Info.plist                          FSMediaTypes (detecção) + FSPersonalities (montagem)
# Contents/Extensions/ntfsoficial.kext         onde o load_ntfsoficial procura (patch 0003)
# Contents/Resources/ntfsoficial.util          detecção (-p), chamado pelo macOS
# Contents/Resources/mount_ntfsoficial         montagem, chamado pelo macOS (mesmo programa do .util)
# Contents/Resources/Support/                  desinstalador (.pkg), driver, ferramentas NTFS e os auxiliares do FUSE
#                                              (load_/mount_ntfsoficial, onde a libfuse procura)
set -euo pipefail
source "$(dirname "$0")/config.sh"

KEXT="${SAIDA}/kext/Release/${NOME}.kext"
[ -d "${KEXT}" ] && [ -x "${SAIDA}/bin/${NOME}.util" ] || { echo "ERRO: rode antes bash scripts/compilar.sh"; exit 1; }

PACOTE="${SAIDA}/${NOME}.fs"
R="${PACOTE}/Contents/Resources"
echo "==> Montando ${PACOTE}"
rm -rf "${PACOTE}"
mkdir -p "${PACOTE}/Contents/Extensions" "${R}/Support"
rsync -a "${KEXT}/" "${PACOTE}/Contents/Extensions/${NOME}.kext/"
cp "${SAIDA}/bin/${NOME}.util" "${R}/${NOME}.util"
cp "${SAIDA}/bin/${NOME}.util" "${R}/mount_${NOME}"
for f in "${NOME}" load_${NOME} mount_${NOME} ntfs-3g.probe mkntfs ntfsfix ntfslabel ntfsls ntfsinfo; do
    cp "${SAIDA}/bin/${f}" "${R}/Support/"
done
cp "${RAIZ}/pacote/desmontar-ao-desligar.sh" "${RAIZ}/pacote/desinstalar-ntfs-oficial.command" "${R}/Support/"
# Licenças junto do programa distribuído (a do osxfuse, estilo BSD, exige o aviso de direitos na distribuição binária)
mkdir -p "${R}/Licencas"
cp "${TERCEIROS}/osxfuse/LICENSE.txt" "${R}/Licencas/osxfuse.txt"
cp "${TERCEIROS}/ntfs-3g/COPYING" "${R}/Licencas/ntfs-3g-GPL-2.txt"
cp "${TERCEIROS}/ntfs-3g/COPYING.LIB" "${R}/Licencas/libntfs-3g-LGPL-2.txt"

# Um tipo de mídia do macOS -> o nosso detector, com prioridade (menor = consultado antes)
midia() {  # midia <chave> <content hint ou vazio para disco inteiro> <ordem>
    local propriedades
    if [ -n "$2" ]; then
        propriedades="<key>Content Hint</key><string>$2</string><key>Leaf</key><true/>"
    else
        propriedades="<key>Leaf</key><true/><key>Whole</key><true/>"
    fi
    cat <<EOF
		<key>$1</key>
		<dict>
			<key>FSMediaProperties</key>
			<dict>${propriedades}</dict>
			<key>FSProbeArguments</key><string>-p</string>
			<key>FSProbeExecutable</key><string>${NOME}.util</string>
			<key>FSProbeOrder</key><integer>$3</integer>
		</dict>
EOF
}

cat > "${PACOTE}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key><string>${IDENTIFICADOR}.filesystems.util</string>
	<key>CFBundleName</key><string>${NOME}</string>
	<key>CFBundlePackageType</key><string>fs  </string>
	<key>CFBundleShortVersionString</key><string>${VERSAO}</string>
	<key>CFBundleVersion</key><string>${VERSAO}</string>
	<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
	<key>FSMediaTypes</key>
	<dict>
$(midia Windows_NTFS Windows_NTFS "${ORDEM_NTFS}")
$(midia EBD0A0A2-B9E5-4433-87C0-68B6B72699C7 EBD0A0A2-B9E5-4433-87C0-68B6B72699C7 "${ORDEM_NTFS}")
$(midia Whole "" "${ORDEM_DISCO_INTEIRO}")
	</dict>
	<key>FSPersonalities</key>
	<dict>
		<key>NTFS Oficial</key>
		<dict>
			<key>FSMountArguments</key><string></string>
			<key>FSMountExecutable</key><string>mount_${NOME}</string>
			<key>FSName</key><string>Windows NT File System (NTFS Oficial)</string>
			<key>FSSubType</key><integer>0</integer>
		</dict>
	</dict>
</dict>
</plist>
EOF
plutil -lint "${PACOTE}/Contents/Info.plist" >/dev/null
find "${PACOTE}" -type f | sed "s#${SAIDA}/##" | sort
