# NTFS Oficial no Hackintosh (OpenCore)

> English: [`en/HACKINTOSH.md`](en/HACKINTOSH.md) · Español: [`es/HACKINTOSH.md`](es/HACKINTOSH.md) (traduções de
> 19/10/2026; se mudar este guia, mude as duas).

19/10/2026. **Testado e funcionando** num Hackintosh Intel com a 0.2.1 (ver [Testado](#testado-19102026-021)). Use a
**0.2.1 ou mais nova**: a 0.2.0 só carregava o kext no macOS 27 e, nos outros, os discos NTFS sumiam do Finder
([`correcoes/2026-10-19_kext-so-carregava-no-macos-27.md`](../correcoes/2026-10-19_kext-so-carregava-no-macos-27.md)).

O Hackintosh usa o mesmo `.pkg` universal de [`INSTALAR_EM_OUTRO_MAC.md`](INSTALAR_EM_OUTRO_MAC.md). A diferença é como
desligar a proteção do sistema: no Hackintosh quem manda nisso é o `config.plist` do OpenCore, não o `csrutil` (o
OpenCore reescreve o valor a cada inicialização, se estiver configurado para isso). Marcado com ⚠️ o que ainda não foi
testado.

## Testado (19/10/2026, 0.2.1)

- **PC:** Intel `x86_64`, macOS 26.6.2 (kernel 25.6.0), OpenCore REL-107-2026-03-20, `csr-active-config` = `03080000`
  (`csrutil status` → `Kext Signing: disabled`). `SecureBootModel` sem mudar.
- **Pacote:** `NTFS-Oficial-0.2.1.pkg` da Release, SHA-256 `a08bc259991ba6be8a6672ceeb4630f342606d323af78c33574ead900ac51f0b`.
- **Kext:** 0.1.1 carregado no boot (`kmutil showloaded`), sem o OpenCore recusar. Primeira vez do kext num processador Intel (num Mac Intel de verdade, ainda não).
- **Discos:** os 4 discos internos do Windows montam sozinhos no boot pelo NTFS Oficial, com gravação e os nomes certos.
  Aparecem como da pessoa (`ls -ln` → `501 20`; como root, `99 99`) e o `git` funciona neles.
- **Disco marcado para o chkdsk** (`VOLUME_IS_DIRTY`, journal limpo): monta com gravação, como no Tuxera. A marca fica no
  disco até rodar o chkdsk num Windows; o NTFS Oficial não a apaga.
- **Instalar por cima de outra versão:** o macOS pediu para permitir o kext de novo. Até permitir e reiniciar, os discos
  ficaram só leitura pelo NTFS da Apple (não somem).
- ⚠️ Não testado: processador AMD, a opção B e macOS 14/15.

## Antes de começar

- Anotar a versão do macOS e do OpenCore (`nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version`).
- Processador Intel ou AMD: o kext é `x86_64` genérico e deve servir nos dois. ⚠️ AMD não testado.
- Fazer **cópia da EFI** (pendrive) antes de mexer no `config.plist`.
- Desinstalar ou desligar outros drivers NTFS (Tuxera, Paragon, macFUSE + ntfs-3g).

## Opção A (recomendada, testada): desligar a verificação de kext pelo config.plist

No `EFI/OC/config.plist` (ProperTree ou OCAT):

1. `NVRAM → Add → 7C436110-AB2A-4BBB-A880-FE41995C9F82 → csr-active-config` (tipo **Data**) = `03000000`
   - `0x3` = kext sem assinatura da Apple (`0x1`) + sistema de arquivos sem restrição (`0x2`). É o mínimo para o
     nosso kext. Se já houver outro valor que inclui o `0x1` (ex.: `03080000`, o do PC testado, ou `EF0F0000`), deixe
     como está.
2. `NVRAM → Delete → 7C436110-AB2A-4BBB-A880-FE41995C9F82` tem que conter `csr-active-config` (senão o valor
   antigo da NVRAM continua valendo).
3. Salvar, reiniciar, no menu do OpenCore escolher **Reset NVRAM** uma vez, e iniciar o macOS.
4. Conferir: `csrutil status` deve mostrar `Kext Signing: disabled` (ou o SIP todo desligado).
5. Seguir os passos 2 e 3 do [guia normal](INSTALAR_EM_OUTRO_MAC.md): liberar o Gatekeeper, instalar o `.pkg`,
   permitir em Ajustes → Privacidade e Segurança e reiniciar.
6. Só se o kext não carregar mesmo assim: `Misc → Security → SecureBootModel` = `Disabled` (o Secure Boot da Apple
   recusa kext de terceiros fora do OpenCore). No PC testado não precisou.

## Opção B (alternativa, ⚠️ não testada): o OpenCore injeta o kext

Funcionaria mesmo com o SIP ligado, porque o OpenCore coloca o kext no kernel antes do macOS iniciar.

1. Instalar o `.pkg` normalmente (o app, o detector e o serviço vêm dele).
2. Copiar `/Library/Filesystems/ntfsoficial.fs/Contents/Extensions/ntfsoficial.kext` para `EFI/OC/Kexts/`.
3. `Kernel → Add`, nova entrada: `BundlePath` = `ntfsoficial.kext`, `ExecutablePath` =
   `Contents/MacOS/ntfsoficial`, `PlistPath` = `Contents/Info.plist`, `Arch` = `x86_64`, `MinKernel` = `23.0.0`
   (macOS 14, o mínimo da 0.2.1), `Enabled` = `true`.
4. Reiniciar.

Pendência conhecida: quem carrega o kext normalmente é o `load_ntfsoficial`, que também liga
`vfs.generic.ntfsoficial.tunables.allow_other=1` e o grupo admin (sem isso a montagem pelo Finder cai; ver
[`../modulos/montagem-automatica.md`](../modulos/montagem-automatica.md)). Com o kext injetado, esse passo não roda
sozinho depois de reiniciar. Para usar a opção B, precisa de um ajuste (ex.: o serviço do NTFS Oficial gravar os dois
`sysctl` ao iniciar). Por isso a recomendada é a A.

## Atualizar o NTFS Oficial depois

- **Opção A:** instalar o `.pkg` novo. Se o arquivo do kext mudou (mesmo que só o `Info.plist`), o macOS pede para
  permitir de novo e reiniciar; até lá, os discos ficam só leitura pelo NTFS da Apple.
- **Opção B:** além do `.pkg`, trocar o `ntfsoficial.kext` na EFI.

## Problemas e dicas

| O que | Como |
|---|---|
| Voltar a só leitura pelo NTFS da Apple, sem desinstalar | `sudo defaults write /Library/Preferences/com.danielmanske.ntfsoficial DisableDriver -int 1` e reiniciar. Para desfazer: `sudo defaults delete /Library/Preferences/com.danielmanske.ntfsoficial DisableDriver` |
| Desinstalar | ver o [guia normal](INSTALAR_EM_OUTRO_MAC.md#desinstalar) |
| Qual é qual disco | os números (`diskN`) mudam a cada reinício: identifique pelo nome (`diskutil list`) |
| O kext carregou? | `kmutil showloaded --list-only \| grep ntfsoficial` e `csrutil status` |
| O que o instalador fez | `cat /private/var/log/ntfsoficial-instalacao.log` (diz se falta permitir ou se o macOS é incompatível) |
| Registro da detecção e da montagem | `/usr/bin/log show --last 15m --predicate 'subsystem == "com.danielmanske.ntfsoficial"'` (no zsh, `log` sozinho é um comando interno e não mostra nada) |
| Disco ficou só leitura pela Apple | falta permitir o kext em Privacidade e Segurança + reiniciar; o registro mostra `kext não carregou (load_ntfsoficial = 1)` |
| Reinicia sozinho quando outro Mac abre um disco NTFS dele pela rede (o relatório diz `What kind of a flag is this` e `smbd`) | até a 0.2.1 (kext 0.1.1); corrigido na 0.2.2 (kext 0.1.2). Enquanto estiver na 0.2.1, tire os discos NTFS das pastas compartilhadas (Ajustes → Geral → Compartilhamento → Compartilhamento de Arquivos) |
| Tudo que usa um disco NTFS para de responder (Finder, FinderX, Spotlight, o app NTFS Oficial) e só volta reiniciando | até a 0.2.1: um programa foi encerrado enquanto esperava o disco e o kext entrou num laço. Corrigido na 0.2.2 (kext 0.1.2). Na 0.2.1, reinicie |

## Compilar no Hackintosh (Intel)

Funciona com o Xcode 26.5 e o Homebrew em `/usr/local` (`autoconf`, `automake`, `libtool`, `pkgconf`). O
`compilar-usuario.sh` ignora o `libintl.h` do gettext do Homebrew (`ac_cv_header_libintl_h=no`), que quebrava o link do
arm64. Para instalar, prefira o `.pkg` da Release: é o que foi testado.

## Histórico

- **19/10/2026, 0.2.0: não funcionou.** O kext pedia o kernel do macOS 27 e era recusado antes de pedir permissão
  (nada aparecia em Privacidade e Segurança); os discos NTFS sumiram do Finder e o nome deles virou o aviso
  `WARNING: Dirty volume mount was forced…`. Corrigido na 0.2.1.
- **19/10/2026, 0.2.1:** testada aqui e no Mac com chip Apple com o mesmo pacote, e publicada. Durante o teste, os discos
  montados no boot ficavam em nome de `root`/`_windowserver` (o `git` recusava); corrigido antes de publicar (dono 99).
- **20/10/2026, 0.2.1: kernel panic ao compartilhar.** Abrir pelo MacBook Air (Finder → Rede) uma pasta do Hackintosh
  num disco NTFS fazia o Hackintosh reiniciar: o `smbd` abre os arquivos sem leitura nem escrita (`O_EVTONLY`) e o kext
  dava panic. No outro sentido funcionava. Corrigido na 0.2.2 (kext 0.1.2), ainda sem teste aqui.
- **20/10/2026, 0.2.1: disco travado.** O FinderX, o Spotlight e o app NTFS Oficial pararam em um dos discos NTFS: o
  ajudante de espelhar telas dos Ajustes foi encerrado enquanto esperava o disco e o kext ficou girando com a trava
  do pedido, sem deixar o driver trabalhar. Corrigido na 0.2.2 (kext 0.1.2), ainda sem teste aqui.
- 17/10/2026: guia escrito antes do primeiro teste.
