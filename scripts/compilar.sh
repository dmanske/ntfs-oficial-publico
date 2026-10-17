#!/bin/bash
# Compila tudo (kext + parte fora do kernel). Não instala nem carrega nada.
set -euo pipefail
source "$(dirname "$0")/config.sh"
bash "${RAIZ}/scripts/preparar-fontes.sh"
PULAR_PREPARO=1 bash "${RAIZ}/scripts/compilar-kext.sh"
PULAR_PREPARO=1 bash "${RAIZ}/scripts/compilar-usuario.sh"
echo "==> Tudo compilado em ${SAIDA}"
