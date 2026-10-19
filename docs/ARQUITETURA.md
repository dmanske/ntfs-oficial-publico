# Arquitetura e padrões do NTFS Oficial

**Vale a partir de 17/10/2026 — estrutura aceita pelo Daniel em 17/10/2026 ("pode continuar até onde
não precisar reiniciar").** Regra para qualquer
pessoa ou IA (Claude, Kiro) que for criar ou mudar algo neste projeto. O Kiro lê o resumo em
`.kiro/steering/arquitetura-projeto.md` (sempre ativo). Padrão geral de projetos do Daniel:
`docs/ARQUITETURA.md` do projeto netogofans.

## 1. Antes de começar qualquer coisa

1. **Explicar o plano e esperar aprovação** antes de mudança não trivial.
2. **Ler o que já existe:** o índice [`docs/README.md`](README.md), o PRD e o design.
3. **Nada de dependência pesada sem perguntar.**
4. **Nunca testar em disco de verdade do Daniel** sem ele pedir: testes usam imagens de disco
   criadas para isso, em pasta temporária.
5. **Carregar ou descarregar o kext, mexer no Tuxera ou na segurança do Mac: só com o ok do Daniel.**

## 2. O que é

- Leitura e gravação de NTFS no macOS, do jeito do Tuxera: **kext FUSE próprio + driver NTFS-3G +
  integração com o macOS + app de menu**. Detalhes em [design/DESIGN_KEXT_PROPRIO.md](design/DESIGN_KEXT_PROPRIO.md).
- Mac com chip Apple e Mac Intel (pacote universal), macOS 14+; o principal é o Mac do Daniel (chip Apple, macOS 27).
  Hackintosh em [`operacao/HACKINTOSH.md`](operacao/HACKINTOSH.md). Sem servidor, sem conta, sem telemetria.

## 3. Código

### 3.1 Estrutura: uma pasta por camada

Não é a do padrão React (`src/features/<modulo>/`): o projeto é um kext em C, ferramentas de linha de
comando em C e um app SwiftUI. Cada camada tem sua pasta e seu jeito de compilar.

```
ntfs-oficial/
  terceiros/          código de terceiros como submódulos git, sem alteração direta
    osxfuse/          osxfuse/osxfuse ramo archive/osxfuse-3 (headers common/) — BSD
      kext/           osxfuse/kext — BSD
      support/        osxfuse/support (load_osxfuse, mount_osxfuse) — BSD
      fuse/           osxfuse/fuse (libfuse 2) — LGPL
    ntfs-3g/          tuxera/ntfs-3g — GPL-2
  build/              cópia dos fontes com os patches + saída da compilação (fora do git)
  kext/               nosso kext: patches sobre terceiros/osxfuse-kext + nome ntfsoficial
  driver/             driver ntfsoficial (lowntfs-3g) + libfuse renomeada, ligada estática
  ferramentas/        load_ntfsoficial, mount_ntfsoficial, ntfsoficial.util, daemon de desmontagem
  pacote/             ntfsoficial.fs (Info.plist), LaunchDaemon, instalador e desinstalador
  app/                pacote Swift do app de menu
    Sources/NTFSOficialMotor/   discos (DiskArbitration), chamar as ferramentas, preferências
    Sources/NTFSOficial/        app SwiftUI (App/, Features/<Tela>/, Shared/Config.swift)
    Tests/NTFSOficialMotorTests/
  scripts/            compilar tudo, assinar, instalar, montar o .pkg, publicar, testes, medições
    engenharia-reversa/   extrair e exportar os binários do Tuxera com o Ghidra (fora do público)
  identidade/         marca (ícone, símbolos, logo, papel de parede) e telas-alvo — ver docs/design/DESIGN_SYSTEM.md
  publico/            README, LICENSE e notas da versão do repositório público
  docs/
```

- **Mudanças no código de terceiros** vão como arquivos de patch em `kext/patches/` e
  `driver/patches/`, aplicados pelo `scripts/preparar-fontes.sh` numa cópia em `build/src`. Assim dá para
  atualizar o código de origem e ver exatamente o que mudou. A **troca de nome** (osxfuse → ntfsoficial)
  não é patch: é feita pelo mesmo script a partir de `scripts/config.sh`, e ele para com erro se a troca
  não pegar. Macros do autoconf que faltam ficam em `driver/m4/`.
- **Antes de decidir como uma peça deve funcionar, conferir no Tuxera com o REA** (descompilação pelo
  Hopper, rodando o `rea` pelo Terminal.app) e citar a evidência no patch ou no documento.
- **Nomes:** identificador `ntfsoficial`; pacotes `com.danielmanske.ntfsoficial.*`.
- **Valores ajustáveis num lugar só:** `scripts/config.sh` (versão, nomes, caminhos de instalação),
  lido pelos scripts e gerando as constantes de C; no app, `Shared/Config.swift`.
- Um arquivo por responsabilidade. Não criar pasta vazia.

### 3.2 Compilar

- Tudo: `bash scripts/compilar.sh` (prepara os fontes, compila o kext e a parte fora do kernel). Separado:
  `scripts/compilar-kext.sh`, `scripts/compilar-usuario.sh`. Usa o Xcode e `autoconf automake libtool
  pkg-config` (Homebrew). Saída em `build/out/`; nada é instalado nem carregado.
- App: `swift build` / `swift test` dentro de `app/`; `bash scripts/montar-app.sh` monta o `NTFS Oficial.app`.
- Tudo é **universal** (`scripts/config.sh`: `ARQUITETURAS_KEXT`, `ARQUITETURAS_USUARIO`): o kext compila uma
  arquitetura por vez e junta com `lipo`; NTFS-3G e libfuse, uma cópia dos fontes por arquitetura.
- Instalador para outros Macs: `bash scripts/montar-instalador.sh` → `build/out/NTFS-Oficial-<versão>.pkg`
  (scripts em `pacote/instalador/`). Neste Mac, continuar usando `scripts/instalar.sh`, que mantém o kext já aprovado.

### 3.3 Repositórios

- **Privado** `dmanske/ntfs-oficial`: tudo, inclusive a análise do Tuxera com o REA (`docs/design/`).
- **Público** `dmanske/ntfs-oficial-publico`: gerado por `bash scripts/publicar.sh` a partir do commit atual,
  sem `docs/design`, `docs/planos`, `docs/produto`, `.kiro` e os scripts do REA (lista `FORA_DO_PUBLICO` no
  script). README e LICENSE (GPL-2.0) vêm de `publico/`. `--release` cria a Release com o `.pkg`.
- Nunca editar o público direto: muda aqui, faz commit, roda o `publicar.sh`.

## 4. Documentação

Tudo em `docs/`, índice em [`docs/README.md`](README.md).

| Momento | Documento | Pasta |
|---|---|---|
| Antes de construir algo grande | Design: problema, decisões, alternativas | `docs/design/` |
| Pendência ou plano para depois | Plano, com o que falta e a evidência | `docs/planos/` |
| Depois de corrigir algo não trivial | Sintoma, causa, correção, como reverter | `docs/correcoes/` |
| Funcionalidade pronta | Como funciona hoje | `docs/modulos/` |
| Funcionalidade nova | Linha/seção no PRD | `docs/produto/PRD.md` |
| Guia de operação (instalar, aprovar kext) | Passo a passo | `docs/operacao/` |

- Análise pontual fica no chat. Nada de arquivos de "fase" ou "resumo final".
- Documento velho vai para `docs/_arquivo/`, nunca é apagado.

## 5. Reiniciar o Mac

Nada que exija reiniciar (carregar kext novo, aprovar extensão, mudar segurança) sem o Daniel avisar que
pode. Combinado em 17/10/2026.

## 6. Git

- Repositório privado `dmanske/ntfs-oficial`. `main` é a versão estável.
- `.kiro/steering/` vai para o git; o resto do `.kiro/` não.
- Imagens de disco de teste e binários compilados nunca vão para o git.
- Commit em português; push no mesmo dia.
