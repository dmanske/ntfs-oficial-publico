#!/bin/bash
# Mede muitos arquivos pequenos num volume NTFS montado (sem sudo): copiar uma árvore, listar, procurar, ler e
# apagar. Complementa o medir-velocidade.sh (arquivo grande): o Tuxera tem cache de blocos próprio (cbcio) e o
# nosso modo raw não tem cache nenhum, então pastas cheias podem ser o ponto fraco (conferência de 18/10/2026).
#   bash scripts/medir-arquivos-pequenos.sh /Volumes/Filmes [quantidade_de_arquivos]
# Cada etapa de leitura começa com o volume desmontado e montado de novo (sem cache da memória).
set -euo pipefail
source "$(dirname "$0")/config.sh"

PONTO="${1:?informe o ponto de montagem, ex.: /Volumes/Filmes}"
N="${2:-3000}"
T="${BUILD}/teste"; ORIGEM="${T}/peq-${N}"; DESTINO="${PONTO}/_teste_pequenos_${NOME}"
mkdir -p "${T}"
agora() { python3 -I -c 'import time; print(time.time())'; }
tempo() { python3 -I -c "import sys; print(f'{float(sys.argv[2])-float(sys.argv[1]):6.1f} s')" "$1" "$2"; }

DISCO="$(mount | awk -v p="${PONTO}" '$3==p {print $1}')"
[ -n "${DISCO}" ] || { echo "ERRO: nada montado em ${PONTO}"; exit 1; }
remontar() { diskutil unmount "${DISCO}" >/dev/null && diskutil mount "${DISCO}" >/dev/null; }
echo "Volume: ${PONTO} (${DISCO}) — $(mount | grep " on ${PONTO} " | sed 's/.*(//;s/)//')"

# Árvore de origem fixa (mesma semente): N arquivos de 1 a 64 KB em pastas de 100
[ -d "${ORIGEM}" ] || python3 -I - "${ORIGEM}" "${N}" <<'EOF'
import os, random, sys
raiz, n = sys.argv[1], int(sys.argv[2]); random.seed(18102026)
for i in range(n):
    pasta = os.path.join(raiz, f"pasta {i // 100:03d}"); os.makedirs(pasta, exist_ok=True)
    open(os.path.join(pasta, f"arquivo {i:05d} ação.txt"), "wb").write(os.urandom(random.randint(1024, 65536)))
EOF
echo "Origem: ${N} arquivos, $(du -sm "${ORIGEM}" | cut -f1) MB"
rm -rf "${DESTINO}"

t0="$(agora)"; cp -R "${ORIGEM}" "${DESTINO}"; sync; t1="$(agora)"
echo "Copiar:   $(tempo "$t0" "$t1")"
remontar
t0="$(agora)"; CONTA="$(find "${DESTINO}" -type f | wc -l | tr -d ' ')"; t1="$(agora)"
echo "Procurar: $(tempo "$t0" "$t1")  (${CONTA} arquivos)"
remontar
t0="$(agora)"; ls -lR "${DESTINO}" > /dev/null; t1="$(agora)"
echo "Listar:   $(tempo "$t0" "$t1")"
remontar
t0="$(agora)"; tar cf - -C "${DESTINO}" . > /dev/null; t1="$(agora)"
echo "Ler tudo: $(tempo "$t0" "$t1")"
# Compara pelo nome normalizado (NFC): o volume devolve os nomes acentuados em NFD, como o macOS espera, e o
# diff -r compara os nomes byte a byte (deu "diferente" com o conteúdo idêntico, 18/10/2026)
python3 -I - "${ORIGEM}" "${DESTINO}" <<'EOF' && echo "Conteúdo: igual à origem" || echo "ERRO: conteúdo diferente da origem"
import os, sys, unicodedata
def arvore(raiz):
    r = {}
    for d, _, fs in os.walk(raiz):
        for f in fs:
            p = os.path.join(d, f)
            r[unicodedata.normalize("NFC", os.path.relpath(p, raiz))] = p
    return r
a, b = arvore(sys.argv[1]), arvore(sys.argv[2])
sys.exit(0 if a.keys() == b.keys() and all(open(a[k], "rb").read() == open(b[k], "rb").read() for k in a) else 1)
EOF
t0="$(agora)"; rm -rf "${DESTINO}"; sync; t1="$(agora)"
echo "Apagar:   $(tempo "$t0" "$t1")"
