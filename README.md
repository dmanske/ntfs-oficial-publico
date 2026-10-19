<p align="center"><img src="identidade/logo-horizontal.png" alt="NTFS Oficial" width="420"></p>

# NTFS Oficial

Leitura e **gravação** de discos NTFS (Windows) no macOS, sem macFUSE e sem Tuxera/Paragon.

- Monta sozinho ao plugar o disco, já com gravação.
- Rápido: 202 MB/s gravando e 267 MB/s lendo num SSD USB (o mesmo SSD lê no máximo 326 MB/s).
- App na barra de menus com gerenciador de discos: abrir, ejetar, verificar, reparar e formatar.
- Avisa quando o disco só pode ser lido (Windows hibernado ou desligado sem "Desligar").
- Português do Brasil (padrão) e inglês.
- Um instalador só para **Mac com chip Apple (M1, M2, M3, M4)** e **Mac Intel**. macOS 14 ou mais novo.

> **Atenção:** o NTFS Oficial usa uma extensão de kernel própria, sem o certificado da Apple que os produtos
> pagos têm. Por isso o Mac precisa estar com a **Proteção da Integridade do Sistema (SIP) desligada**. Leia o
> passo a passo antes de instalar.

## Instalar

Guia completo, com os comandos: [`docs/operacao/INSTALAR_EM_OUTRO_MAC.md`](docs/operacao/INSTALAR_EM_OUTRO_MAC.md).
Hackintosh (OpenCore): [`docs/operacao/HACKINTOSH.md`](docs/operacao/HACKINTOSH.md).

Resumo:

1. **Desligar o SIP** (uma vez), no modo de recuperação:
   - **Chip Apple:** segure o botão de ligar → Opções → Utilitários → Utilitário de Segurança de Inicialização →
     *Segurança Reduzida* + *permitir extensões de kernel de desenvolvedores identificados*. Depois Utilitários →
     Terminal: `csrutil disable` → reiniciar.
   - **Intel:** reinicie segurando **Cmd + R** → Utilitários → Terminal: `csrutil disable` → reiniciar.
2. **Liberar apps sem assinatura da Apple**, no Terminal:
   ```bash
   sudo spctl --master-disable
   ```
   Desliga o Gatekeeper, que só deixa abrir apps assinados pela Apple. No macOS 15 ou mais novo, depois do
   comando, vá em **Ajustes → Privacidade e Segurança → Permitir aplicativos de: Qualquer lugar**. Para voltar:
   `sudo spctl --master-enable`. (Alternativa: botão direito no `.pkg` → Abrir.)
3. Baixe o `NTFS-Oficial-<versão>.pkg` em **[Releases](https://github.com/dmanske/ntfs-oficial-publico/releases)**
   e instale.
4. **Ajustes → Privacidade e Segurança → Permitir** (a extensão do NTFS Oficial) e **reinicie**.

Desinstalar: dois cliques em
`/Library/Filesystems/ntfsoficial.fs/Contents/Resources/Support/desinstalar-ntfs-oficial.command`.

## Como funciona

- **Extensão de kernel:** o código aberto do osxfuse 3 (FUSE para macOS), com outro nome (`ntfsoficial`), para não
  depender nem conflitar com o macFUSE.
- **Driver NTFS:** NTFS-3G (`lowntfs-3g`) com correções para o macOS: acesso direto ao disco com leitura e
  gravação alinhadas (rápido), números de arquivo estáveis (evita dado errado quando o NTFS reaproveita um
  registro) e montagem pelo Finder como usuário comum.
- **Detecção e montagem automática:** um pacote em `/Library/Filesystems/ntfsoficial.fs`, que o macOS consulta
  antes do NTFS dele (que só lê).
- **App:** SwiftUI, na barra de menus.
- **Disco que o Windows deixou sujo** (tirado sem "remover com segurança"): o journal do Windows é reaplicado com o
  `ntfsrecover` do NTFS-3G e o disco monta com gravação; se não der, monta só para leitura e avisa.
- **Finder:** arquivos ocultos do Windows ficam escondidos, "somente leitura" vira o cadeado, data de criação, renomear
  o volume. Nomes com `" * : < > ? \ |` são gravados no formato SFM (o mesmo do compartilhamento SMB do macOS).
- **Utilitário de Disco:** Primeiros Socorros (verificar/reparar) e Apagar como "NTFS Oficial".

Detalhes em [`docs/ARQUITETURA.md`](docs/ARQUITETURA.md) e [`docs/modulos/`](docs/modulos/).

## Versões

| Versão | Data | O que mudou |
|---|---|---|
| 0.2.0 | 18/10/2026 | Disco sujo do Windows montado com gravação; Finder (ocultos, cadeado, data de criação, renomear volume); nomes SFM; Utilitário de Disco; correções (nada montava depois da 0.1.1; disco com espaço no nome não era desmontado ao desligar). Kext 0.1.1: precisa aprovar de novo e reiniciar |
| 0.1.1 | 17/10/2026 | App não some mais em segundo plano |
| 0.1.0 | 17/10/2026 | Primeira versão |

## Compilar

```bash
git clone --recursive https://github.com/dmanske/ntfs-oficial-publico.git
cd ntfs-oficial-publico
brew install autoconf automake libtool pkg-config
bash scripts/compilar.sh              # kext + driver (Intel e chip Apple), em build/out/
bash scripts/montar-pacote.sh
bash scripts/montar-app.sh
bash scripts/montar-instalador.sh     # build/out/NTFS-Oficial-<versão>.pkg
```

Precisa do Xcode. Nada é instalado no sistema por esses comandos.

## Licença

GPL-2.0 (arquivo [`LICENSE`](LICENSE)), por causa do NTFS-3G. Partes de terceiros, em `terceiros/`, com as suas
licenças: osxfuse 3 (estilo BSD), libfuse (LGPL-2), NTFS-3G (GPL-2). Sem garantia: faça backup dos seus dados.

---

## English (short)

Read/write NTFS for macOS, without macFUSE, Tuxera or Paragon. Universal installer (Apple silicon and Intel),
macOS 14+. It ships its own kernel extension without Apple's kext-signing certificate, so **SIP must be
disabled** (`csrutil disable` from Recovery; on Apple silicon also choose *Reduced Security* and allow kernel
extensions). Unsigned app: `sudo spctl --master-disable` (on macOS 15+ then pick *Anywhere* in Privacy &
Security), or right-click → Open. Download the `.pkg` from Releases, install, allow the extension in Privacy &
Security and restart. GPL-2.0.

Criado por Daniel Manske.
