# NTFS Oficial en un Hackintosh (OpenCore)

> Traducción de la guía en portugués [`../HACKINTOSH.md`](../HACKINTOSH.md), 19/10/2026. Si las dos no coinciden, la de
> portugués es la referencia. English: [`../en/HACKINTOSH.md`](../en/HACKINTOSH.md).

19/10/2026. **Probado y funcionando** en un Hackintosh Intel con la 0.2.1 (ver [Probado](#probado-19102026-021)). Usa
la **0.2.1 o más nueva**: la 0.2.0 solo cargaba el kext en macOS 27 y, en las demás versiones, los discos NTFS
desaparecían del Finder (detalles, en portugués:
[`../../correcoes/2026-10-19_kext-so-carregava-no-macos-27.md`](../../correcoes/2026-10-19_kext-so-carregava-no-macos-27.md)).

Un Hackintosh usa el mismo `.pkg` universal de [`INSTALAR.md`](INSTALAR.md). La diferencia es cómo se desactiva la
protección del sistema: en un Hackintosh la controla el `config.plist` de OpenCore, no `csrutil` (OpenCore reescribe el
valor en cada arranque, si está configurado para eso). Lo marcado con ⚠️ todavía no está probado.

## Probado (19/10/2026, 0.2.1)

- **PC:** Intel `x86_64`, macOS 26.6.2 (kernel 25.6.0), OpenCore REL-107-2026-03-20, `csr-active-config` = `03080000`
  (`csrutil status` → `Kext Signing: disabled`). `SecureBootModel` sin cambiar.
- **Paquete:** `NTFS-Oficial-0.2.1.pkg` de la Release, SHA-256 `a08bc259991ba6be8a6672ceeb4630f342606d323af78c33574ead900ac51f0b`.
- **Kext:** 0.1.1 cargado al arrancar (`kmutil showloaded`), sin que OpenCore lo bloqueara. Primera vez del kext en un
  procesador Intel (en un Mac Intel de verdad, todavía no).
- **Discos:** los 4 discos internos de Windows se montan solos al arrancar con NTFS Oficial, con escritura y los nombres
  correctos. Aparecen como del usuario (`ls -ln` → `501 20`; como root, `99 99`) y `git` funciona en ellos.
- **Disco marcado para chkdsk** (`VOLUME_IS_DIRTY`, journal limpio): se monta con escritura, como hace NTFS-3G. La marca
  queda en el disco hasta que se ejecute chkdsk en Windows; NTFS Oficial no la borra.
- **Instalar encima de otra versión:** macOS pidió permitir el kext otra vez. Hasta permitirlo y reiniciar, los discos
  quedaron en solo lectura con el controlador NTFS de Apple (no desaparecen).
- ⚠️ No probado: procesadores AMD, la opción B, macOS 14/15.

## Antes de empezar

- Anota la versión de macOS y de OpenCore (`nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version`).
- Procesador Intel o AMD: el kext es `x86_64` genérico y debería servir en los dos. ⚠️ AMD no probado.
- Haz una **copia de la EFI** (pendrive) antes de tocar el `config.plist`.
- Desinstala o desactiva otros controladores NTFS (Tuxera, Paragon, macFUSE + ntfs-3g).

## Opción A (recomendada, probada): desactivar la comprobación de kext en el config.plist

En `EFI/OC/config.plist` (ProperTree u OCAT):

1. `NVRAM → Add → 7C436110-AB2A-4BBB-A880-FE41995C9F82 → csr-active-config` (tipo **Data**) = `03000000`
   - `0x3` = kexts sin firma de Apple (`0x1`) + sistema de archivos sin restricción (`0x2`). Es el mínimo para nuestro
     kext. Si ya hay otro valor que incluye el `0x1` (p. ej. `03080000`, el del PC probado, o `EF0F0000`), déjalo como
     está.
2. `NVRAM → Delete → 7C436110-AB2A-4BBB-A880-FE41995C9F82` tiene que contener `csr-active-config` (si no, sigue
   valiendo el valor antiguo de la NVRAM).
3. Guarda, reinicia, elige **Reset NVRAM** una vez en el menú de OpenCore y arranca macOS.
4. Comprueba: `csrutil status` tiene que mostrar `Kext Signing: disabled` (o el SIP entero desactivado).
5. Sigue los pasos 2 y 3 de la [guía normal](INSTALAR.md): permitir Gatekeeper, instalar el `.pkg`, permitirlo en
   Ajustes del Sistema → Privacidad y seguridad y reiniciar.
6. Solo si el kext sigue sin cargar: `Misc → Security → SecureBootModel` = `Disabled` (el Secure Boot de Apple rechaza
   kexts de terceros fuera de OpenCore). En el PC probado no hizo falta.

## Opción B (alternativa, ⚠️ no probada): OpenCore inyecta el kext

Funcionaría incluso con el SIP activado, porque OpenCore pone el kext en el kernel antes de que arranque macOS.

1. Instala el `.pkg` normalmente (la app, el detector y el servicio vienen de él).
2. Copia `/Library/Filesystems/ntfsoficial.fs/Contents/Extensions/ntfsoficial.kext` a `EFI/OC/Kexts/`.
3. `Kernel → Add`, entrada nueva: `BundlePath` = `ntfsoficial.kext`, `ExecutablePath` = `Contents/MacOS/ntfsoficial`,
   `PlistPath` = `Contents/Info.plist`, `Arch` = `x86_64`, `MinKernel` = `23.0.0` (macOS 14, el mínimo de la 0.2.1),
   `Enabled` = `true`.
4. Reinicia.

Pendiente conocido: normalmente quien carga el kext es `load_ntfsoficial`, que también activa
`vfs.generic.ntfsoficial.tunables.allow_other=1` y el grupo admin (sin eso, el montaje desde el Finder falla). Con el
kext inyectado, ese paso no se ejecuta solo después de reiniciar. Para usar la opción B hace falta un ajuste (p. ej., que
el servicio de NTFS Oficial escriba los dos `sysctl` al arrancar). Por eso la recomendada es la A.

## Actualizar después

- **Opción A:** instala el `.pkg` nuevo. Si el archivo del kext cambió (aunque sea solo su `Info.plist`), macOS pide
  permitirlo otra vez y reiniciar; hasta entonces, los discos quedan en solo lectura con el controlador NTFS de Apple.
- **Opción B:** además del `.pkg`, reemplaza el `ntfsoficial.kext` en la EFI.

## Problemas y consejos

| Qué | Cómo |
|---|---|
| Volver a solo lectura con el controlador NTFS de Apple, sin desinstalar | `sudo defaults write /Library/Preferences/com.danielmanske.ntfsoficial DisableDriver -int 1` y reiniciar. Para deshacer: `sudo defaults delete /Library/Preferences/com.danielmanske.ntfsoficial DisableDriver` |
| Desinstalar | ver la [guía normal](INSTALAR.md#desinstalar) |
| Cuál es cada disco | los números (`diskN`) cambian en cada arranque: identifica los discos por el nombre (`diskutil list`) |
| ¿Se cargó el kext? | `kmutil showloaded --list-only \| grep ntfsoficial` y `csrutil status` |
| Qué hizo el instalador | `cat /private/var/log/ntfsoficial-instalacao.log` (dice si falta permitir el kext o si el macOS es incompatible) |
| Registro de la detección y del montaje | `/usr/bin/log show --last 15m --predicate 'subsystem == "com.danielmanske.ntfsoficial"'` (en zsh, `log` solo es un comando interno y no muestra nada) |
| El disco quedó en solo lectura con el controlador de Apple | falta permitir el kext en Privacidad y seguridad + reiniciar; el registro muestra `kext não carregou (load_ntfsoficial = 1)` ("el kext no cargó") |

## Compilar en un Hackintosh (Intel)

Funciona con Xcode 26.5 y Homebrew en `/usr/local` (`autoconf`, `automake`, `libtool`, `pkgconf`). `compilar-usuario.sh`
ignora el `libintl.h` del gettext de Homebrew (`ac_cv_header_libintl_h=no`), que rompía el enlace de arm64. Para
instalar, mejor el `.pkg` de la Release: es el que se probó.

## Historial

- **19/10/2026, 0.2.0: no funcionó.** El kext pedía el kernel de macOS 27 y era rechazado antes de pedir permiso (no
  aparecía nada en Privacidad y seguridad); los discos NTFS desaparecieron del Finder y su nombre pasó a ser el aviso
  `WARNING: Dirty volume mount was forced…`. Corregido en la 0.2.1.
- **19/10/2026, 0.2.1:** probada aquí y en un Mac con chip de Apple con el mismo paquete, y publicada. Durante la
  prueba, los discos montados al arrancar quedaban a nombre de `root`/`_windowserver` (`git` los rechazaba); corregido
  antes de publicar (dueño 99).
- 17/10/2026: guía escrita antes de la primera prueba.
