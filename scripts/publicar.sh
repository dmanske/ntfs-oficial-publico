#!/bin/bash
# Atualiza o repositório público (dmanske/ntfs-oficial-publico) a partir deste, o privado.
#   bash scripts/publicar.sh            copia, faz commit e push no público
#   bash scripts/publicar.sh --release  também cria a Release v${VERSAO} com o .pkg de build/out/
#
# O público recebe só o que está no git daqui (commit atual), menos o que é só nosso (FORA_DO_PUBLICO): a análise
# do Tuxera feita com o REA, os desenhos baseados nela, planos internos e os scripts do REA. O README e a licença
# do público ficam em publico/. Os terceiros (NTFS-3G, osxfuse) continuam submódulos apontando para os originais.
set -euo pipefail
source "$(dirname "$0")/config.sh"

REPO_PUBLICO="dmanske/ntfs-oficial-publico"
PASTA_PUBLICO="${RAIZ}/../ntfs-oficial-publico"
FORA_DO_PUBLICO=(
    docs/design            # análise do Tuxera (REA) e desenhos baseados nela
    docs/planos            # pendências internas
    docs/produto           # PRD (decisões internas)
    .kiro
    publico                # vira a raiz do público (README, LICENSE)
    scripts/rea-trabalhador.command
    scripts/prova-fase0.sh # mexe nas preferências do Tuxera deste Mac
)
CRIAR_RELEASE=0
[ "${1:-}" = "--release" ] && CRIAR_RELEASE=1

[ -z "$(git -C "${RAIZ}" status --porcelain)" ] || { echo "ERRO: há mudanças sem commit aqui; faça o commit antes."; exit 1; }
COMMIT="$(git -C "${RAIZ}" rev-parse --short HEAD)"

if [ ! -d "${PASTA_PUBLICO}/.git" ]; then
    echo "==> Clonando ${REPO_PUBLICO} em ${PASTA_PUBLICO}"
    gh repo clone "${REPO_PUBLICO}" "${PASTA_PUBLICO}"
fi

echo "==> Copiando os arquivos do commit ${COMMIT}"
TEMP="$(mktemp -d)"
git -C "${RAIZ}" archive HEAD | tar -x -C "${TEMP}"
for f in "${FORA_DO_PUBLICO[@]}"; do rm -rf "${TEMP:?}/${f}"; done
cp "${RAIZ}/publico/README.md" "${TEMP}/README.md"
cp "${RAIZ}/publico/LICENSE" "${TEMP}/LICENSE"
cp "${RAIZ}/publico/DOCS_README.md" "${TEMP}/docs/README.md"   # o índice daqui aponta para pastas que não vão
# --delete apaga no público o que saiu daqui; .git e os submódulos (que o git archive não traz) ficam
rsync -a --delete --exclude .git --exclude terceiros/ "${TEMP}/" "${PASTA_PUBLICO}/"
rm -rf "${TEMP:?}"

echo "==> Submódulos (mesmos commits do privado)"
cd "${PASTA_PUBLICO}"
git -C "${RAIZ}" ls-tree HEAD terceiros/ | while read -r modo tipo sha caminho; do
    if [ "${tipo}" = "commit" ]; then git update-index --add --cacheinfo "160000,${sha},${caminho}"; fi
done

git add -A
if git diff --cached --quiet; then
    echo "(nada mudou no público)"
else
    git commit -q -m "NTFS Oficial ${VERSAO} (privado ${COMMIT})"
    git push -q -u origin HEAD:main
    echo "==> Publicado: https://github.com/${REPO_PUBLICO}"
fi

if [ "${CRIAR_RELEASE}" = 1 ]; then
    PKG="${SAIDA}/NTFS-Oficial-${VERSAO}.pkg"
    [ -f "${PKG}" ] || { echo "ERRO: ${PKG} não existe (bash scripts/montar-instalador.sh)"; exit 1; }
    gh release create "v${VERSAO}" "${PKG}" --repo "${REPO_PUBLICO}" --title "NTFS Oficial ${VERSAO}" \
        --notes-file "${RAIZ}/publico/NOTAS_DA_VERSAO.md"
fi
