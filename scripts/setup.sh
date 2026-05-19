#!/usr/bin/env bash
# Set up the meshtastic-firmware checkout so this repo can build out-of-tree:
#   1. Clone upstream meshtastic/firmware into external/ (if missing).
#   2. Symlink our variant + board JSON into the upstream tree.
#   3. Apply every patches/*.patch on top of upstream develop.
#
# Idempotent — safe to re-run after pulling SQ-Solar5262 or after adding a
# new patch under patches/. Re-runs skip the clone and the symlinks if already
# in place; patch application is gated on `git apply --reverse --check` so an
# already-applied patch is silently skipped.

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
FW="$ROOT/external/meshtastic-firmware"

# 1. Clone upstream if missing.
if [[ ! -d "$FW/.git" ]]; then
  echo "==> Cloning meshtastic/firmware into external/"
  mkdir -p "$ROOT/external"
  git clone --depth 1 --recursive \
    https://github.com/meshtastic/firmware.git "$FW"
else
  echo "==> external/meshtastic-firmware already present, skipping clone"
fi

# 2. Symlink variant + board JSON (absolute paths — see docs/decision_log.md).
ln -sfn "$ROOT/src/variant/ht_n5262m"        "$FW/variants/nrf52840/ht_n5262m"
ln -sfn "$ROOT/src/boards/ht_n5262m.json"    "$FW/boards/ht_n5262m.json"
echo "==> Symlinks in place"

# 3. Apply patches/ in lexical order. Skip ones already applied.
shopt -s nullglob
for patch in "$ROOT"/patches/*.patch; do
  name="$(basename "$patch")"
  if git -C "$FW" apply --reverse --check "$patch" >/dev/null 2>&1; then
    echo "==> $name already applied, skipping"
  else
    echo "==> Applying $name"
    git -C "$FW" apply "$patch"
  fi
done

echo "==> Setup complete. Build: (cd external/meshtastic-firmware && pio run -e ht_n5262m)"
