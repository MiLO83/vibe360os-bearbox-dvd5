# BearBox Post-Install Notes

## First Login

SSH as the generated admin user:

```bash
ssh <your-admin-user>@bearbox.local
```

The build process creates an SSH keypair under `dvd5-refresh-disc/out/secrets`
unless you provide `BEARBOX_PUBLIC_KEY_FILE`.

## First Boot

The first boot service installs network-dependent pieces:

- GitHub CLI from the official GitHub apt repository
- Codex CLI from the OpenAI standalone Linux installer
- NVIDIA drivers using Ubuntu driver tooling
- CUDA toolkit from NVIDIA's Ubuntu network repository
- VNC/XFCE helpers

Watch logs:

```bash
sudo journalctl -u bearbox-firstboot -f
```

## VNC

VNC is localhost-only. Tunnel it:

```bash
ssh -L 5901:localhost:5901 <your-admin-user>@bearbox.local
```

On the server:

```bash
bearbox-start-vnc
```

Then connect your VNC client to `localhost:5901`.

## Disc 2 Runtime Key

Insert Disc 2 and run:

```bash
sudo bearbox-verify-boot-key
sudo install-vibe-runtime-from-disc2
```

The boot-key gate starts vibe runtime services only after Disc 2 is verified.
