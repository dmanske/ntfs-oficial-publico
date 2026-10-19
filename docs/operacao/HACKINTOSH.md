# NTFS Oficial no Hackintosh (OpenCore)

17/10/2026. **Ainda não testado** — guia para quando formos no PC do Daniel. Marcado com ⚠️ o que precisa
conferir lá.

> **19/10/2026 — primeira tentativa (0.2.0), não funcionou.** PC: Intel `x86_64`, macOS 26.6.2 (kernel 25.6.0),
> OpenCore REL-107-2026-03-20, `csr-active-config` = `03080000` (já basta: `Kext Signing: disabled`). O kext da
> 0.2.0 exige kernel 27 e é recusado antes de pedir aprovação; os discos NTFS somem do Finder. Corrigido na 0.2.1
> ([`correcoes/2026-10-19_kext-so-carregava-no-macos-27.md`](../correcoes/2026-10-19_kext-so-carregava-no-macos-27.md));
> plano e teste: [`planos/KEXT_SO_CARREGA_NO_MACOS_27_2026-10-19.md`](../planos/KEXT_SO_CARREGA_NO_MACOS_27_2026-10-19.md).
>
> **Estado em 19/10/2026 (0.2.1): funcionando.** Kext 0.1.1 carregado no boot (o OpenCore não recusou, sem mexer no
> `SecureBootModel`); os 4 discos internos do Windows (DADOS 1 1TB, DADOS 2 1TB, 3TB, Windows) montam sozinhos pelo NTFS
> Oficial, com gravação. Eles têm a marca do chkdsk (`VOLUME_IS_DIRTY`) com journal limpo e montam com gravação, como no
> Tuxera (decisão do Daniel). Os números dos discos (`diskN`) mudam a cada reinício: identificar pelo nome.
> Com o pacote final da 0.2.1 (`a08bc259…`, instalado às 13:53): kext x86_64 `71E49789-…`; os discos montados no boot
> aparecem como do usuário (`uid=99` na montagem, `ls -ln` = 501) e o `git` funciona neles. Ao instalar por cima, o macOS
> pediu aprovação de novo (até aprovar, os discos ficam só leitura pela Apple).
> **Para voltar** a só leitura pelo NTFS da Apple: `sudo defaults write /Library/Preferences/com.danielmanske.ntfsoficial
> DisableDriver -int 1` e reiniciar (desfazer: `sudo defaults delete … DisableDriver`).
>
> **Compilar no Hackintosh (Intel):** funciona com o Xcode 26.5 e o Homebrew em `/usr/local` (autoconf, automake,
> libtool, pkgconf). O `compilar-usuario.sh` ignora o `libintl.h` do gettext do Homebrew (`ac_cv_header_libintl_h=no`),
> que quebrava o link do arm64.

O Hackintosh usa o pacote **Intel** (o mesmo `.pkg` universal de [`INSTALAR_EM_OUTRO_MAC.md`](INSTALAR_EM_OUTRO_MAC.md)).
A diferença é como desligar a proteção do sistema: no Hackintosh quem manda nisso é o `config.plist` do
OpenCore, não o `csrutil` (o OpenCore reescreve o valor a cada inicialização se estiver configurado para isso).

## Antes de ir ao PC: anotar

- Versão do macOS e do OpenCore (`nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version`).
- Processador (Intel ou AMD) — o kext é x86_64 genérico, deve servir nos dois. ⚠️
- Fazer **cópia da EFI** (pendrive) antes de mexer no `config.plist`.

## Opção A (recomendada): desligar a verificação de kext pelo config.plist

No `EFI/OC/config.plist` (ProperTree ou OCAT):

1. `NVRAM → Add → 7C436110-AB2A-4BBB-A880-FE41995C9F82 → csr-active-config` (tipo **Data**) = `03000000`
   - `0x3` = kext sem assinatura da Apple (`0x1`) + sistema de arquivos sem restrição (`0x2`). É o mínimo para o
     nosso kext. Se já houver outro valor (ex.: `03080000`, `EF0F0000`), ele já inclui o `0x1`: deixe como está.
2. `NVRAM → Delete → 7C436110-AB2A-4BBB-A880-FE41995C9F82` tem que conter `csr-active-config` (senão o valor
   antigo da NVRAM continua valendo).
3. Salvar, reiniciar, no menu do OpenCore escolher **Reset NVRAM** uma vez, e iniciar o macOS.
4. Conferir: `csrutil status` deve mostrar `Kext Signing: disabled` (ou o SIP todo desligado).
5. Se o kext não carregar mesmo assim: `Misc → Security → SecureBootModel` = `Disabled` (o Secure Boot da Apple
   recusa kext de terceiros fora do OpenCore). ⚠️
6. Seguir os passos 2 e 3 do guia normal (Gatekeeper, instalar o `.pkg`, permitir em Privacidade e Segurança,
   reiniciar).

## Opção B (alternativa): o OpenCore injeta o kext

Funciona mesmo com o SIP ligado, porque o OpenCore coloca o kext no kernel antes do macOS iniciar.

1. Instalar o `.pkg` normalmente (o app, o detector e o serviço vêm dele).
2. Copiar `/Library/Filesystems/ntfsoficial.fs/Contents/Extensions/ntfsoficial.kext` para `EFI/OC/Kexts/`.
3. `Kernel → Add`, nova entrada: `BundlePath` = `ntfsoficial.kext`, `ExecutablePath` =
   `Contents/MacOS/ntfsoficial`, `PlistPath` = `Contents/Info.plist`, `Arch` = `x86_64`, `MinKernel` = `21.0.0`
   (macOS 12), `Enabled` = `true`.
4. Reiniciar.

⚠️ Pendência conhecida da opção B: quem carrega o kext normalmente é o `load_ntfsoficial`, que também liga
`vfs.generic.ntfsoficial.tunables.allow_other=1` e o grupo admin (sem isso a montagem pelo Finder cai — ver
`docs/modulos/montagem-automatica.md`). Com o kext injetado, esse passo não roda sozinho depois de reiniciar. Se
for usar a opção B, precisa de um ajuste (ex.: o serviço do NTFS Oficial gravar os dois `sysctl` ao iniciar).
Por isso a recomendada é a A.

## Atualizar o NTFS Oficial depois

- Opção A: instalar o `.pkg` novo; se o kext mudou, o macOS pede nova permissão + reinício.
- Opção B: além do `.pkg`, trocar o `ntfsoficial.kext` na EFI.
