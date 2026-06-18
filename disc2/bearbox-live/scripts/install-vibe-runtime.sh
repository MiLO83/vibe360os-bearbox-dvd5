#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
install -d -m 0755 /opt/vibes
rsync -a --delete vibe-runtime/ /opt/vibes/
cd /opt/vibes
npm install
systemctl daemon-reload
systemctl enable vibe-patch.service vibe-webxr.service
systemctl restart vibe-patch.service vibe-webxr.service
