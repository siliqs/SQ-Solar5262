#!/usr/bin/env bash
# Flash the Meshtastic ht_n5262m UF2 via the Heltec UF2 bootloader (drag-drop).
#
# Why DFU instead of SWD `program`:
#   SWD `program ... verify` writes the app to 0x26000 but does NOT update the
#   Adafruit bootloader settings page at 0xFF000. The Heltec bootloader reads
#   that page on boot to decide whether to launch the app; without an update
#   it treats the app slot as invalid and stays in DFU advertising mode
#   (using SoftDevice for BLE), so the app's Reset_Handler is never reached.
#   Symptom: openocd verifies OK, but USB CDC enumerates with no Meshtastic
#   output and breakpoints at Reset_Handler/main/setup never hit. Verified
#   2026-05-19 (see README "Bring-up history").
#
#   Drag-dropping the UF2 to /Volumes/HT-n5262 lets the bootloader update the
#   settings page atomically alongside the app, so it boots cleanly.
#
# DFU entry strategy:
#   1. If /Volumes/HT-n5262 is already mounted, just write the UF2.
#   2. Otherwise (DAPLink available, default) — write Adafruit's UF2 magic
#      0x57 to NRF_POWER->GPREGRET (0x4000051C) via openocd + soft-reset.
#      Bootloader reads GPREGRET on boot and mounts USB MSC for drag-drop.
#      This works whether the app, the OTA-mode bootloader, or a crashed
#      state is currently running.
#   3. If DAPLink is not available, fall back to `meshtastic --enter-dfu`
#      (writes 0xA8 = OTA mode — bootloader will be BLE-advertising and the
#      MSC volume will NOT mount; user must double-tap RESET to switch to
#      UF2 mode), or ask user to double-tap RESET manually.
#
# Usage:
#   ./scripts/flash_meshtastic_dfu.sh                  # auto via DAPLink
#   ./scripts/flash_meshtastic_dfu.sh manual           # skip auto-DFU; expects volume already mounted

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UF2="$(ls -t "$REPO_ROOT"/external/meshtastic-firmware/.pio/build/ht_n5262m/firmware-ht_n5262m-*.uf2 2>/dev/null | head -1)"
BL_VOLUME="/Volumes/HT-n5262"
MODE="${1:-auto}"

HELTEC_ROOT="$HOME/Library/Arduino15/packages/Heltec_nRF52/hardware/Heltec_nRF52/1.7.0"
OPENOCD="$HOME/Library/Arduino15/packages/arduino/tools/openocd/0.11.0-arduino2/bin/openocd"
OPENOCD_SCRIPTS="$HOME/Library/Arduino15/packages/arduino/tools/openocd/0.11.0-arduino2/share/openocd/scripts"
DAPLINK_CFG="$HELTEC_ROOT/scripts/openocd/daplink_nrf52.cfg"

if [[ -z "$UF2" || ! -f "$UF2" ]]; then
  echo "No UF2 found. Build first:" >&2
  echo "  (cd external/meshtastic-firmware && pio run -e ht_n5262m)" >&2
  exit 1
fi

# Locate the target's USB CDC port. Filters down to the Heltec/Silic Meshtastic
# device by Vendor string in IORegistry — won't confuse with DAPLink CDC.
find_target_port() {
  python3 - <<'PY' 2>/dev/null
import plistlib, subprocess, sys
xml = subprocess.run(["ioreg","-arc","IOUSBHostDevice","-l"], capture_output=True).stdout
try: tree = plistlib.loads(xml)
except Exception: sys.exit(0)
def walk(node):
    if isinstance(node, dict):
        if node.get("USB Vendor Name","") in ("Heltec/Silic","Heltec AutoMation"):
            for child in node.get("IORegistryEntryChildren", []) or []:
                tty = find_tty(child)
                if tty:
                    print(tty); return
        for child in node.get("IORegistryEntryChildren", []) or []:
            walk(child)
    elif isinstance(node, list):
        for item in node: walk(item)
def find_tty(node):
    if isinstance(node, dict):
        if "IOCalloutDevice" in node:
            return node["IOCalloutDevice"]
        for child in node.get("IORegistryEntryChildren", []) or []:
            r = find_tty(child)
            if r: return r
    return None
walk(tree)
PY
}

daplink_attached() {
  [[ -x "$OPENOCD" && -f "$DAPLINK_CFG" ]] || return 1
  system_profiler SPUSBDataType 2>/dev/null | grep -q "DAPLink CMSIS-DAP"
}

