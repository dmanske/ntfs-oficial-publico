#!/bin/bash
# Testa, sem sudo, os patches 0007 (metadados do Finder: chflags, data de criação, nome do volume) e 0008 (nomes SFM).
# Usa o driver compilado em build/src-arm64 (ou DRV=caminho) montado direto como usuário, numa imagem de disco de teste.
# Uso: scripts/testar-finder-sfm.sh
set -uo pipefail
R="$(cd "$(dirname "$0")/.." && pwd)"
DRV="${DRV:-${R}/build/src-arm64/ntfs-3g/src/lowntfs-3g}"; BIN="${R}/build/out/bin"
T="${R}/build/teste/finder"; M="${T}/mp"; mkdir -p "${M}"
UID_=$(id -u); GID_=$(id -g)

cat > "${T}/xt.c" <<'CEOF'
/* xt crtime <arq> <segundos> | xt volname <ponto> <nome> : data de criação e nome do volume via setattrlist */
#include <sys/attr.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
int main(int c, char **v) {
    struct attrlist al; memset(&al, 0, sizeof al); al.bitmapcount = ATTR_BIT_MAP_COUNT;
    if (c == 4 && !strcmp(v[1], "crtime")) {
        struct timespec t = { atol(v[3]), 0 }; al.commonattr = ATTR_CMN_CRTIME;
        return setattrlist(v[2], &al, &t, sizeof t, 0) ? (perror("setattrlist"), 1) : 0;
    }
    if (c == 4 && !strcmp(v[1], "volname")) {
        struct { u_int32_t len; attrreference_t ref; char b[256]; } a; al.volattr = ATTR_VOL_INFO | ATTR_VOL_NAME;
        a.ref.attr_dataoffset = sizeof(attrreference_t); a.ref.attr_length = strlen(v[3]) + 1;
        strcpy(a.b, v[3]); a.len = sizeof a;
        return setattrlist(v[2], &al, &a.ref, sizeof(attrreference_t) + a.ref.attr_length, 0) ? (perror("setattrlist"), 1) : 0;
    }
    return 2;
}
CEOF
cc -o "${T}/xt" "${T}/xt.c" || exit 1

hdiutil create -quiet -size 200m -layout GPTSPUD -partitionType "Microsoft Basic Data" -ov "${T}/f.dmg"
P="$(hdiutil attach -nomount "${T}/f.dmg" 2>/dev/null | awk '/Microsoft Basic Data/ {print $1}')"
"${BIN}/mkntfs" -Q -L ROTULO "${P}" > /dev/null 2>&1
montar() {
    "${DRV}" "${P}" "${M}" -o "local,uid=${UID_},gid=${GID_},norecover${1:+,$1}" 2>&1 | tail -3; sleep 1
    mount | grep -q " on ${M} " || { echo "montagem falhou: abortando (nada foi gravado fora do volume)"; hdiutil detach -quiet "${P%s*}"; exit 1; }
}
desmontar() { umount "${M}"; sleep 1; }

echo "==> A: flags do Finder"
montar
echo x > "${M}/arq"; chflags hidden "${M}/arq"; ls -lO "${M}/arq"
mkdir "${M}/pasta"; chflags uchg "${M}/pasta"; ls -ldO "${M}/pasta"      # diretório nunca fica imutável
echo y > "${M}/ro"; chflags uchg "${M}/ro"; ls -lO "${M}/ro"; rm -f "${M}/ro" 2>&1 | head -1   # apagar deve dar erro de permissão
stat -f 'criação: %B %SB' "${M}/arq"; "${T}/xt" crtime "${M}/arq" 1000000000; stat -f 'criação depois: %B %SB' "${M}/arq"
desmontar
"${BIN}/ntfsinfo" -F /arq "${P}" | grep -i "flags\|HIDDEN"
montar; ls -lO "${M}/arq"; stat -f 'criação após remontar: %B' "${M}/arq"
"${T}/xt" volname "${M}" "NOVO NOME"; desmontar; "${BIN}/ntfslabel" "${P}"

echo "==> B: nomes SFM"
montar sfmconv
touch "${M}/a:b?c*.txt" "${M}/fim." "${M}/fim "; ls "${M}"; desmontar
"${BIN}/ntfsls" "${P}"
montar sfmconv; ls "${M}"; desmontar
montar nosfmconv; ls "${M}"; desmontar
montar windows_names; touch "${M}/a:b" 2>&1 | head -1; desmontar

echo "==> ntfsck do Tuxera (101 = sem erro)"
"${R}/build/rea/bin/ntfsck_2027.0.1_arm64" -s -P "${P}"; echo "ntfsck: $?"
hdiutil detach -quiet "${P%s*}"
