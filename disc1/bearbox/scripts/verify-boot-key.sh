#!/usr/bin/env bash
set -euo pipefail

EXPECTED_FILE="/etc/bearbox/boot-key.sha256"
KEY_RELATIVE="bearbox-live/boot-key/bearbox-runtime.key"
MOUNT_ROOT="/run/media"

if [[ ! -s "$EXPECTED_FILE" ]]; then
  echo "No expected boot-key hash at $EXPECTED_FILE" >&2
  exit 2
fi

expected="$(awk '{print $1}' "$EXPECTED_FILE")"

find_key() {
  local candidate
  for candidate in \
    "/cdrom/${KEY_RELATIVE}" \
    "/media/${KEY_RELATIVE}" \
    "${MOUNT_ROOT}/BEARBOX_D2/${KEY_RELATIVE}" \
    "/media/$USER/BEARBOX_D2/${KEY_RELATIVE}"; do
    [[ -f "$candidate" ]] && printf '%s\n' "$candidate" && return 0
  done

  local dev
  dev="$(blkid -L BEARBOX_D2 2>/dev/null || true)"
  if [[ -n "$dev" ]]; then
    mkdir -p "${MOUNT_ROOT}/BEARBOX_D2"
    if ! mountpoint -q "${MOUNT_ROOT}/BEARBOX_D2"; then
      mount -o ro "$dev" "${MOUNT_ROOT}/BEARBOX_D2"
    fi
    candidate="${MOUNT_ROOT}/BEARBOX_D2/${KEY_RELATIVE}"
    [[ -f "$candidate" ]] && printf '%s\n' "$candidate" && return 0
  fi

  return 1
}

key_path="$(find_key || true)"
if [[ -z "$key_path" ]]; then
  echo "BEARBOX_D2 boot key is not present." >&2
  exit 1
fi

actual="$(sha256sum "$key_path" | awk '{print $1}')"
if [[ "$actual" != "$expected" ]]; then
  echo "BEARBOX_D2 boot key hash mismatch." >&2
  exit 1
fi

echo "BEARBOX_D2 boot key verified at $key_path"
