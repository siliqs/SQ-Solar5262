#!/usr/bin/env bash
# Flash the Meshtastic ht_n5262m build to the board over SWD via DAPLink.
# Uses `program ... verify` (no mass_erase), so the Adafruit bootloader and
# S140 SoftDevice in the protected region are left untouched. To wipe the
# bootloader and recover Arduino, run ../25_HT5262M_test/scripts/restore_bootloader.sh.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HEX="$(ls -t "$REPO_ROOT"/external/meshtastic-firmware/.pio/build/ht_n5262m/firmware-ht_n5262m-*.hex 2>/dev/null | head -1)"
HELTEC_ROOT="$HOME/Library/Arduino15/packages/Heltec_nRF52/hardware/Heltec_nRF52/1.7.0"
OPENOCD="$HOME/Library/Arduino15/packages/arduino/tools/openocd/0.11.0-arduino2/bin/openocd"
OPENOCD_SCRIPTS="$HOME/Library/Arduino15/packages/arduino/tools/openocd/0.11.0-arduino2/share/openocd/scripts"
DAPLINK_CFG="$HELTEC_ROOT/scripts/openocd/daplink_nrf52.cfg"

if [[ -z "$HEX" || ! -f "$HEX" ]]; then
  echo "No hex found. Build first:" >&2
  echo "  (cd external/meshtastic-firmware && pio run -e ht_n5262m)" >&2
  exit 1
fi

echo "Flashing $HEX via DAPLink (SWD, no chip erase — preserves bootloader)..."
"$OPENOCD" -s "$OPENOCD_SCRIPTS" -f "$DAPLINK_CFG" \
  -c "init" \
  -c "reset halt" \
  -c "program \"$HEX\" verify" \
  -c "reset run" \
  -c "exit"
echo
echo "Done. App flashed. Watch boot log:"
echo "  screen /dev/cu.usbmodem21101 115200    # exit: Ctrl-A then K"
