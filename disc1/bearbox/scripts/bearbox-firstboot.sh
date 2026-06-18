#!/usr/bin/env bash
set -euo pipefail

LOG="/var/log/bearbox/firstboot.log"
exec > >(tee -a "$LOG") 2>&1

echo "== BearBox first boot bootstrap: $(date -Is) =="

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y \
  apt-transport-https \
  build-essential \
  ca-certificates \
  curl \
  dbus-x11 \
  fail2ban \
  firefox \
  git \
  gnupg \
  htop \
  lsb-release \
  net-tools \
  nodejs \
  nvtop \
  openssh-server \
  os-prober \
  pkg-config \
  python3 \
  python3-venv \
  npm \
  rsync \
  tigervnc-standalone-server \
  tmux \
  ttyd \
  ufw \
  unzip \
  wget \
  xfce4 \
  xfce4-goodies

systemctl enable --now bearbox-web-terminal.service || true

echo "== Multiboot GRUB support =="
install -d -m 0755 /etc/default/grub.d
cat >/etc/default/grub.d/99-bearbox-multiboot.cfg <<'EOF'
# BearBox enables os-prober so GRUB can discover other installed OS entries.
GRUB_DISABLE_OS_PROBER=false
GRUB_TIMEOUT_STYLE=menu
GRUB_TIMEOUT=10
EOF
if command -v update-grub >/dev/null 2>&1; then
  update-grub || true
fi

echo "== SSH hardening =="
install -d -m 0755 /etc/ssh/sshd_config.d
cat >/etc/ssh/sshd_config.d/99-bearbox-hardening.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
X11Forwarding no
AllowTcpForwarding yes
EOF
systemctl restart ssh || systemctl restart sshd || true

echo "== Firewall =="
ufw default deny incoming || true
ufw default allow outgoing || true
ufw allow OpenSSH || true
ufw --force enable || true

echo "== GitHub CLI official repository =="
if ! command -v gh >/dev/null 2>&1; then
  mkdir -p -m 755 /etc/apt/keyrings
  tmp_key="$(mktemp)"
  wget -nv -O "$tmp_key" https://cli.github.com/packages/githubcli-archive-keyring.gpg
  install -m 0644 "$tmp_key" /etc/apt/keyrings/githubcli-archive-keyring.gpg
  rm -f "$tmp_key"
  mkdir -p -m 755 /etc/apt/sources.list.d
  arch="$(dpkg --print-architecture)"
  echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" >/etc/apt/sources.list.d/github-cli.list
  apt-get update
  apt-get install -y gh
fi

echo "== Codex CLI standalone installer =="
if ! command -v codex >/dev/null 2>&1; then
  curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh
fi

echo "== Cloudflare Tunnel connector =="
if [[ -s /etc/bearbox/cloudflared-token ]]; then
  configure-cloudflare-tunnel || true
else
  echo "No /etc/bearbox/cloudflared-token yet; skipping internet tunnel auto-connect."
fi

echo "== NVIDIA driver attempt =="
apt-get install -y ubuntu-drivers-common linux-headers-generic
if command -v ubuntu-drivers >/dev/null 2>&1; then
  ubuntu-drivers autoinstall || true
fi

echo "== NVIDIA CUDA toolkit network repository attempt =="
if ! command -v nvcc >/dev/null 2>&1; then
  . /etc/os-release
  distro="${ID}${VERSION_ID//./}"
  arch_dir="x86_64"
  case "$(dpkg --print-architecture)" in
    amd64) arch_dir="x86_64" ;;
    arm64) arch_dir="sbsa" ;;
  esac
  cuda_keyring="/tmp/cuda-keyring_1.1-1_all.deb"
  cuda_url="https://developer.download.nvidia.com/compute/cuda/repos/${distro}/${arch_dir}/cuda-keyring_1.1-1_all.deb"
  if wget -nv -O "$cuda_keyring" "$cuda_url"; then
    dpkg -i "$cuda_keyring" || apt-get -f install -y
    apt-get update
    apt-get install -y cuda-toolkit || true
  else
    echo "CUDA keyring unavailable for ${distro}/${arch_dir}; skipping CUDA toolkit."
  fi
fi

echo "== VNC helper =="
cat >/usr/local/bin/bearbox-start-vnc <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$HOME/.vnc"
cat >"$HOME/.vnc/xstartup" <<'XEOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startxfce4
XEOF
chmod +x "$HOME/.vnc/xstartup"
exec vncserver :1 -localhost yes -geometry 1920x1080 -depth 24
EOF
chmod 0755 /usr/local/bin/bearbox-start-vnc

echo "== Marking firstboot complete =="
touch /var/lib/bearbox-firstboot-complete
systemctl disable bearbox-firstboot.service || true

echo "== BearBox first boot complete: $(date -Is) =="
