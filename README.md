# panther-ideal-kernel

Custom kernel CI for **Google Pixel 7 (panther) / 7 Pro (cheetah) / 7a (lynx)** — gs201 / Tensor G2, Android 16 (6.1 GKI).

Built for custom ROMs (MistOS, LineageOS, etc.) with maximum root stealth as the goal — the kernel half of a Play Integrity **STRONG** setup.

## What's inside

| Component | Source |
|---|---|
| Base kernel | [Sultan kernel](https://github.com/kerneltoast/android_kernel_google_tensynos) (gs201, A16) |
| Root | [KernelSU-Next](https://github.com/pershoot/KernelSU-Next) (`dev-susfs`, built-in, non-GKI hooks) |
| Hiding | [SUSFS](https://gitlab.com/simonpunk/susfs4ksu) (`gki-android14-6.1`) + pershoot coexistence patches |
| Extras | Mountify support (TMPFS xattr/ACL), BBR TCP, IPSet, IPv6 NAT, TTL/HL spoofing |
| Packaging | AnyKernel3 (`sultan-gs201`), flashable via Kernel Flasher |

## Build

GitHub → **Actions → Build panther ideal kernel → Run workflow**:

- `variant`: `ksun-susfs` (default, main target) · `ksun` (no SUSFS, manual hooks) · `stock` (pure Sultan, sanity build)
- `susfs_branch`: keep `gki-android14-6.1` for gs201 on A16
- `make_release`: publishes a tagged Release with the zip; otherwise grab the Actions artifact

Output: `gs201-a16-ideal-<variant>-anykernel3.zip`

## Flash

1. Be on firmware/ROM matching the current monthly patch level (kernel and ROM patch levels must match — mismatch = bootloop risk).
2. Back up `boot`, `init_boot`, `vendor_boot`, `vendor_kernel_boot` first.
3. Flash the zip with [Kernel Flasher](https://github.com/capntrips/KernelFlasher) (or fastboot), reboot.
4. Install the KernelSU-Next manager and the [ksu_module_susfs](https://github.com/sidex15/ksu_module_susfs) module.

## The STRONG integrity chain (userspace part)

The kernel only covers root + hiding. For 3/3 Play Integrity you still need:

1. **TrickyStore** + a valid, unrevoked `keybox.xml` (public keyboxes get revoked fast)
2. **PlayIntegrityFork** (osm0sis) with a fresh fingerprint
3. **ReZygisk** or **ZygiskNext** + hiding (sus_path / sus_mount / try_umount via the SUSFS module)
4. SELinux **Enforcing**, no suspicious props, Play Services/Play Store data cleared after setup

## Warning

Flashing kernels can brick your device. Never re-lock the bootloader on modified images. You are responsible for your own device.

---

Кратко по-русски: это CI-сборка ядра Sultan для Pixel 7 (gs201, Android 16) со встроенными KernelSU-Next и SUSFS. Сборка запускается во вкладке Actions, результат — AnyKernel3-zip для прошивки через Kernel Flasher. STRONG-integrity добивается связкой TrickyStore + валидный keybox + PlayIntegrityFork + ReZygisk.
