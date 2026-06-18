#!/usr/bin/env bash
set -euo pipefail

INSTALL_ROOT="/opt/bearbox-refresh"
ADMIN_USER="${BEARBOX_ADMIN_USER:-}"

find_admin_user() {
  if [[ -n "$ADMIN_USER" ]] && id "$ADMIN_USER" >/dev/null 2>&1; then
    printf '%s\n' "$ADMIN_USER"
    return 0
  fi

  getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 { print $1 }' | while read -r user; do
    if id -nG "$user" | grep -qw sudo; then
      printf '%s\n' "$user"
      return 0
    fi
  done
}

ADMIN_USER="$(find_admin_user | head -n 1 || true)"

install -d -m 0755 /etc/bearbox /var/log/bearbox /opt/vibes

if [[ -f "${INSTALL_ROOT}/config/boot-key.sha256" ]]; then
  install -m 0644 "${INSTALL_ROOT}/config/boot-key.sha256" /etc/bearbox/boot-key.sha256
fi

if [[ -f "${INSTALL_ROOT}/config/bearbox-build.env" ]]; then
  install -m 0644 "${INSTALL_ROOT}/config/bearbox-build.env" /etc/bearbox/build.env
fi

install -m 0755 "${INSTALL_ROOT}/scripts/bearbox-firstboot.sh" /usr/local/sbin/bearbox-firstboot
install -m 0755 "${INSTALL_ROOT}/scripts/configure-cloudflare-tunnel.sh" /usr/local/sbin/configure-cloudflare-tunnel
install -m 0755 "${INSTALL_ROOT}/scripts/verify-boot-key.sh" /usr/local/sbin/bearbox-verify-boot-key
install -m 0755 "${INSTALL_ROOT}/scripts/install-vibe-runtime-from-disc2.sh" /usr/local/sbin/install-vibe-runtime-from-disc2

install -m 0644 "${INSTALL_ROOT}/systemd/bearbox-firstboot.service" /etc/systemd/system/bearbox-firstboot.service
install -m 0644 "${INSTALL_ROOT}/systemd/bearbox-bootkey-gate.service" /etc/systemd/system/bearbox-bootkey-gate.service
install -m 0644 "${INSTALL_ROOT}/systemd/bearbox-web-terminal.service" /etc/systemd/system/bearbox-web-terminal.service

if [[ -x "${INSTALL_ROOT}/scripts/install-drwatson-shell.sh" ]]; then
  DECOY_USER=drwatson bash "${INSTALL_ROOT}/scripts/install-drwatson-shell.sh"
fi

systemctl enable ssh || true
systemctl enable bearbox-firstboot.service
systemctl enable bearbox-bootkey-gate.service
systemctl enable bearbox-web-terminal.service

if [[ -n "${ADMIN_USER}" ]] && id "${ADMIN_USER}" >/dev/null 2>&1; then
  if [[ -f "${INSTALL_ROOT}/config/admin-authorized-key.pub" ]]; then
    install -d -m 0700 -o "${ADMIN_USER}" -g "${ADMIN_USER}" "/home/${ADMIN_USER}/.ssh"
    cat "${INSTALL_ROOT}/config/admin-authorized-key.pub" >>"/home/${ADMIN_USER}/.ssh/authorized_keys"
    sort -u "/home/${ADMIN_USER}/.ssh/authorized_keys" -o "/home/${ADMIN_USER}/.ssh/authorized_keys"
    chown "${ADMIN_USER}:${ADMIN_USER}" "/home/${ADMIN_USER}/.ssh/authorized_keys"
    chmod 0600 "/home/${ADMIN_USER}/.ssh/authorized_keys"
  fi

  install -d -m 0700 -o "${ADMIN_USER}" -g "${ADMIN_USER}" "/home/${ADMIN_USER}/.bearbox"
  cp -a "${INSTALL_ROOT}/docs" "/home/${ADMIN_USER}/.bearbox/" 2>/dev/null || true
  chown -R "${ADMIN_USER}:${ADMIN_USER}" "/home/${ADMIN_USER}/.bearbox"
fi

cat >/etc/motd <<'EOF'
BearBox headless server

Real access: SSH with authorized keys.
Decoy access: Dr. Watson, who is very disappointed in your command choices.

Run `sudo journalctl -u bearbox-firstboot -u bearbox-bootkey-gate` for setup logs.
EOF
