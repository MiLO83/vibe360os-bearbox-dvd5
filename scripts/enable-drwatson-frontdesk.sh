#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

DECOY_USER="${DECOY_USER:-drwatson}"
GETTY_DIR="/etc/systemd/system/getty@tty1.service.d"
SSH_BANNER="/etc/issue.net"
SSHD_DROPIN="/etc/ssh/sshd_config.d/99-drwatson-banner.conf"

if ! id "$DECOY_USER" >/dev/null 2>&1; then
  echo "User ${DECOY_USER} does not exist. Run install-drwatson-shell.sh first." >&2
  exit 1
fi

mkdir -p "$GETTY_DIR"
cat >"${GETTY_DIR}/override.conf" <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${DECOY_USER} --noclear %I \$TERM
EOF

cat >"$SSH_BANNER" <<'EOF'
Dr. Watson Diagnostic Console

This host does not provide a public shell.
Authorized operators should authenticate normally.
Everyone else may enjoy the confidence of being logged.
EOF

mkdir -p "$(dirname "$SSHD_DROPIN")"
cat >"$SSHD_DROPIN" <<EOF
Banner ${SSH_BANNER}
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
EOF

systemctl daemon-reload
systemctl restart ssh || systemctl restart sshd || true

cat <<EOF
Enabled Dr. Watson front desk.

Local tty1 now auto-opens the decoy shell as ${DECOY_USER}.
SSH now displays ${SSH_BANNER} before authentication.

Real access still requires a separate admin user with SSH keys.
EOF
