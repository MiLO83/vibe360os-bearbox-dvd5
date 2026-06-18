#!/usr/bin/env bash
set -euo pipefail

if ! /usr/local/sbin/bearbox-verify-boot-key; then
  echo "Disc 2 boot key verification failed; refusing runtime install." >&2
  exit 1
fi

SRC=""
for candidate in \
  "/run/media/BEARBOX_D2/bearbox-live/vibe-runtime" \
  "/media/BEARBOX_D2/bearbox-live/vibe-runtime" \
  "/cdrom/bearbox-live/vibe-runtime"; do
  if [[ -d "$candidate" ]]; then
    SRC="$candidate"
    break
  fi
done

if [[ -z "$SRC" ]]; then
  echo "Could not find Disc 2 vibe-runtime directory." >&2
  exit 1
fi

install -d -m 0755 /opt/vibes
rsync -a --delete "$SRC/" /opt/vibes/

if [[ -f /opt/vibes/package.json ]]; then
  cd /opt/vibes
  npm install
fi

if [[ -d /opt/vibes/systemd ]]; then
  admin_user="$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 { print $1 }' | while read -r user; do if id -nG "$user" | grep -qw sudo; then printf '%s\n' "$user"; break; fi; done)"
  if [[ -n "$admin_user" ]]; then
    sed -i "s/^User=.*/User=${admin_user}/; s/^Group=.*/Group=${admin_user}/" /opt/vibes/systemd/*.service
    chown -R "${admin_user}:${admin_user}" /opt/vibes
  fi
  install -m 0644 /opt/vibes/systemd/*.service /etc/systemd/system/
fi

systemctl daemon-reload
systemctl enable vibe-patch.service vibe-webxr.service
systemctl restart vibe-patch.service vibe-webxr.service
