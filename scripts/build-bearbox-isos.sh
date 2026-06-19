#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE="${ROOT}/cache"
OUT="${ROOT}/out"
SECRETS="${OUT}/secrets"
BASE_ISO="${CACHE}/ubuntu-24.04.4-live-server-amd64.iso"
BASE_SUMS="${CACHE}/SHA256SUMS.server"

ADMIN_USER="${BEARBOX_ADMIN_USER:-}"
HOSTNAME="${BEARBOX_HOSTNAME:-bearbox}"
STORAGE_MODE="${BEARBOX_STORAGE_MODE:-interactive}"
INTERACTIVE_IDENTITY="${BEARBOX_INTERACTIVE_IDENTITY:-1}"
PUBLIC_KEY_FILE="${BEARBOX_PUBLIC_KEY_FILE:-${SECRETS}/bearbox_admin_ed25519.pub}"

DISC1_ISO="${OUT}/bearbox-disc1-install-refresh.iso"
DISC2_ISO="${OUT}/bearbox-disc2-live-runtime-key.iso"

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required tool: $1" >&2
    exit 1
  }
}

require xorriso
require sha256sum
require openssl
require rsync
require ssh-keygen

mkdir -p "$CACHE" "$OUT" "$SECRETS"

if [[ ! -f "$BASE_ISO" ]]; then
  echo "Missing base ISO: $BASE_ISO" >&2
  echo "Download it first with scripts/download-base-ubuntu.sh or the README command." >&2
  exit 1
fi

if [[ -f "$BASE_SUMS" ]]; then
  (cd "$CACHE" && sha256sum -c "$(basename "$BASE_SUMS")")
fi

if [[ ! -f "$PUBLIC_KEY_FILE" ]]; then
  ssh-keygen -t ed25519 -N "" -C "bearbox-admin-${ADMIN_USER}" -f "${SECRETS}/bearbox_admin_ed25519"
  PUBLIC_KEY_FILE="${SECRETS}/bearbox_admin_ed25519.pub"
fi

PUBLIC_KEY="$(awk '{print $1" "$2}' "$PUBLIC_KEY_FILE")"

if [[ ! -s "${SECRETS}/bearbox-runtime.key" ]]; then
  openssl rand -base64 48 >"${SECRETS}/bearbox-runtime.key"
  chmod 0600 "${SECRETS}/bearbox-runtime.key"
fi
BOOT_KEY_HASH="$(sha256sum "${SECRETS}/bearbox-runtime.key" | awk '{print $1}')"

if [[ ! -s "${SECRETS}/bearbox-auth-ed25519.pem" ]]; then
  openssl genpkey -algorithm ED25519 -out "${SECRETS}/bearbox-auth-ed25519.pem"
  chmod 0600 "${SECRETS}/bearbox-auth-ed25519.pem"
  openssl pkey -in "${SECRETS}/bearbox-auth-ed25519.pem" -pubout -out "${OUT}/bearbox-auth-ed25519.pub.pem"
fi

STAGE1="${OUT}/stage-disc1"
STAGE2="${OUT}/stage-disc2"
rm -rf "$STAGE1" "$STAGE2"
mkdir -p "$STAGE1/nocloud" "$STAGE1/nocloud-wipe" "$STAGE1/bearbox" "$STAGE1/boot/grub"
mkdir -p "$STAGE2/bearbox-live/boot-key" "$STAGE2/boot/grub"

rsync -a "${ROOT}/disc1/bearbox/" "$STAGE1/bearbox/"
install -m 0644 "${ROOT}/disc1/README-BEARBOX-DISC1.txt" "$STAGE1/README-BEARBOX-DISC1.txt"
install -m 0755 "${ROOT}/disc1/bearbox/scripts/bearbox-wipe-non-install-disks.sh" "$STAGE1/bearbox-wipe-non-install-disks.sh"
rsync -a "${ROOT}/scripts/drwatson-shell" "$STAGE1/bearbox/scripts/"
rsync -a "${ROOT}/scripts/install-drwatson-shell.sh" "$STAGE1/bearbox/scripts/"
rsync -a "${ROOT}/scripts/enable-drwatson-frontdesk.sh" "$STAGE1/bearbox/scripts/"

