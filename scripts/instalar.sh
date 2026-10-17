#!/bin/bash
# Instala o NTFS Oficial neste Mac (pede a senha do sudo). Rodar no Terminal:
#   bash scripts/instalar.sh            instala/atualiza o pacote e o serviço de desmontagem
#   bash scripts/instalar.sh --tuxera   também desliga o Tuxera (DisableDriver = 1)
# Desfazer: bash scripts/desinstalar.sh
#
# Kext: o macOS aprovou o kext instalado. Se o kext novo tiver outro CDHash, vai precisar aprovar em
# Ajustes e reiniciar de novo; por isso o script avisa e só troca com --kext-novo.
set -euo pipefail
source "$(dirname "$0")/config.sh"

ID_KEXT="${IDENTIFICADOR}.filesystems.${NOME}"
SERVICO="${IDENTIFICADOR}.desmontar"
PLIST_SERVICO="/Library/LaunchDaemons/${SERVICO}.plist"
KEXT_INSTALADO="${PACOTE_FS}/Contents/Extensions/${NOME}.kext"
TROCAR_KEXT=0; DESLIGAR_TUXERA=0
for a in "$@"; do
    case "$a" in
        --kext-novo) TROCAR_KEXT=1 ;;
        --tuxera) DESLIGAR_TUXERA=1 ;;
    esac
done

cdhash() { codesign -dvvv "$1" 2>&1 | sed -n 's/^CDHash=//p'; }

bash "${RAIZ}/scripts/montar-pacote.sh" > /dev/null
NOVO="${SAIDA}/${NOME}.fs"

if [ -d "${KEXT_INSTALADO}" ] && [ "$(cdhash "${KEXT_INSTALADO}")" != "$(cdhash "${NOVO}/Contents/Extensions/${NOME}.kext")" ]; then
    if [ "${TROCAR_KEXT}" = 1 ]; then
        echo "==> Kext novo (CDHash diferente): vai precisar aprovar em Ajustes e reiniciar."
    else
        echo "==> Kext compilado é diferente do aprovado; mantendo o instalado (use --kext-novo para trocar)."
        rsync -a --delete "${KEXT_INSTALADO}/" "${NOVO}/Contents/Extensions/${NOME}.kext/"
    fi
fi

echo "==> Instalando ${PACOTE_FS}"
sudo rsync -a --delete "${NOVO}/" "${PACOTE_FS}/"
sudo chown -R root:wheel "${PACOTE_FS}"
# Carregar o kext precisa de root; quem monta pelo Finder pode não ser root (o Tuxera faz o mesmo:
# load_tuxera_ntfs é setuid root)
sudo chmod 4755 "${PACOTE_FS}/Contents/Resources/Support/load_${NOME}"

echo "==> Serviço de desmontagem ao desligar (${SERVICO})"
# Parar o serviço manda SIGTERM, o mesmo sinal do desligamento: ele desmontaria os discos (aconteceu em
# 17/10/2026 ao reinstalar). Por isso só reinicia o serviço se o plist mudou ou se ele não está carregado.
if ! cmp -s "${RAIZ}/pacote/${SERVICO}.plist" "${PLIST_SERVICO}" || ! launchctl print "system/${SERVICO}" >/dev/null 2>&1; then
    sudo cp "${RAIZ}/pacote/${SERVICO}.plist" "${PLIST_SERVICO}"
    sudo chown root:wheel "${PLIST_SERVICO}"; sudo chmod 644 "${PLIST_SERVICO}"
    sudo launchctl bootout system "${PLIST_SERVICO}" 2>/dev/null || true
    sudo launchctl bootstrap system "${PLIST_SERVICO}"
else
    echo "(serviço já carregado e igual: não reiniciado, para não desmontar os discos)"
fi
launchctl print "system/${SERVICO}" 2>/dev/null | grep -E '^\s*state' || true

if [ "${DESLIGAR_TUXERA}" = 1 ] && [ -f /Library/Preferences/com.tuxera.NTFS.plist ]; then
    echo "==> Desligando o Tuxera (DisableDriver = 1)"
    sudo defaults write /Library/Preferences/com.tuxera.NTFS.plist DisableDriver -int 1
fi

echo "==> Kext"
# Carregar pelo load_ntfsoficial (como o load_tuxera_ntfs, visto com o REA): além de carregar, ele grava
# o grupo admin em tunables.admin_group. Sem isso (valor 0 = wheel), quem não é root não consegue montar
# com allow_other e a montagem pelo Finder cai logo depois de abrir o disco.
if ! kmutil showloaded --list-only 2>/dev/null | grep -q "${ID_KEXT}"; then
    sudo "${PACOTE_FS}/Contents/Resources/Support/load_${NOME}" \
        || sudo kmutil load -p "${KEXT_INSTALADO}" \
        || echo "Se pediu aprovação: Ajustes → Privacidade e Segurança → permitir → reiniciar."
fi
GRUPO_ADMIN="$(dscl . -read /Groups/admin PrimaryGroupID | awk '{print $2}')"
sudo sysctl -w "vfs.generic.${NOME}.tunables.admin_group=${GRUPO_ADMIN}" >/dev/null || true
# A montagem que o macOS lança roda como o usuário, mas só com o grupo principal (log: "grupos 20"), sem
# o admin; aí o kext nega o allow_other (fuse_vfsops.c:284, EPERM). Com allow_other=1 o kext aceita.
# O load_ntfsoficial faz o mesmo a cada carga (patch 0004); aqui vale para o kext que já está carregado.
sudo sysctl -w "vfs.generic.${NOME}.tunables.allow_other=1" >/dev/null || true
kmutil showloaded --list-only 2>/dev/null | grep "${ID_KEXT}" || true
sysctl "vfs.generic.${NOME}.tunables.admin_group" 2>/dev/null || true
APP="${SAIDA}/NTFS Oficial.app"
if [ -d "${APP}" ]; then
    echo "==> App NTFS Oficial em /Applications"
    pkill -x NTFSOficial 2>/dev/null || true
    sudo rsync -a --delete "${APP}/" "/Applications/NTFS Oficial.app/"
    sudo chown -R root:wheel "/Applications/NTFS Oficial.app"
    open "/Applications/NTFS Oficial.app" || true
else
    echo "(app não montado: bash scripts/montar-app.sh)"
fi
echo "==> Pronto. Teste: bash scripts/testar-automatico.sh"
