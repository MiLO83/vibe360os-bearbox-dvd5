#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SHELL_SRC="${SCRIPT_DIR}/drwatson-shell"
SHELL_DST="/usr/local/sbin/drwatson-shell"
DECOY_USER="${DECOY_USER:-drwatson}"

install -o root -g root -m 0755 "$SHELL_SRC" "$SHELL_DST"
touch /var/log/drwatson-shell.log
chown root:adm /var/log/drwatson-shell.log || chown root:root /var/log/drwatson-shell.log
chmod 0640 /var/log/drwatson-shell.log

if ! grep -qxF "$SHELL_DST" /etc/shells; then
  echo "$SHELL_DST" >> /etc/shells
fi

if ! id "$DECOY_USER" >/dev/null 2>&1; then
  adduser \
    --disabled-password \
    --gecos "Dr. Watson Decoy Console" \
    --shell "$SHELL_DST" \
    "$DECOY_USER"
else
  chsh -s "$SHELL_DST" "$DECOY_USER"
fi

passwd -l "$DECOY_USER" >/dev/null || true
usermod -L "$DECOY_USER" >/dev/null || true

cat >/etc/sudoers.d/99-drwatson-no-sudo <<EOF
${DECOY_USER} ALL=(ALL:ALL) !ALL
EOF
chmod 0440 /etc/sudoers.d/99-drwatson-no-sudo

cat <<EOF
Installed Dr. Watson decoy shell.

Decoy user:       ${DECOY_USER}
Decoy shell:      ${SHELL_DST}
Attempt log:      /var/log/drwatson-shell.log

Real access should be configured on a separate admin account with SSH keys.
EOF
