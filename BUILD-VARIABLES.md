# BearBox Build Variables

Use environment variables to customize a build without editing scripts.

Defaults are safe for third-party use:

- No fixed Linux username is embedded.
- No fixed Linux password is embedded.
- The Ubuntu installer asks for identity and storage.
- Disc 2 contains no username or password.

## Variables

`BEARBOX_HOSTNAME`

- Default: `bearbox`
- Sets the target hostname.

`BEARBOX_INTERACTIVE_IDENTITY`

- Default: `1`
- `1`: ask for username/password during install.
- `0`: use `BEARBOX_ADMIN_USER` and a generated recovery password.

`BEARBOX_ADMIN_USER`

- Default: empty
- Only required when `BEARBOX_INTERACTIVE_IDENTITY=0`.

`BEARBOX_STORAGE_MODE`

- Default: `interactive`
- `interactive`: confirm target disk in installer.
- `auto-wipe`: use Ubuntu LVM layout automatically.

`BEARBOX_PUBLIC_KEY_FILE`

- Default: generated key under `out/secrets/`.
- Public key embedded in Disc 1 for SSH access after install.
- The key comment is stripped before embedding.

## Example

```bash
BEARBOX_HOSTNAME=vibebox \
BEARBOX_INTERACTIVE_IDENTITY=1 \
bash scripts/build-bearbox-isos.sh
```

## Secret Handling

Do not distribute `out/secrets/`.

For public releases, distribute source files plus build instructions, not a
prebuilt ISO that contains your personal SSH public key.
