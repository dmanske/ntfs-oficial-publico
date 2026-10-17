#!/bin/bash
# Remove o NTFS Oficial e religa o Tuxera (pede a senha do sudo). Rodar no Terminal.
# Volumes montados pelo NTFS Oficial são desmontados antes.
set -euo pipefail
source "$(dirname "$0")/config.sh"

ID_KEXT="${IDENTIFICADOR}.filesystems.${NOME}"
SERVICO="${IDENTIFICADOR}.desmontar"

echo "==> Desmontando volumes ${NOME}"
/sbin/mount -t "${NOME}" | while read -r _ _ ponto _; do diskutil unmount "${ponto}" || true; done
echo "==> App"
pkill -x NTFSOficial 2>/dev/null || true
[ -d "/Applications/NTFS Oficial.app" ] && sudo rm -rf "/Applications/NTFS Oficial.app"
echo "==> Serviço de desmontagem"
sudo launchctl bootout system "/Library/LaunchDaemons/${SERVICO}.plist" 2>/dev/null || true
[ -f "/Library/LaunchDaemons/${SERVICO}.plist" ] && sudo rm "/Library/LaunchDaemons/${SERVICO}.plist"
echo "==> Kext"
sudo kmutil unload -b "${ID_KEXT}" 2>/dev/null || echo "(não estava carregado)"
echo "==> Pacote ${PACOTE_FS}"
[ -d "${PACOTE_FS}" ] && sudo rm -rf "${PACOTE_FS}"
if [ -f /Library/Preferences/com.tuxera.NTFS.plist ]; then
    echo "==> Religando o Tuxera (DisableDriver = 0)"
    sudo defaults write /Library/Preferences/com.tuxera.NTFS.plist DisableDriver -int 0
fi
echo "==> Pronto"
