# Valores ajustáveis do NTFS Oficial, num lugar só.
# Lido pelos scripts de compilação (source scripts/config.sh). Não coloque segredos aqui.

# Nome técnico: vira /dev/${NOME}N, o tipo do sistema de arquivos, os sysctl vfs.generic.${NOME}.*
NOME="ntfsoficial"
# Nome que aparece para a pessoa (sem espaço: o osxfuse usa como token do pré-processador)
NOME_EXIBICAO="NTFSOficial"
# Prefixo dos identificadores (kext: ${IDENTIFICADOR}.filesystems.${NOME})
IDENTIFICADOR="com.danielmanske.ntfsoficial"
VERSAO="0.2.3"
# Versão do kext: vai para o kext (sysctl version.number) e para o load_/mount_ntfsoficial, que recusam montar se
# ela for diferente da do kext carregado ("mismatched version"). Só mude quando o código do kext mudar: kext novo
# exige aprovar em Ajustes e reiniciar, e o instalar.sh mantém o kext já aprovado. Separada da VERSAO desde
# 18/10/2026: a 0.1.1 subiu a versão de tudo, ficou o kext aprovado 0.1.0 e nenhum disco montava.
#   0.1.0  kext da fase 0 (patches 0001-0004)
#   0.1.1  + 0005: anuncia "renomear volume" (18/10/2026)
#          0.1.1 também na 0.2.1: mesmo código, Info.plist com KPI_MINIMO (antes 27.0.0)
#   0.1.2  + 0007: abrir sem leitura nem escrita (O_EVTONLY do smbd) vira só leitura, não panic (20/10/2026)
#          + 0008: pedido interrompido antes de o driver recebê-lo desiste na hora (travava o disco, 20/10/2026)
VERSAO_KEXT="0.1.2"

# macOS mínimo: KPI que o kext declara (OSBundleLibraries) e versão que o instalador exige.
# Os dois são macOS 14 = Darwin 23; mudar juntos; não há fórmula (macOS 26 = Darwin 25, macOS 27 = Darwin 27);
# nunca usar a KPI do SDK: a 0.2.0 saiu com 27.0.0 e só carregava no macOS 27.
KPI_MINIMO="23.0.0"
MACOS_PKG_MINIMO="14.0"    # o app SwiftUI também pede macOS 14

# Onde o pacote fica instalado
PACOTE_FS="/Library/Filesystems/${NOME}.fs"
# Preferências (lidas pelo ntfsoficial.util; padrões em ferramentas/ntfsoficial_util/preferencias.c)
PREFERENCIAS="/Library/Preferences/${IDENTIFICADOR}.plist"

# Ordem de detecção no macOS (menor = consultado primeiro). Precisa ganhar do Tuxera e do NTFS da Apple:
#   Apple ntfs.fs: Windows_NTFS 1000, GPT dados do Windows 2000, disco inteiro 4000
#   Tuxera:        440, 440, 3440
ORDEM_NTFS=400
ORDEM_DISCO_INTEIRO=3400
# Partição marcada como FAT que na verdade é NTFS (o Windows monta assim). Apple FAT: 1000; Tuxera: 1940.
# Com 1900 a Apple (FAT de verdade) ainda ganha das partições FAT autênticas no nosso detector, que confere a
# assinatura "NTFS    " antes de tudo e recusa FAT rápido; só pegamos o que a Apple recusou.
ORDEM_FAT=1900

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
