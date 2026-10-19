#!/bin/bash
# Serviço (LaunchDaemon) que desmonta os volumes ntfsoficial quando o Mac desliga ou reinicia.
# O launchd manda SIGTERM aos serviços antes de desligar; desmontando aqui, o driver (que roda fora do
# kernel) grava tudo e fecha o NTFS direito antes de ser encerrado. Mesmo papel do tuxera_ntfs_daemon +
# TuxeraNTFSUnmountHelper (REA, docs/design/REFERENCIA_TUXERA.md seção 7).
#
# Como o tuxera_ntfs_daemon (_sigterm_execute / _unmount_ntfs3g_filesystems, REA): tenta desmontar normal e,
# se não der, forçado, e repete de 1 em 1 s até não sobrar volume. O dele repete para sempre; aqui para em
# LIMITE_SEGUNDOS, porque o launchd mata o serviço em ExitTimeOut (30 s no plist com.danielmanske.ntfsoficial.
# desmontar.plist) e uma desmontagem interrompida no meio é pior que a que o macOS fizer sozinho.
#
# Uso:  desmontar-ao-desligar.sh            serviço: espera o SIGTERM e desmonta
#       desmontar-ao-desligar.sh --agora    desmonta uma vez (com as tentativas acima) e sai; 0 = nada sobrou
TIPO="ntfsoficial"
LIMITE_SEGUNDOS=25

# Imprime o dispositivo de cada volume montado, um por linha. A linha do mount é
#   /dev/disk4s1 on /Volumes/Meu Disco (ntfsoficial, local, ...)
# O ponto de montagem pode ter espaço, então não dá para separar por campos (era o bug: "/Volumes/Meu").
# O dispositivo (1º campo) nunca tem espaço, e o diskutil/umount aceitam dispositivo no lugar do ponto.
listar_dispositivos() {
    /sbin/mount -t "${TIPO}" | while IFS= read -r linha; do
        printf '%s\n' "${linha%% on *}"
    done
}

# Ponto de montagem de um dispositivo, só para o log (tira "<disp> on " do começo e " (opções)" do fim)
ponto_de() {
    local linha
    linha="$(/sbin/mount -t "${TIPO}" | grep -F -- "$1 on " | head -n 1)"
    linha="${linha#* on }"
    printf '%s' "${linha% (*}"
}

# Uma rodada: sync, e para cada volume tenta normal e depois forçado. Devolve 0 se não sobrou nenhum.
desmontar_rodada() {
    local dispositivo ponto
    /bin/sync
    while IFS= read -r dispositivo; do
        [ -n "${dispositivo}" ] || continue
        ponto="$(ponto_de "${dispositivo}")"
        logger -t "${TIPO}" "desligando: desmontando ${ponto} (${dispositivo})"
        /usr/sbin/diskutil unmount "${dispositivo}" >/dev/null 2>&1 && continue
        logger -t "${TIPO}" "não desmontou ${ponto} normalmente, forçando"
        /usr/sbin/diskutil unmount force "${dispositivo}" >/dev/null 2>&1 \
            || /sbin/umount -f "${dispositivo}" >/dev/null 2>&1 \
            || logger -t "${TIPO}" "não consegui desmontar ${ponto} (${dispositivo})"
    done < <(listar_dispositivos)
    [ -z "$(listar_dispositivos)" ]
}

# Repete a cada 1 s até não sobrar volume ou acabar o tempo. 0 = tudo desmontado.
desmontar_tudo() {
    local inicio=${SECONDS}
    while true; do
        desmontar_rodada && return 0
        if [ $((SECONDS - inicio)) -ge "${LIMITE_SEGUNDOS}" ]; then
            logger -t "${TIPO}" "desligando: sobraram volumes depois de ${LIMITE_SEGUNDOS} s"
            return 1
        fi
        sleep 1
    done
}

if [ "${1:-}" = "--agora" ]; then
    desmontar_tudo
    exit $?
fi

ao_desligar() {
    trap '' TERM INT          # um segundo SIGTERM não reinicia a desmontagem
    desmontar_tudo
    exit 0
}
trap ao_desligar TERM INT

while true; do
    sleep 86400 &
    wait $!
done
