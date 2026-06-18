#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE="${ROOT}/cache"
mkdir -p "$CACHE"

cd "$CACHE"
curl -fL --continue-at - -O https://releases.ubuntu.com/noble/ubuntu-24.04.4-live-server-amd64.iso
curl -fL -O https://releases.ubuntu.com/noble/SHA256SUMS
grep 'ubuntu-24.04.4-live-server-amd64.iso$' SHA256SUMS >SHA256SUMS.server
sha256sum -c SHA256SUMS.server
