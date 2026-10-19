# Instalar o NTFS Oficial em outro Mac

17/10/2026. Vale para Mac com chip Apple (M1, M2, M3, M4… — todos iguais) e Mac Intel. Para Hackintosh, ver
[`HACKINTOSH.md`](HACKINTOSH.md).

Testado de ponta a ponta com a 0.2.1 (19/10/2026, o mesmo pacote) no Mac do Daniel (chip Apple, macOS 27) e num
Hackintosh Intel (macOS 26.6.2: kext carregado no boot, 4 discos internos montados com gravação; ver
[`HACKINTOSH.md`](HACKINTOSH.md)). Ainda não testado num Mac Intel de verdade nem no macOS 14 e 15.

> **Use a 0.2.1 ou mais nova fora do macOS 27.** O kext da 0.2.0 pedia o kernel do macOS 27 e era recusado nas outras
> versões, sem pedir aprovação; os discos NTFS sumiam do Finder. Ver
> [`correcoes/2026-10-19_kext-so-carregava-no-macos-27.md`](../correcoes/2026-10-19_kext-so-carregava-no-macos-27.md).

## Por que precisa preparar o Mac

O NTFS Oficial usa uma extensão de kernel (kext) própria. O Tuxera tem um certificado especial da Apple para
assinar kext; nós não temos (exige conta de desenvolvedor paga e aprovação à parte da Apple). Sem esse
certificado, o macOS só carrega o kext com a **Proteção da Integridade do Sistema (SIP)** desligada. É o mesmo
estado deste Mac (`csrutil status` → `disabled`).

O instalador (`.pkg`) e o app também não têm assinatura da Apple, então o macOS bloqueia a abertura até você
liberar (passo 2).

**Requisitos:** macOS 14 (Sonoma) ou mais novo (o instalador recusa o 13; o kext declara a KPI do macOS 14). Desinstale ou desligue antes outros drivers NTFS (Tuxera,
Paragon, macFUSE + ntfs-3g); o app avisa se encontrar algum.

## 1. Desligar a proteção do sistema (uma vez)

### Mac com chip Apple (M1, M2, M3, M4)

1. Desligue o Mac. Segure o **botão de ligar** até aparecer "Carregando opções de inicialização" → **Opções** →
   Continuar (pede usuário e senha).
2. Menu **Utilitários → Utilitário de Segurança de Inicialização** → escolha o disco → **Política de Segurança…**
   → marque **Segurança Reduzida** e **Permitir que o usuário gerencie extensões de kernel de desenvolvedores
   identificados** → OK (pede a senha).
3. Menu **Utilitários → Terminal**:
   ```bash
   csrutil disable
   ```
   Responda `y` e digite a senha.
4. Menu Apple → **Reiniciar**.

### Mac Intel

1. Reinicie segurando **Cmd + R** até aparecer a maçã (modo de recuperação).
2. Menu **Utilitários → Terminal**:
   ```bash
   csrutil disable
   ```
3. Menu Apple → **Reiniciar**.

Mac Intel com chip T2 não precisa mexer no Utilitário de Segurança de Inicialização para isso.

Conferir depois de reiniciar (Terminal normal):
```bash
csrutil status        # tem que dizer: System Integrity Protection status: disabled.
```

> Alternativa mais restrita (desliga só a parte de kext, não testada aqui): no Terminal da recuperação,
> `csrutil enable --without kext` no lugar de `csrutil disable`.

## 2. Liberar a instalação de apps sem assinatura da Apple

O jeito mais simples (o que o Daniel usa):

```bash
sudo spctl --master-disable
```

**Para que serve:** desliga o Gatekeeper, a trava que só deixa abrir apps assinados pela Apple ou baixados da
App Store. Sem isso, o macOS diz que o `NTFS-Oficial-….pkg` "não pode ser aberto porque não é de um
desenvolvedor identificado".

- No macOS 15 (Sequoia) ou mais novo o comando sozinho não basta: depois dele, abra **Ajustes → Privacidade e
  Segurança → Permitir aplicativos de** e escolha **Qualquer lugar** (a opção só aparece depois do comando).
- Para voltar a proteção: `sudo spctl --master-enable`.
- Sem desligar o Gatekeeper: clique com o botão direito no `.pkg` → **Abrir** → Abrir; ou, se o macOS não
  oferecer o botão, `xattr -d com.apple.quarantine ~/Downloads/NTFS-Oficial-*.pkg` e abra de novo.

## 3. Instalar

1. Baixe `NTFS-Oficial-<versão>.pkg` na página de Releases do repositório público
   (https://github.com/dmanske/ntfs-oficial-publico/releases). O mesmo arquivo serve para Intel e chip Apple.
2. Abra o `.pkg` e siga o instalador (pede a senha do Mac).
3. O macOS mostra **"Extensão de sistema bloqueada"**. Abra **Ajustes → Privacidade e Segurança**, role até o
   aviso do NTFS Oficial e clique em **Permitir** (pede a senha).
4. **Reinicie** quando o macOS pedir (no chip Apple sempre pede; é quando ele inclui o kext no sistema).
5. Depois de reiniciar, o ícone do NTFS Oficial aparece na barra de menus. Plugue um disco NTFS: ele monta
   sozinho, com leitura e gravação.

Conferir pelo Terminal:
```bash
kmutil showloaded --list-only | grep ntfsoficial       # o kext carregado
mount | grep ntfsoficial                               # discos montados pelo NTFS Oficial
cat /private/var/log/ntfsoficial-instalacao.log        # o que o instalador fez
```

## Desinstalar

Dê dois cliques em
`/Library/Filesystems/ntfsoficial.fs/Contents/Resources/Support/desinstalar-ntfs-oficial.command`
(pede a senha). Ele desmonta os discos, remove o app, o serviço, o kext e o pacote.

Para religar a proteção do sistema depois: modo de recuperação → Terminal → `csrutil enable` → reiniciar
(e, no chip Apple, voltar a **Segurança Total** no Utilitário de Segurança de Inicialização).

## Problemas comuns

| O que aparece | O que fazer |
|---|---|
| Disco aparece só para leitura e o app avisa "Windows hibernado" | No Windows, desligue a "Inicialização rápida" e use Desligar (não Hibernar). |
| Nada monta e `kmutil showloaded` não mostra `ntfsoficial` | Faltou o passo 1 (`csrutil status`) ou a aprovação em Privacidade e Segurança + reinício. |
| O app avisa "Outro driver NTFS instalado" | Desinstale o Tuxera/Paragon/macFUSE indicado. |
| `.pkg` "não pode ser aberto" | Passo 2. |
