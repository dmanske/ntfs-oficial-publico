# NTFS Oficial on a Hackintosh (OpenCore)

> Translated from the Portuguese guide [`../HACKINTOSH.md`](../HACKINTOSH.md) on 19/10/2026. If the two differ, the
> Portuguese one is the reference. Español: [`../es/HACKINTOSH.md`](../es/HACKINTOSH.md).

19/10/2026. **Tested and working** on an Intel Hackintosh with 0.2.1 (see [Tested](#tested-19102026-021)). Use
**0.2.1 or newer**: 0.2.0 only loaded the kext on macOS 27, and on every other version NTFS drives disappeared from the
Finder (details, in Portuguese:
[`../../correcoes/2026-10-19_kext-so-carregava-no-macos-27.md`](../../correcoes/2026-10-19_kext-so-carregava-no-macos-27.md)).

A Hackintosh uses the same universal `.pkg` as [`INSTALL.md`](INSTALL.md). The difference is how system protection is
turned off: on a Hackintosh the OpenCore `config.plist` controls it, not `csrutil` (OpenCore rewrites the value on every
boot, if configured to). Things marked ⚠️ are not tested yet.

## Tested (19/10/2026, 0.2.1)

- **PC:** Intel `x86_64`, macOS 26.6.2 (kernel 25.6.0), OpenCore REL-107-2026-03-20, `csr-active-config` = `03080000`
  (`csrutil status` → `Kext Signing: disabled`). `SecureBootModel` left unchanged.
- **Package:** `NTFS-Oficial-0.2.1.pkg` from the Release, SHA-256 `a08bc259991ba6be8a6672ceeb4630f342606d323af78c33574ead900ac51f0b`.
- **Kext:** 0.1.1 loaded at boot (`kmutil showloaded`), OpenCore didn't block it. First run of the kext on an Intel
  processor (not yet on a real Intel Mac).
- **Drives:** the 4 internal Windows drives mount by themselves at boot through NTFS Oficial, read/write, with the right
  names. They show up as owned by the user (`ls -ln` → `501 20`; as root, `99 99`) and `git` works on them.
- **Drive flagged for chkdsk** (`VOLUME_IS_DIRTY`, clean journal): mounts read/write, as NTFS-3G does. The flag stays on
  the drive until chkdsk runs on Windows; NTFS Oficial doesn't clear it.
- **Installing over another version:** macOS asked to allow the kext again. Until allowed and restarted, the drives were
  read-only through Apple's NTFS driver (they don't disappear).
- ⚠️ Not tested: AMD processors, option B, macOS 14/15.

## Before you start

- Write down your macOS and OpenCore versions (`nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version`).
- Intel or AMD processor: the kext is generic `x86_64` and should work on both. ⚠️ AMD not tested.
- **Back up your EFI** (USB stick) before touching `config.plist`.
- Uninstall or turn off other NTFS drivers (Tuxera, Paragon, macFUSE + ntfs-3g).

## Option A (recommended, tested): turn off kext checking in config.plist

In `EFI/OC/config.plist` (ProperTree or OCAT):

1. `NVRAM → Add → 7C436110-AB2A-4BBB-A880-FE41995C9F82 → csr-active-config` (type **Data**) = `03000000`
   - `0x3` = kexts not signed by Apple (`0x1`) + unrestricted file system (`0x2`). That's the minimum for our kext.
     If there's already a value that includes `0x1` (e.g. `03080000`, the one on the tested PC, or `EF0F0000`), leave
     it as is.
2. `NVRAM → Delete → 7C436110-AB2A-4BBB-A880-FE41995C9F82` must contain `csr-active-config` (otherwise the old NVRAM
   value still applies).
3. Save, restart, choose **Reset NVRAM** once in the OpenCore picker, and boot macOS.
4. Check: `csrutil status` must show `Kext Signing: disabled` (or SIP fully disabled).
5. Follow steps 2 and 3 of the [regular guide](INSTALL.md): allow Gatekeeper, install the `.pkg`, allow it in System
   Settings → Privacy & Security, and restart.
6. Only if the kext still doesn't load: `Misc → Security → SecureBootModel` = `Disabled` (Apple Secure Boot rejects
   third-party kexts outside OpenCore). It wasn't needed on the tested PC.

## Option B (alternative, ⚠️ not tested): OpenCore injects the kext

Should work even with SIP on, because OpenCore puts the kext in the kernel before macOS starts.

1. Install the `.pkg` normally (the app, the detector and the service come from it).
2. Copy `/Library/Filesystems/ntfsoficial.fs/Contents/Extensions/ntfsoficial.kext` to `EFI/OC/Kexts/`.
3. `Kernel → Add`, new entry: `BundlePath` = `ntfsoficial.kext`, `ExecutablePath` = `Contents/MacOS/ntfsoficial`,
   `PlistPath` = `Contents/Info.plist`, `Arch` = `x86_64`, `MinKernel` = `23.0.0` (macOS 14, the 0.2.1 minimum),
   `Enabled` = `true`.