mkdir -p "$STAGE1/bearbox/config"
printf '%s  bearbox-runtime.key\n' "$BOOT_KEY_HASH" >"$STAGE1/bearbox/config/boot-key.sha256"
cat >"$STAGE1/bearbox/config/bearbox-build.env" <<EOF
BEARBOX_ADMIN_USER=${ADMIN_USER}
BEARBOX_HOSTNAME=${HOSTNAME}
BEARBOX_STORAGE_MODE=${STORAGE_MODE}
BEARBOX_INTERACTIVE_IDENTITY=${INTERACTIVE_IDENTITY}
BEARBOX_BUILD_TIME=$(date -Is)
EOF
printf '%s\n' "$PUBLIC_KEY" >"$STAGE1/bearbox/config/admin-authorized-key.pub"

cat >"$STAGE1/nocloud/meta-data" <<EOF
instance-id: bearbox-disc1-${HOSTNAME}
local-hostname: ${HOSTNAME}
EOF

cat >"$STAGE1/nocloud-wipe/meta-data" <<EOF
instance-id: bearbox-disc1-${HOSTNAME}-wipe
local-hostname: ${HOSTNAME}
EOF

cat >"$STAGE1/nocloud/user-data" <<EOF
#cloud-config
autoinstall:
  version: 1
  locale: en_US.UTF-8
  keyboard:
    layout: us
  ssh:
    install-server: true
    allow-pw: false
  packages:
    - openssh-server
    - ca-certificates
    - curl
    - wget
    - git
    - gnupg
    - lsb-release
EOF

cp "$STAGE1/nocloud/user-data" "$STAGE1/nocloud-wipe/user-data"

if [[ "$INTERACTIVE_IDENTITY" == "1" ]]; then
  cat >>"$STAGE1/nocloud/user-data" <<'EOF'
  interactive-sections:
    - identity
    - storage
EOF
  cat >>"$STAGE1/nocloud-wipe/user-data" <<'EOF'
  interactive-sections:
    - identity
EOF
elif [[ -n "$ADMIN_USER" ]]; then
  if [[ ! -s "${SECRETS}/recovery-password.txt" ]]; then
    {
      echo "# BearBox recovery password"
      echo "# Generated: $(date -Is)"
      echo "# Admin user: ${ADMIN_USER}"
      openssl rand -base64 24
    } >"${SECRETS}/recovery-password.txt"
    chmod 0600 "${SECRETS}/recovery-password.txt"
  fi
  RECOVERY_PASSWORD="$(tail -n 1 "${SECRETS}/recovery-password.txt")"
  PASSWORD_HASH="$(openssl passwd -6 "$RECOVERY_PASSWORD")"
  cat >>"$STAGE1/nocloud/user-data" <<EOF
  identity:
    hostname: ${HOSTNAME}
    realname: BearBox Admin
    username: ${ADMIN_USER}
    password: "${PASSWORD_HASH}"
EOF
  cat >>"$STAGE1/nocloud-wipe/user-data" <<EOF
  identity:
    hostname: ${HOSTNAME}
    realname: BearBox Admin
    username: ${ADMIN_USER}
    password: "${PASSWORD_HASH}"
EOF
else
  cat >&2 <<'EOF'
BEARBOX_INTERACTIVE_IDENTITY=0 requires BEARBOX_ADMIN_USER to be set.
EOF
  exit 1
fi

if [[ "$STORAGE_MODE" == "auto-wipe" ]]; then
  cat >>"$STAGE1/nocloud/user-data" <<'EOF'
  storage:
    layout:
      name: lvm
