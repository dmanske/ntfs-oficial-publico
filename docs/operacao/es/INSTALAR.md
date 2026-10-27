# Instalar NTFS Oficial en un Mac

> Traducción de la guía en portugués [`../INSTALAR_EM_OUTRO_MAC.md`](../INSTALAR_EM_OUTRO_MAC.md), 19/10/2026. Si las dos
> no coinciden, la de portugués es la referencia. Los nombres de los menús pueden variar un poco según la versión de
> macOS. English: [`../en/INSTALL.md`](../en/INSTALL.md).

Para Mac con chip de Apple (M1, M2, M3, M4… todos iguales) y Mac Intel. Para un Hackintosh, ver
[`HACKINTOSH.md`](HACKINTOSH.md).

Probado de principio a fin con la 0.2.1 (19/10/2026, el mismo paquete) en un Mac con chip de Apple (macOS 27) y en un
Hackintosh Intel (macOS 26.6.2: kext cargado al arrancar, 4 discos internos montados con escritura; ver
[`HACKINTOSH.md`](HACKINTOSH.md)). Todavía no probado en un Mac Intel de verdad ni en macOS 14 y 15.

> **Usa la 0.2.1 o más nueva si no estás en macOS 27.** El kext de la 0.2.0 pedía el kernel de macOS 27 y era
> rechazado en las demás versiones, sin pedir aprobación; los discos NTFS desaparecían del Finder. Detalles (en
> portugués):
> [`../../correcoes/2026-10-19_kext-so-carregava-no-macos-27.md`](../../correcoes/2026-10-19_kext-so-carregava-no-macos-27.md).

## Por qué hay que preparar el Mac

NTFS Oficial usa su propia extensión de kernel (kext). Tuxera tiene un certificado especial de Apple para firmar kexts;
nosotros no (exige una cuenta de desarrollador de pago y una aprobación aparte de Apple). Sin ese certificado, macOS
solo carga el kext con la **Protección de la Integridad del Sistema (SIP)** desactivada.

El instalador (`.pkg`) y la app tampoco están firmados por Apple, así que macOS los bloquea hasta que los permitas
(paso 2).

**Requisitos:** macOS 14 (Sonoma) o más nuevo (el instalador rechaza macOS 13; el kext declara la KPI de macOS 14).
Desinstala o desactiva antes otros controladores NTFS (Tuxera, Paragon, macFUSE + ntfs-3g); la app avisa si encuentra
alguno.

## 1. Desactivar la protección del sistema (una vez)

### Mac con chip de Apple (M1, M2, M3, M4)

1. Apaga el Mac. Mantén pulsado el **botón de encendido** hasta que aparezca "Cargando opciones de arranque" →
   **Opciones** → Continuar (pide usuario y contraseña).
2. Menú **Utilidades → Utilidad Seguridad de Arranque** → elige el disco → **Política de seguridad…** → marca
   **Seguridad reducida** y **Permitir que el usuario gestione extensiones de kernel de desarrolladores
   identificados** → OK (pide la contraseña).
3. Menú **Utilidades → Terminal**:
   ```bash
   csrutil disable
   ```
   Responde `y` y escribe la contraseña.
4. Menú Apple → **Reiniciar**.

### Mac Intel

1. Reinicia manteniendo **Cmd + R** hasta que aparezca la manzana (modo de recuperación).
2. Menú **Utilidades → Terminal**:
   ```bash
   csrutil disable
   ```
3. Menú Apple → **Reiniciar**.

Los Mac Intel con chip T2 no necesitan la Utilidad Seguridad de Arranque para esto.

Comprueba después de reiniciar (Terminal normal):
```bash
csrutil status        # tiene que decir: System Integrity Protection status: disabled.
```

> Alternativa más restrictiva (desactiva solo la parte de kext, no probada aquí): en el Terminal de recuperación, usa
> `csrutil enable --without kext` en lugar de `csrutil disable`.

## 2. Permitir apps que no están firmadas por Apple

La forma más sencilla:

```bash
sudo spctl --master-disable
```

**Para qué sirve:** desactiva Gatekeeper, el bloqueo que solo deja abrir apps firmadas por Apple o descargadas del App
Store. Sin esto, macOS dice que `NTFS-Oficial-….pkg` "no se puede abrir porque es de un desarrollador no identificado".

- En macOS 15 (Sequoia) o más nuevo el comando solo no basta: después, abre **Ajustes del Sistema → Privacidad y
  seguridad → Permitir aplicaciones de** y elige **Cualquier sitio** (la opción solo aparece después del comando).
- Para volver a activar la protección: `sudo spctl --master-enable`.
- Sin desactivar Gatekeeper: clic derecho en el `.pkg` → **Abrir** → Abrir; o, si macOS no ofrece el botón,
  `xattr -d com.apple.quarantine ~/Downloads/NTFS-Oficial-*.pkg` y ábrelo de nuevo.

## 3. Instalar

1. Descarga `NTFS-Oficial-<versión>.pkg` de la página de Releases del repositorio público
   (https://github.com/dmanske/ntfs-oficial-publico/releases). El mismo archivo sirve para Intel y chip de Apple.
2. Abre el `.pkg` y sigue el instalador (pide la contraseña del Mac).
3. macOS muestra **"Extensión del sistema bloqueada"**. Abre **Ajustes del Sistema → Privacidad y seguridad**, baja
   hasta el aviso de NTFS Oficial y haz clic en **Permitir** (pide la contraseña).
4. **Reinicia** cuando macOS lo pida (en chip de Apple siempre lo pide; es cuando añade el kext al sistema).
5. Después de reiniciar, el icono de NTFS Oficial aparece en la barra de menús. Conecta un disco NTFS: se monta solo,
   con lectura y escritura.

Comprobar en el Terminal:
```bash
kmutil showloaded --list-only | grep ntfsoficial       # el kext cargado
mount | grep ntfsoficial                               # discos montados por NTFS Oficial
cat /private/var/log/ntfsoficial-instalacao.log        # lo que hizo el instalador
```

**Al actualizar:** instalar una versión nueva puede pedir que permitas el kext otra vez en Privacidad y seguridad y
reinicies; hasta entonces, los discos quedan en solo lectura con el controlador NTFS de Apple.

## Desinstalar

Haz doble clic en
`/Library/Filesystems/ntfsoficial.fs/Contents/Resources/Support/desinstalar-ntfs-oficial.command`
(pide la contraseña). Desmonta los discos y elimina la app, el servicio, el kext y el paquete.

Para volver a activar la protección del sistema después: modo de recuperación → Terminal → `csrutil enable` →
reiniciar (y, en chip de Apple, volver a **Seguridad completa** en la Utilidad Seguridad de Arranque).

## Problemas comunes

| Lo que aparece | Qué hacer |
|---|---|
| El disco aparece solo de lectura y la app avisa que Windows está hibernado | En Windows, desactiva el "Inicio rápido" y usa Apagar (no Hibernar). |
| El disco aparece solo de lectura y la app avisa "Windows Fast Startup" | Windows se apagó con el Inicio rápido. Conecta el disco a Windows y usa Reiniciar (no Apagar), o desactiva el Inicio rápido (Símbolo del sistema como administrador: `powercfg /h off`) y usa Apagar. |
| No se monta nada y `kmutil showloaded` no muestra `ntfsoficial` | Falta el paso 1 (`csrutil status`) o la aprobación en Privacidad y seguridad + reinicio. |
| La app avisa que hay otro controlador NTFS instalado | Desinstala el Tuxera/Paragon/macFUSE que indica. |
| El `.pkg` "no se puede abrir" | Paso 2. |
