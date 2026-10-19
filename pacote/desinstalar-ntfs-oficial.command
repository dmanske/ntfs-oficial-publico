#!/bin/bash
# Desinstala o NTFS Oficial de quem instalou pelo .pkg (dar dois cliques ou rodar no Terminal; pede a senha).
# Equivale a scripts/desinstalar.sh, mas não depende do repositório: os valores abaixo são fixos e
# precisam bater com scripts/config.sh (NOME, IDENTIFICADOR) e com scripts/montar-instalador.sh (ID do recibo).
NOME="ntfsoficial"
IDENTIFICADOR="com.danielmanske.ntfsoficial"
ID_KEXT="${IDENTIFICADOR}.filesystems.${NOME}"
SERVICO="${IDENTIFICADOR}.desmontar"
PACOTE_FS="/Library/Filesystems/${NOME}.fs"
ID_RECIBO="${IDENTIFICADOR}.pacote"

echo "NTFS Oficial: desinstalação (vai pedir a senha de administrador)."
sudo -v || { echo "Sem permissão de administrador."; exit 1; }

echo "==> Desmontando volumes ${NOME}"
# 1º campo da linha do mount = dispositivo (nunca tem espaço); o ponto de montagem pode ter ("/Volumes/Meu Disco")
/sbin/mount -t "${NOME}" | while IFS= read -r linha; do diskutil unmount "${linha%% on *}" || true; done
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
echo "==> Recibo da instalação"
sudo pkgutil --forget "${ID_RECIBO}" 2>/dev/null || echo "(sem recibo)"
# Se o Tuxera estava instalado e foi desligado pela instalação, religa
if [ -f /Library/Preferences/com.tuxera.NTFS.plist ]; then
    echo "==> Religando o Tuxera (DisableDriver = 0)"
    sudo defaults write /Library/Preferences/com.tuxera.NTFS.plist DisableDriver -int 0
fi
echo "==> Pronto. O NTFS Oficial foi removido."