EOF
elif [[ "$INTERACTIVE_IDENTITY" != "1" ]]; then
  cat >>"$STAGE1/nocloud/user-data" <<'EOF'
  interactive-sections:
    - storage
EOF
fi

cat >>"$STAGE1/nocloud-wipe/user-data" <<'EOF'
  storage:
    layout:
      name: lvm
EOF

cat >>"$STAGE1/nocloud/user-data" <<EOF
  late-commands:
    - mkdir -p /target/opt/bearbox-refresh
    - cp -a /cdrom/bearbox/. /target/opt/bearbox-refresh/
    - curtin in-target --target=/target -- /bin/bash /opt/bearbox-refresh/scripts/bootstrap-target.sh
EOF

cat >>"$STAGE1/nocloud-wipe/user-data" <<EOF
  late-commands:
    - mkdir -p /target/opt/bearbox-refresh
    - cp -a /cdrom/bearbox/. /target/opt/bearbox-refresh/
    - curtin in-target --target=/target -- /bin/bash /opt/bearbox-refresh/scripts/bootstrap-target.sh
EOF

cat >"$STAGE1/boot/grub/grub.cfg" <<'EOF'
set timeout=30

loadfont unicode
terminal_output console

set menu_color_normal=white/black
set menu_color_highlight=black/light-gray

set bearbox_debug_args="console=tty0 loglevel=7 ignore_loglevel debug systemd.show_status=1 systemd.log_level=debug systemd.log_target=console rd.debug earlycon=efifb keep_bootcon efi=debug"
set bearbox_safe_debug_args="${bearbox_debug_args} nomodeset"
set bearbox_noefi_debug_args="${bearbox_safe_debug_args} noefi"
set bearbox_acpi_debug_args="${bearbox_safe_debug_args} noapic nolapic irqpoll pci=nomsi"
set bearbox_pci_debug_args="${bearbox_safe_debug_args} pci=nommconf,noaer,routeirq pcie_aspm=off"
set bearbox_acpi_off_debug_args="${bearbox_pci_debug_args} acpi=off"
set bearbox_gpu_blacklist_args="${bearbox_safe_debug_args} modprobe.blacklist=nouveau,nvidia,nvidia_drm,nvidia_modeset nouveau.blacklist=1 rd.driver.blacklist=nouveau video=efifb:off"
set bearbox_pci_resource_args="${bearbox_safe_debug_args} pci=nocrs,realloc=off,noaer pcie_aspm=off"

