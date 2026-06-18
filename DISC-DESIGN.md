# BearBox DVD5 Install/Refresh + Live Runtime Disc Design

## Research Snapshot

Current date: 2026-06-18.

Primary sources used:

- Ubuntu releases lists Ubuntu Server 24.04.4 LTS AMD64 as a 3.2 GB server
  install image, small enough for DVD5.
- Ubuntu Subiquity autoinstall supports NoCloud `user-data`/`meta-data` seed
  media and the `autoinstall` kernel parameter.
- NVIDIA CUDA 13.3 Linux documentation recommends Ubuntu network repository
  enablement through `cuda-keyring_1.1-1_all.deb`, then `apt update`, then
  `apt install cuda-toolkit`.
- GitHub CLI maintainers recommend their official Debian/Ubuntu apt repository
  over Ubuntu community `gh` packages.
- OpenAI Codex CLI docs recommend the standalone Linux installer:
  `curl -fsSL https://chatgpt.com/codex/install.sh | sh`, with
  `CODEX_NON_INTERACTIVE=1` for unattended installs.

## Disc 1: Install / Refresh

Name: `BEARBOX_D1`

Base: verified `ubuntu-24.04.4-live-server-amd64.iso`.

Purpose:

- Boot Ubuntu Server installer.
- Add a BearBox install menu entry.
- Provide NoCloud autoinstall data from `/nocloud`.
- Install a headless/admin-ready base system.
- Install authenticity and boot-key gates.
- Install Dr. Watson decoy terminal.
- Create first-boot bootstrap service for network-dependent components.

Default safety posture:

- Booting the disc is not immediately destructive.
- The normal Ubuntu installer menu remains available.
- The BearBox install entry is explicit.
- Storage is left interactive by default so the operator confirms the target
  disk instead of accidentally wiping the wrong machine.
- A full unattended wipe can be generated later by setting
  `BEARBOX_STORAGE_MODE=auto-wipe` when building Disc 1.
- The standard build also includes a separate explicit full-wipe menu entry
  backed by `/nocloud-wipe`, while keeping identity interactive.

Installed base:

- OpenSSH server with key-first access.
- `build-essential`, `git`, `curl`, `wget`, `unzip`, `ca-certificates`,
  `gnupg`, `lsb-release`, `tmux`, `htop`, `nvtop`, `ufw`, `fail2ban`.
- Lightweight VNC stack: TigerVNC + XFCE, intended for SSH tunnels only.
- Official GitHub CLI apt repository and `gh`.
- Codex CLI standalone installer.
- NVIDIA driver autoinstall through Ubuntu driver tooling.
- CUDA toolkit through NVIDIA network apt repository.
- Dr. Watson decoy shell and optional local tty front desk.
- Boot-key gate that looks for Disc 2 before enabling runtime vibe services.
- Authenticated browser terminal on `127.0.0.1:7681` using `ttyd login`.
- Optional Cloudflare Tunnel connector for internet access without opening
  router ports.
- Multiboot support: storage remains interactive, `os-prober` is installed,
  GRUB menu timeout is enabled, and GRUB is updated after first boot.

## Disc 2: Live Runtime / Boot Key

Name: `BEARBOX_D2`

Base: the same verified Ubuntu Server ISO, rebuilt with a different volume ID
and additional runtime files.

Purpose:

- Bootable rescue/live runtime media.
- Carry the physical boot key file.
- Carry runtime source files for the WebXR vibe environment.
- Act as an offline local payload source for `/opt/vibes`.
- Let the installed system verify that the key disc is present before starting
  vibe services.

Boot-key model:

- Build process creates a random boot-key token.
- Disc 2 contains the token under `/bearbox-live/boot-key/bearbox-runtime.key`.
- Disc 1 embeds only the SHA256 hash in `/etc/bearbox/boot-key.sha256`.
- Installed system checks the inserted Disc 2 by volume label and token hash.
- Missing or wrong Disc 2 does not brick the OS; it withholds vibe runtime
  services and logs the reason.

This is a physical runtime gate, not cryptographic DRM. Anyone with Disc 2 can
copy the key, which is fine for the intended "disc as talisman/key" behavior.

## Vibe Runtime Direction

The initial runtime is a WebXR app served by the Linux box and opened in Meta
Quest Browser:

- Three.js renders the 360 degree world.
- WebXR uses `immersive-vr` first; passthrough AR becomes a separate mode later.
- A websocket patch server accepts structured scene patches.
- Codex/ChatGPT edits files or emits patches on the Linux server.
- Quest refreshes or receives live patches over the LAN.

First runtime services:

- `vibe-webxr.service`: serves the WebXR app.
- `vibe-patch.service`: receives JSON scene patches.
- `bearbox-web-terminal.service`: serves a browser terminal that requires a
  normal Linux login before a shell is available.
- `bearbox-bootkey-gate.service`: enables or disables vibe services based on
  Disc 2 presence.

Internet access model:

- Do not expose raw SSH, VNC, ttyd, or Vite ports directly to the internet.
- Use Cloudflare Tunnel or an equivalent zero-trust tunnel.
- The disc installs the connector helper, but the Cloudflare tunnel token must
  be provided by the operator because it is a secret.
- Publish these tunnel routes after setup:
  - web terminal -> `http://127.0.0.1:7681`
  - WebXR runtime -> `http://127.0.0.1:5173`

## ISO Build Strategy

Use `xorriso` from WSL Ubuntu:

- Verify official Ubuntu ISO hash.
- Generate keys and secrets outside the ISO output.
- Stage `/nocloud`, `/bearbox`, `/bearbox-live`, and runtime files.
- Replace `/boot/grub/grub.cfg` with a BearBox-aware menu.
- Rebuild with `-boot_image any replay` so the original hybrid BIOS/UEFI boot
  configuration is preserved.
- Emit SHA256 manifests for both custom ISOs.

## Burn Strategy

Windows sees the optical writer as `G:`:

- `hp BDDVDRW CH20L`
- media loaded

Windows does not expose `Burn-DiskImage` in this environment, but
`C:\Windows\System32\isoburn.exe` exists. The burn script uses `isoburn.exe`
for Disc 1 after both ISO files exist and hashes are written.
