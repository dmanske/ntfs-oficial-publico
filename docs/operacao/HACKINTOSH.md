# NTFS Oficial no Hackintosh (OpenCore)

17/10/2026. **Ainda não testado** — guia para quando formos no PC do Daniel. Marcado com ⚠️ o que precisa
conferir lá.

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