menuentry "BearBox Install/Refresh VERBOSE (safe graphics, confirm storage)" {
	set gfxpayload=text
	linux	/casper/vmlinuz autoinstall ds=nocloud\;s=/cdrom/nocloud/ ${bearbox_safe_debug_args} ---
	initrd	/casper/initrd
}
menuentry "BearBox Install/Refresh VERBOSE no EFI runtime" {
	set gfxpayload=text
	linux	/casper/vmlinuz autoinstall ds=nocloud\;s=/cdrom/nocloud/ ${bearbox_noefi_debug_args} ---
	initrd	/casper/initrd
}
menuentry "BearBox Install/Refresh VERBOSE ACPI/APIC fallback" {
	set gfxpayload=text
	linux	/casper/vmlinuz autoinstall ds=nocloud\;s=/cdrom/nocloud/ ${bearbox_acpi_debug_args} ---
	initrd	/casper/initrd
}
menuentry "BearBox Install/Refresh VERBOSE PCI bridge fallback" {
	set gfxpayload=text
	linux	/casper/vmlinuz autoinstall ds=nocloud\;s=/cdrom/nocloud/ ${bearbox_pci_debug_args} ---
	initrd	/casper/initrd
}
menuentry "BearBox Install/Refresh VERBOSE NVIDIA bus 23 blacklist" {
	set gfxpayload=text
	linux	/casper/vmlinuz autoinstall ds=nocloud\;s=/cdrom/nocloud/ ${bearbox_gpu_blacklist_args} ---
	initrd	/casper/initrd
}
menuentry "BearBox Install/Refresh VERBOSE PCI resource fallback" {
	set gfxpayload=text
	linux	/casper/vmlinuz autoinstall ds=nocloud\;s=/cdrom/nocloud/ ${bearbox_pci_resource_args} ---
	initrd	/casper/initrd
}
menuentry "BearBox Install/Refresh HWE NVIDIA bus 23 blacklist" {
	set gfxpayload=text
	linux	/casper/hwe-vmlinuz autoinstall ds=nocloud\;s=/cdrom/nocloud/ ${bearbox_gpu_blacklist_args} ---
	initrd	/casper/hwe-initrd
}
menuentry "BearBox Install/Refresh HWE PCI resource fallback" {
	set gfxpayload=text
	linux	/casper/hwe-vmlinuz autoinstall ds=nocloud\;s=/cdrom/nocloud/ ${bearbox_pci_resource_args} ---
	initrd	/casper/hwe-initrd
}
menuentry "BearBox Install/Refresh HWE ACPI off" {
	set gfxpayload=text
	linux	/casper/hwe-vmlinuz autoinstall ds=nocloud\;s=/cdrom/nocloud/ ${bearbox_acpi_off_debug_args} ---
	initrd	/casper/hwe-initrd
}
menuentry "BearBox Install/Refresh VERBOSE last resort ACPI off" {
	set gfxpayload=text
	linux	/casper/vmlinuz autoinstall ds=nocloud\;s=/cdrom/nocloud/ ${bearbox_acpi_off_debug_args} ---
	initrd	/casper/initrd
}
menuentry "BearBox FULL WIPE VERBOSE (DESTROYS selected disk)" {
	set gfxpayload=text
	linux	/casper/vmlinuz autoinstall ds=nocloud\;s=/cdrom/nocloud-wipe/ ${bearbox_safe_debug_args} ---
	initrd	/casper/initrd
}
menuentry "BearBox Install/Refresh normal graphics (verbose)" {
	set gfxpayload=keep
	linux	/casper/vmlinuz autoinstall ds=nocloud\;s=/cdrom/nocloud/ ${bearbox_debug_args} ---
	initrd	/casper/initrd
}
menuentry "BearBox FULL WIPE normal graphics (verbose, DESTROYS selected disk)" {
	set gfxpayload=keep
	linux	/casper/vmlinuz autoinstall ds=nocloud\;s=/cdrom/nocloud-wipe/ ${bearbox_debug_args} ---
	initrd	/casper/initrd
}
menuentry "Try or Install Ubuntu Server (stock)" {
	set gfxpayload=keep
	linux	/casper/vmlinuz ${bearbox_debug_args} ---
	initrd	/casper/initrd
}
menuentry "Ubuntu Server with the HWE kernel (stock)" {
	set gfxpayload=keep
	linux	/casper/hwe-vmlinuz ${bearbox_debug_args} ---
	initrd	/casper/hwe-initrd
}
grub_platform
if [ "$grub_platform" = "efi" ]; then
menuentry 'Boot from next volume' {
	exit 1
}
menuentry 'UEFI Firmware Settings' {
	fwsetup
}
else
menuentry 'Test memory' {
	linux16 /boot/memtest86+x64.bin
}
fi
EOF

rsync -a "${ROOT}/disc2/bearbox-live/" "$STAGE2/bearbox-live/"
install -m 0400 "${SECRETS}/bearbox-runtime.key" "$STAGE2/bearbox-live/boot-key/bearbox-runtime.key"

for unit in "$STAGE2"/bearbox-live/vibe-runtime/systemd/*.service; do
  if [[ -n "$ADMIN_USER" ]]; then
    sed -i "s/^User=.*/User=${ADMIN_USER}/; s/^Group=.*/Group=${ADMIN_USER}/" "$unit"
  fi
