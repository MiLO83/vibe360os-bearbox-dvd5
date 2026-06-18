# BearBox / Vibe360 OS DVD5 Kit

Bootable DVD5 install and runtime media for a headless Linux workstation that can
serve a Meta Quest WebXR coding environment.

The kit builds two bootable ISOs:

- **Disc 1, `BEARBOX_D1`**: Ubuntu Server install/refresh disc with BearBox
  bootstrap, Dr. Watson decoy shell, browser terminal support, Cloudflare Tunnel
  helper, multiboot support, and explicit wipe options.
- **Disc 2, `BEARBOX_D2`**: live/runtime boot-key disc with the WebXR vibe
  runtime payload and physical boot-key token.

## Safety Model

Disc 1 has no fixed Linux username or password embedded by default.

At install time, Ubuntu asks for:

- admin username
- admin password
- storage choice

Disc 1 offers three storage workflows:

- **Install/Refresh**: identity and storage are interactive; best for multiboot
  or installing onto one chosen partition.
- **Full Wipe Install**: identity is interactive, storage uses Ubuntu LVM layout,
  and the selected target disk is erased.
- **Manual Non-Installer Disk Wipe**: a dry-run-first utility that wipes
  candidate disks while excluding the mounted installer/source media.

The manual wipe utility is available on Disc 1:

```bash
sudo /cdrom/bearbox-wipe-non-install-disks.sh
sudo /cdrom/bearbox-wipe-non-install-disks.sh --wipe
```

It requires typing:

```text
WIPE NON INSTALL DISKS
```

## Multiboot

For installation alongside Windows or another OS:

1. Back up the existing OS.
2. Create free/unallocated space first if possible.
3. Boot Disc 1.
4. Choose the normal **Install/Refresh** menu entry.
5. In storage, choose manual/custom partitioning.
6. Preserve the existing EFI System Partition.
7. Mount the BearBox partition as `/`.

First boot installs `os-prober`, enables the GRUB menu, and updates GRUB so
other operating systems can appear.

## Quest / Remote Access

The first-boot bootstrap installs:

- OpenSSH
- `ttyd` authenticated browser terminal on `127.0.0.1:7681`
- Cloudflare Tunnel helper
- VNC/XFCE helper
- GitHub CLI
- Codex CLI
- NVIDIA driver/CUDA bootstrap attempts

Recommended Cloudflare Tunnel routes:

```text
terminal hostname -> http://127.0.0.1:7681
WebXR hostname    -> http://127.0.0.1:5173
```

Protect public terminal/WebXR hostnames with Cloudflare Access.

## Build

From WSL Ubuntu or Linux:

```bash
cd /path/to/dvd5-refresh-disc
bash scripts/download-base-ubuntu.sh
bash scripts/build-bearbox-isos.sh
```

Useful variables:

```bash
BEARBOX_HOSTNAME=bearbox
BEARBOX_INTERACTIVE_IDENTITY=1
BEARBOX_STORAGE_MODE=interactive
BEARBOX_PUBLIC_KEY_FILE=/path/to/id_ed25519.pub
```

See [BUILD-VARIABLES.md](BUILD-VARIABLES.md).

## Burn

On Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\burn-disc1.ps1
```

For Disc 2:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\burn-disc1.ps1 -IsoPath .\out\bearbox-disc2-live-runtime-key.iso
```

## Generated Files

Generated private material is under `out/secrets/`.

Do not publish:

- `out/secrets/`
- generated ISO images in git history
- Cloudflare Tunnel tokens
- generated recovery passwords from non-interactive builds

The `.gitignore` excludes generated caches, secrets, ISO files, split release
parts, and verification extracts.

## Release Assets

The ISO files are DVD-sized, so do not commit them to git. For GitHub Releases,
split each ISO into chunks smaller than common release-asset limits:

```bash
cd out
split -b 1900M -d -a 2 bearbox-disc1-install-refresh.iso bearbox-disc1-install-refresh.iso.part-
split -b 1900M -d -a 2 bearbox-disc2-live-runtime-key.iso bearbox-disc2-live-runtime-key.iso.part-
sha256sum bearbox-disc*.iso bearbox-disc*.part-* > SHA256SUMS.release
```

Reassemble:

```bash
cat bearbox-disc1-install-refresh.iso.part-* > bearbox-disc1-install-refresh.iso
cat bearbox-disc2-live-runtime-key.iso.part-* > bearbox-disc2-live-runtime-key.iso
sha256sum -c SHA256SUMS.release
```

## Important Source Notes

- Disc 1 does not embed fixed Linux credentials by default.
- Disc 2 does not require or embed Linux credentials.
- The Disc 2 runtime service templates use placeholders and are rewritten during
  install to the actual sudo/admin user.
- The Dr. Watson shell is a decoy, not real security.

## Project Files

- [DISC-DESIGN.md](DISC-DESIGN.md): architecture and design notes
- [VR-XR-VIBE-CODING-SPEC.md](VR-XR-VIBE-CODING-SPEC.md): WebXR runtime plan
- [BUILD-VARIABLES.md](BUILD-VARIABLES.md): build customization
- [disc1/README-BEARBOX-DISC1.txt](disc1/README-BEARBOX-DISC1.txt): on-disc README