# Write Adafruit's DFU_MAGIC_UF2_RESET (0x57) into NRF_POWER->GPREGRET, then
# soft-reset. The bootloader reads GPREGRET on boot and mounts USB MSC.
enter_uf2_via_daplink() {
  echo "Entering UF2 mode via DAPLink (GPREGRET = 0x57 + soft reset)..."
  "$OPENOCD" -s "$OPENOCD_SCRIPTS" -f "$DAPLINK_CFG" \
    -c "init" -c "halt" \
    -c "mwb 0x4000051C 0x57" \
    -c "mww 0xE000ED0C 0x05FA0004" \
    -c "exit" >/dev/null 2>&1
}

enter_dfu_via_meshtastic() {
  local port="$1"
  echo "Asking running Meshtastic firmware to reboot into DFU..."
  meshtastic --port "$port" --enter-dfu >/dev/null 2>&1 || true
  echo "(--enter-dfu lands in OTA/BLE mode; you must double-tap RESET to switch to UF2 mode.)"
}

if [[ ! -d "$BL_VOLUME" ]]; then
  case "$MODE" in
    manual)
      echo "Manual mode: $BL_VOLUME not mounted. Double-press RESET to enter UF2 mode." >&2
      exit 1
      ;;
    *)
      if daplink_attached; then
        enter_uf2_via_daplink
      else
        PORT="$(find_target_port || true)"
        if [[ -n "$PORT" && -e "$PORT" ]]; then
          enter_dfu_via_meshtastic "$PORT"
        else
          echo "Neither DAPLink nor a running target CDC port found." >&2
          echo "Double-press RESET on the board to enter UF2 mode, then re-run with 'manual'." >&2
        fi
      fi
      ;;
  esac
  echo "Waiting up to 15s for $BL_VOLUME (and CURRENT.UF2 inside it) to appear..."
  # The mount appears in /Volumes/ before macOS finishes populating the
  # FAT directory listing, so wait for CURRENT.UF2 to be visible as well.
  for i in $(seq 1 30); do
    [[ -f "$BL_VOLUME/CURRENT.UF2" ]] && break
    sleep 0.5
  done
fi

if [[ ! -f "$BL_VOLUME/CURRENT.UF2" ]]; then
  echo "Bootloader staging file $BL_VOLUME/CURRENT.UF2 never appeared." >&2
  echo "If the bootloader is unhealthy, run:" >&2
  echo "  ../25_HT5262M_test/scripts/restore_bootloader.sh" >&2
  exit 1
fi

echo "Writing $(basename "$UF2") to $BL_VOLUME/CURRENT.UF2 (with fsync) ..."
# Plain `cp` to a macOS USB-MSC volume gets buffered by the kernel and the
# UF2 bootloader can fail to receive enough blocks to trigger a reset.
# Write via Python with explicit os.fsync() after each chunk, then eject
# the volume — the combination forces macOS to push every block out the USB
# pipe instead of caching. Tested 2026-05-19: plain `cp` left bootloader
# stuck; this Python+fsync path resets the chip reliably.
python3 - "$UF2" "$BL_VOLUME/CURRENT.UF2" <<'PY' || true
import os, sys, errno
src, dst = sys.argv[1], sys.argv[2]
fd = os.open(dst, os.O_WRONLY | os.O_TRUNC, 0o644)
try:
    with open(src, "rb") as r:
        while True:
            chunk = r.read(4096)
            if not chunk: break
            try:
                os.write(fd, chunk)
                os.fsync(fd)
            except OSError as e:
                # ENXIO / EIO means the bootloader has reset mid-write
                # (UF2 transfer complete from its side) — that is success.
                if e.errno in (errno.ENXIO, errno.EIO): break
                raise
finally:
    try: os.close(fd)
    except Exception: pass
PY

# Force flush + unmount any remaining buffered writes. Exits cleanly even
# if the bootloader already disconnected.
diskutil eject "$BL_VOLUME" 2>/dev/null || true

# Wait for USB PID to switch from bootloader (0x0071) to app (0x4405).
echo "Waiting for chip to reboot into app..."
ok=0
for i in $(seq 1 30); do
  if system_profiler SPUSBDataType 2>/dev/null | grep -q "Product ID: 0x4405"; then
    ok=1; break
  fi
  sleep 0.5
done

if [[ $ok -eq 0 ]]; then
  echo "Warning: chip never reappeared with app PID 0x4405." >&2
  echo "Bootloader may have rejected the UF2 — re-check the build, then re-run." >&2
  exit 1
fi

sleep 2
NEW_PORT="$(find_target_port || true)"
echo
echo "Done. App is running (PID 0x4405)."
if [[ -n "$NEW_PORT" ]]; then
  echo "Target CDC port: $NEW_PORT"
  echo "Try:"
  echo "  meshtastic --port $NEW_PORT --info"
  echo "  ./scripts/monitor.sh $NEW_PORT"
fi
