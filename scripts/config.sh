# Valores ajustáveis do NTFS Oficial, num lugar só.
# Lido pelos scripts de compilação (source scripts/config.sh). Não coloque segredos aqui.

# Nome técnico: vira /dev/${NOME}N, o tipo do sistema de arquivos, os sysctl vfs.generic.${NOME}.*
NOME="ntfsoficial"
# Nome que aparece para a pessoa (sem espaço: o osxfuse usa como token do pré-processador)
NOME_EXIBICAO="NTFSOficial"
# Prefixo dos identificadores (kext: ${IDENTIFICADOR}.filesystems.${NOME})
IDENTIFICADOR="com.danielmanske.ntfsoficial"
VERSAO="0.1.0"

# Onde o pacote fica instalado
PACOTE_FS="/Library/Filesystems/${NOME}.fs"
# Preferências (lidas pelo ntfsoficial.util; padrões em ferramentas/ntfsoficial_util/preferencias.c)
PREFERENCIAS="/Library/Preferences/${IDENTIFICADOR}.plist"

# Ordem de detecção no macOS (menor = consultado primeiro). Precisa ganhar do Tuxera e do NTFS da Apple:
#   Apple ntfs.fs: Windows_NTFS 1000, GPT dados do Windows 2000, disco inteiro 4000
#   Tuxera:        440, 440, 3440
ORDEM_NTFS=400
ORDEM_DISCO_INTEIRO=3400

# Compilação
# Binário universal (Mac Intel + Apple Silicon). Listas separadas por espaço.
ARQUITETURAS_KEXT="arm64e x86_64"      # kext: no Apple Silicon o kernel é arm64e
ARQUITETURAS_USUARIO="arm64 x86_64"    # programas fora do kernel (driver, ferramentas, app)
MACOS_MINIMO="12.0"        # o Xcode 27 não aceita menos que 12.0
ASSINATURA="-"             # "-" = assinatura ad-hoc (só funciona neste Mac, com segurança reduzida)

# Pastas (relativas à raiz do projeto)
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
TERCEIROS="${RAIZ}/terceiros"
BUILD="${RAIZ}/build"
FONTES="${BUILD}/src"
SAIDA="${BUILD}/out"