4. Restart.

Known gap: the kext is normally loaded by `load_ntfsoficial`, which also sets
`vfs.generic.ntfsoficial.tunables.allow_other=1` and the admin group (without them, mounting from the Finder fails).
With the kext injected, that step doesn't run by itself after a restart. Option B needs an adjustment (e.g. the NTFS
Oficial service setting both `sysctl` values at startup). That's why option A is the recommended one.

## Updating later

- **Option A:** install the new `.pkg`. If the kext file changed (even just its `Info.plist`), macOS asks you to allow it
  again and restart; until then, drives stay read-only through Apple's NTFS driver.
- **Option B:** besides the `.pkg`, replace `ntfsoficial.kext` in the EFI.

## Problems and tips

| What | How |
|---|---|
| Go back to read-only through Apple's NTFS driver, without uninstalling | `sudo defaults write /Library/Preferences/com.danielmanske.ntfsoficial DisableDriver -int 1` and restart. To undo: `sudo defaults delete /Library/Preferences/com.danielmanske.ntfsoficial DisableDriver` |
| Uninstall | see the [regular guide](INSTALL.md#uninstall) |
| Which drive is which | the numbers (`diskN`) change on every boot: identify drives by name (`diskutil list`) |
| Is the kext loaded? | `kmutil showloaded --list-only \| grep ntfsoficial` and `csrutil status` |
| What the installer did | `cat /private/var/log/ntfsoficial-instalacao.log` (says whether you still need to allow the kext or the macOS is incompatible) |
| Detection and mount log | `/usr/bin/log show --last 15m --predicate 'subsystem == "com.danielmanske.ntfsoficial"'` (in zsh, plain `log` is a built-in and shows nothing) |
| Drive became read-only through Apple's driver | the kext still needs to be allowed in Privacy & Security + restart; the log shows `kext não carregou (load_ntfsoficial = 1)` ("kext didn't load") |
| Restarts by itself when another Mac opens one of its NTFS drives over the network (the report says `What kind of a flag is this` and `smbd`) | up to 0.2.1 (kext 0.1.1); fixed in 0.2.2 (kext 0.1.2). While on 0.2.1, remove the NTFS drives from the shared folders (System Settings → General → Sharing → File Sharing) |
| Everything that uses an NTFS drive stops responding (Finder, FinderX, Spotlight, the NTFS Oficial app) and only a restart brings it back | up to 0.2.1: a program was quit while it was waiting for the drive and the kext got stuck in a loop. Fixed in 0.2.2 (kext 0.1.2). On 0.2.1, restart |

## Building on a Hackintosh (Intel)

Works with Xcode 26.5 and Homebrew in `/usr/local` (`autoconf`, `automake`, `libtool`, `pkgconf`). `compilar-usuario.sh`
ignores the gettext `libintl.h` from Homebrew (`ac_cv_header_libintl_h=no`), which broke the arm64 link. To install,
prefer the `.pkg` from the Release: that's the one that was tested.

## History

- **19/10/2026, 0.2.0: didn't work.** The kext required the macOS 27 kernel and was rejected before asking for
  permission (nothing showed up in Privacy & Security); NTFS drives disappeared from the Finder and their name became
  the warning `WARNING: Dirty volume mount was forced…`. Fixed in 0.2.1.
- **19/10/2026, 0.2.1:** tested here and on an Apple-silicon Mac with the same package, and released. During testing,
  drives mounted at boot were owned by `root`/`_windowserver` (`git` refused them); fixed before release (owner 99).
- **20/10/2026, 0.2.1: kernel panic when sharing.** Opening a Hackintosh folder on an NTFS drive from the MacBook Air
  (Finder → Network) made the Hackintosh restart: `smbd` opens the files with neither read nor write (`O_EVTONLY`)
  and the kext panicked. The other direction worked. Fixed in 0.2.2 (kext 0.1.2), **tested here on 22/10/2026**:
  from the MacBook Air, the shared NTFS drives open, browse and copy in both directions, with no restart.
- **20/10/2026, 0.2.1: drive stuck.** FinderX, Spotlight and the NTFS Oficial app froze on one of the NTFS drives:
  the display mirroring helper from System Settings was quit while it was waiting for the drive, and the kext kept
  spinning with the request's lock, never letting the driver work. Fixed in 0.2.2 (kext 0.1.2). **Used here up to
  22/10/2026** (Screen Sharing included) with no stuck drive.
- 17/10/2026: guide written before the first test.