done

cat >"$STAGE2/boot/grub/grub.cfg" <<'EOF'
set timeout=30

loadfont unicode

set menu_color_normal=white/black
set menu_color_highlight=black/light-gray

menuentry "BearBox Live Runtime / Boot Key" {
	set gfxpayload=keep
	linux	/casper/vmlinuz  ---
	initrd	/casper/initrd
}
menuentry "Ubuntu Server with the HWE kernel (stock)" {
	set gfxpayload=keep
	linux	/casper/hwe-vmlinuz  ---
	initrd	/casper/hwe-initrd
}
grub_platform
if [ "$grub_platform" = "efi" ]; then
menuentry 'Boot from next volume' {
	exit 1
}
menuentry 'UEFI Firmware Settings' {
	fwsetup
}
else
menuentry 'Test memory' {
	linux16 /boot/memtest86+x64.bin
}
fi
EOF

(cd "$STAGE1" && find README-BEARBOX-DISC1.txt bearbox nocloud nocloud-wipe -type f -print0 | sort -z | xargs -0 sha256sum >"$STAGE1/bearbox/MANIFEST.sha256")
(cd "$STAGE2" && find bearbox-live -type f -print0 | sort -z | xargs -0 sha256sum >"$STAGE2/bearbox-live/MANIFEST.sha256")

rm -f "$DISC1_ISO" "$DISC2_ISO"

xorriso -indev "$BASE_ISO" -outdev "$DISC1_ISO" \
  -boot_image any replay \
  -volid "BEARBOX_D1" \
  -rm /boot/grub/grub.cfg -- \
  -map "$STAGE1/boot/grub/grub.cfg" /boot/grub/grub.cfg \
  -map "$STAGE1/README-BEARBOX-DISC1.txt" /README-BEARBOX-DISC1.txt \
  -map "$STAGE1/bearbox-wipe-non-install-disks.sh" /bearbox-wipe-non-install-disks.sh \
  -map "$STAGE1/nocloud" /nocloud \
  -map "$STAGE1/nocloud-wipe" /nocloud-wipe \
  -map "$STAGE1/bearbox" /bearbox

xorriso -indev "$BASE_ISO" -outdev "$DISC2_ISO" \
  -boot_image any replay \
  -volid "BEARBOX_D2" \
  -rm /boot/grub/grub.cfg -- \
  -map "$STAGE2/boot/grub/grub.cfg" /boot/grub/grub.cfg \
  -map "$STAGE2/bearbox-live" /bearbox-live

(
  cd "$OUT"
  sha256sum "$(basename "$DISC1_ISO")" "$(basename "$DISC2_ISO")" >SHA256SUMS.bearbox
  openssl pkeyutl -sign -rawin -inkey "$SECRETS/bearbox-auth-ed25519.pem" -in SHA256SUMS.bearbox -out SHA256SUMS.bearbox.sig || true
)

cat >"${OUT}/BUILD-RESULTS.txt" <<EOF
BearBox ISO build complete

Admin user: ${ADMIN_USER:-chosen interactively during install}
Hostname: ${HOSTNAME}
Storage mode: ${STORAGE_MODE}
Interactive identity: ${INTERACTIVE_IDENTITY}

Disc 1: ${DISC1_ISO}
Disc 2: ${DISC2_ISO}

Admin SSH public key: ${PUBLIC_KEY_FILE}
Admin SSH private key: ${PUBLIC_KEY_FILE%.pub}
Recovery password: ${INTERACTIVE_IDENTITY:+not embedded; chosen during install}
Boot key hash: ${BOOT_KEY_HASH}

Hashes: ${OUT}/SHA256SUMS.bearbox
Signature: ${OUT}/SHA256SUMS.bearbox.sig
Public verification key: ${OUT}/bearbox-auth-ed25519.pub.pem
EOF

cat "${OUT}/BUILD-RESULTS.txt"
