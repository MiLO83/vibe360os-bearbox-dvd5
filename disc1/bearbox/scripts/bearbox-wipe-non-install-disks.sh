#!/usr/bin/env bash
set -euo pipefail

CONFIRM_PHRASE="WIPE NON INSTALL DISKS"
DO_WIPE=0

usage() {
  cat <<EOF
BearBox non-install disk wipe utility

Dry run:
  sudo $0

Actually wipe:
  sudo $0 --wipe

This excludes:
  - the disk that backs /cdrom
  - any mounted BEARBOX_D1 or BEARBOX_D2 media
  - any disk containing a mounted partition with BearBox installer/runtime files

It then wipes other whole disks with wipefs and sgdisk.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ "${1:-}" == "--wipe" ]]; then
  DO_WIPE=1
elif [[ $# -gt 0 ]]; then
  usage >&2
  exit 2
fi

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

disk_of_path() {
  local path="$1"
  local src pk disk
  src="$(findmnt -no SOURCE --target "$path" 2>/dev/null || true)"
  [[ -z "$src" ]] && return 1
  pk="$(lsblk -no PKNAME "$src" 2>/dev/null | head -n 1 || true)"
  if [[ -n "$pk" ]]; then
    printf '/dev/%s\n' "$pk"
    return 0
  fi
  disk="$(lsblk -no NAME,TYPE "$src" 2>/dev/null | awk '$2 == "disk" { print $1; exit }')"
  [[ -n "$disk" ]] && printf '/dev/%s\n' "$disk"
}

declare -A EXCLUDE

for mountpoint in /cdrom /media /mnt; do
  if [[ -e "$mountpoint" ]]; then
    while IFS= read -r disk; do
      [[ -n "$disk" ]] && EXCLUDE["$disk"]=1
    done < <(disk_of_path "$mountpoint" 2>/dev/null || true)
  fi
done

while read -r source target fstype options; do
  [[ "$source" != /dev/* ]] && continue
  label="$(lsblk -no LABEL "$source" 2>/dev/null | head -n 1 || true)"
  if [[ "$label" == "BEARBOX_D1" || "$label" == "BEARBOX_D2" ]]; then
    pk="$(lsblk -no PKNAME "$source" 2>/dev/null | head -n 1 || true)"
    [[ -n "$pk" ]] && EXCLUDE["/dev/$pk"]=1
  fi

  if [[ -f "$target/README-BEARBOX-DISC1.txt" || -f "$target/bearbox-live/boot-key/bearbox-runtime.key" ]]; then
    pk="$(lsblk -no PKNAME "$source" 2>/dev/null | head -n 1 || true)"
    [[ -n "$pk" ]] && EXCLUDE["/dev/$pk"]=1
  fi
done < <(findmnt -rn -o SOURCE,TARGET,FSTYPE,OPTIONS)

mapfile -t DISKS < <(lsblk -dpno NAME,TYPE,RM,SIZE,MODEL | awk '$2 == "disk" { print }')

echo "Excluded install/source disks:"
if [[ "${#EXCLUDE[@]}" -eq 0 ]]; then
  echo "  none detected"
else
  for disk in "${!EXCLUDE[@]}"; do
    echo "  $disk"
  done | sort
fi

echo
echo "Candidate disks to wipe:"
declare -a CANDIDATES=()
for line in "${DISKS[@]}"; do
  disk="$(awk '{print $1}' <<<"$line")"
  if [[ -n "${EXCLUDE[$disk]:-}" ]]; then
    continue
  fi
  CANDIDATES+=("$disk")
  echo "  $line"
done

if [[ "${#CANDIDATES[@]}" -eq 0 ]]; then
  echo "No candidate disks found."
  exit 0
fi

if [[ "$DO_WIPE" -ne 1 ]]; then
  cat <<EOF

Dry run only. Nothing was wiped.
To wipe the candidate disks above, rerun:

  sudo $0 --wipe
EOF
  exit 0
fi

echo
echo "DANGER: this will destroy partition tables and filesystem signatures on:"
printf '  %s\n' "${CANDIDATES[@]}"
echo
printf 'Type exactly "%s" to continue: ' "$CONFIRM_PHRASE"
IFS= read -r answer
if [[ "$answer" != "$CONFIRM_PHRASE" ]]; then
  echo "Confirmation did not match. Aborting."
  exit 1
fi

for disk in "${CANDIDATES[@]}"; do
  echo "Wiping $disk"
  swapoff --all || true
  wipefs --all --force "$disk"
  sgdisk --zap-all "$disk" || true
  dd if=/dev/zero of="$disk" bs=1M count=32 conv=fsync status=progress
done

echo "Wipe complete."
