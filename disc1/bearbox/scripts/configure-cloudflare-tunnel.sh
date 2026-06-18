#!/usr/bin/env bash
set -euo pipefail

TOKEN_FILE="${1:-/etc/bearbox/cloudflared-token}"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo $0 [token-file]" >&2
  exit 1
fi

if [[ ! -s "$TOKEN_FILE" ]]; then
  cat >&2 <<EOF
Cloudflare tunnel token not found: ${TOKEN_FILE}

Create a remotely-managed Cloudflare Tunnel in Cloudflare Zero Trust, then save
the connector token here:

  sudo install -d -m 0700 /etc/bearbox
  sudo nano ${TOKEN_FILE}
  sudo chmod 0600 ${TOKEN_FILE}

Then rerun:

  sudo configure-cloudflare-tunnel
EOF
  exit 1
fi

token="$(tr -d '\r\n ' <"$TOKEN_FILE")"

if ! command -v cloudflared >/dev/null 2>&1; then
  mkdir -p --mode=0755 /usr/share/keyrings
  curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg >/usr/share/keyrings/cloudflare-main.gpg
  echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main" >/etc/apt/sources.list.d/cloudflared.list
  apt-get update
  apt-get install -y cloudflared
fi

cloudflared service install "$token"
systemctl enable --now cloudflared

echo "Cloudflare Tunnel connector installed and started."
echo "Publish these local services in the Cloudflare dashboard:"
echo "  Web terminal: http://127.0.0.1:7681"
echo "  WebXR runtime: http://127.0.0.1:5173"
