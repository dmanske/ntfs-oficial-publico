#!/bin/bash
# Serviço (LaunchDaemon) que desmonta os volumes ntfsoficial quando o Mac desliga ou reinicia.
# O launchd manda SIGTERM aos serviços antes de desligar; desmontando aqui, o driver (que roda fora do
# kernel) grava tudo e fecha o NTFS direito antes de ser encerrado. Mesmo papel do tuxera_ntfs_daemon +
# TuxeraNTFSUnmountHelper (REA, docs/design/REFERENCIA_TUXERA.md seção 7).
TIPO="ntfsoficial"

desmontar_tudo() {
    /sbin/mount -t "${TIPO}" | while read -r dispositivo _ ponto _; do
        logger -t "${TIPO}" "desligando: desmontando ${ponto} (${dispositivo})"
        /usr/sbin/diskutil unmount "${ponto}" >/dev/null 2>&1 \
            || /usr/sbin/diskutil unmount force "${ponto}" >/dev/null 2>&1 \
            || /sbin/umount -f "${ponto}"
    done
    exit 0
}
trap desmontar_tudo TERM INT

while true; do
    sleep 86400 &
    wait $!
done
