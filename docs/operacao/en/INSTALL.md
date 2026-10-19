# Installing NTFS Oficial on a Mac

> Translated from the Portuguese guide [`../INSTALAR_EM_OUTRO_MAC.md`](../INSTALAR_EM_OUTRO_MAC.md) on 19/10/2026. If the two
> differ, the Portuguese one is the reference. Español: [`../es/INSTALAR.md`](../es/INSTALAR.md).

For Macs with Apple silicon (M1, M2, M3, M4… all the same) and Intel Macs. For a Hackintosh, see
[`HACKINTOSH.md`](HACKINTOSH.md).

Tested end to end with 0.2.1 (19/10/2026, the same package) on an Apple-silicon Mac (macOS 27) and on an Intel Hackintosh
(macOS 26.6.2: kext loaded at boot, 4 internal drives mounted read/write; see [`HACKINTOSH.md`](HACKINTOSH.md)). Not yet
tested on a real Intel Mac or on macOS 14 and 15.

> **Use 0.2.1 or newer if you are not on macOS 27.** The 0.2.0 kext required the macOS 27 kernel and was rejected on
> every other version, without asking for approval; NTFS drives disappeared from the Finder. Details (in Portuguese):
> [`../../correcoes/2026-10-19_kext-so-carregava-no-macos-27.md`](../../correcoes/2026-10-19_kext-so-carregava-no-macos-27.md).

## Why the Mac needs some preparation

NTFS Oficial uses its own kernel extension (kext). Tuxera has a special Apple certificate to sign kexts; we don't
(it requires a paid developer account and a separate approval from Apple). Without that certificate, macOS only loads
the kext with **System Integrity Protection (SIP)** turned off.

The installer (`.pkg`) and the app aren't signed by Apple either, so macOS blocks them until you allow them (step 2).

**Requirements:** macOS 14 (Sonoma) or newer (the installer refuses macOS 13; the kext declares the macOS 14 KPI).
Uninstall or turn off other NTFS drivers first (Tuxera, Paragon, macFUSE + ntfs-3g); the app warns you if it finds one.

## 1. Turn off System Integrity Protection (once)

### Mac with Apple silicon (M1, M2, M3, M4)

1. Shut down the Mac. Press and hold the **power button** until "Loading startup options" appears → **Options** →
   Continue (asks for your user and password).
2. Menu **Utilities → Startup Security Utility** → choose the disk → **Security Policy…** → select **Reduced
   Security** and **Allow user management of kernel extensions from identified developers** → OK (asks for your
   password).
3. Menu **Utilities → Terminal**:
   ```bash
   csrutil disable
   ```
   Answer `y` and type your password.
4. Apple menu → **Restart**.

### Intel Mac

1. Restart holding **Cmd + R** until the Apple logo appears (Recovery).
2. Menu **Utilities → Terminal**:
   ```bash
   csrutil disable
   ```
3. Apple menu → **Restart**.

Intel Macs with a T2 chip don't need the Startup Security Utility for this.

Check after restarting (regular Terminal):
```bash
csrutil status        # must say: System Integrity Protection status: disabled.
```

> A more restrictive alternative (turns off only the kext part, not tested here): in the Recovery Terminal, use
> `csrutil enable --without kext` instead of `csrutil disable`.

## 2. Allow apps that aren't signed by Apple

The simplest way:

```bash
sudo spctl --master-disable
```

**What it does:** turns off Gatekeeper, the lock that only lets you open apps signed by Apple or downloaded from the App
Store. Without it, macOS says `NTFS-Oficial-….pkg` "can't be opened because it is from an unidentified developer".

- On macOS 15 (Sequoia) or newer the command alone isn't enough: afterwards, open **System Settings → Privacy &
  Security → Allow applications from** and choose **Anywhere** (the option only shows up after the command).
- To turn the protection back on: `sudo spctl --master-enable`.
- Without turning Gatekeeper off: right-click the `.pkg` → **Open** → Open; or, if macOS doesn't offer the button,
  `xattr -d com.apple.quarantine ~/Downloads/NTFS-Oficial-*.pkg` and open it again.

## 3. Install

1. Download `NTFS-Oficial-<version>.pkg` from the Releases page of the public repository
   (https://github.com/dmanske/ntfs-oficial-publico/releases). The same file works on Intel and Apple silicon.
2. Open the `.pkg` and follow the installer (asks for your Mac password).
3. macOS shows **"System Extension Blocked"**. Open **System Settings → Privacy & Security**, scroll to the NTFS
   Oficial message and click **Allow** (asks for your password).
4. **Restart** when macOS asks (on Apple silicon it always does; that's when it adds the kext to the system).
5. After restarting, the NTFS Oficial icon appears in the menu bar. Plug in an NTFS drive: it mounts by itself, with
   read and write access.

Check in Terminal:
```bash
kmutil showloaded --list-only | grep ntfsoficial       # the loaded kext
mount | grep ntfsoficial                               # drives mounted by NTFS Oficial
cat /private/var/log/ntfsoficial-instalacao.log        # what the installer did
```

**Updating:** installing a new version may ask you to allow the kext again in Privacy & Security and restart; until
you do, your drives stay read-only through Apple's own NTFS driver.

## Uninstall

Double-click
`/Library/Filesystems/ntfsoficial.fs/Contents/Resources/Support/desinstalar-ntfs-oficial.command`
(asks for your password). It unmounts the drives and removes the app, the service, the kext and the package.

To turn system protection back on afterwards: Recovery → Terminal → `csrutil enable` → restart (and, on Apple
silicon, go back to **Full Security** in the Startup Security Utility).

## Common problems

| What you see | What to do |
|---|---|
| The drive is read-only and the app says Windows is hibernated | In Windows, turn off "Fast Startup" and use Shut down (not Hibernate). |
| Nothing mounts and `kmutil showloaded` doesn't show `ntfsoficial` | Step 1 is missing (`csrutil status`), or the approval in Privacy & Security + restart. |
| The app says another NTFS driver is installed | Uninstall the Tuxera/Paragon/macFUSE it points to. |
| The `.pkg` "can't be opened" | Step 2. |
