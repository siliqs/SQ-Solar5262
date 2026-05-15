#!/usr/bin/env bash
# Watch Meshtastic console on HT-N5262M.
# Auto-reconnects when the USB CDC re-enumerates after a reset.
# Usage: ./scripts/monitor.sh [port]

PORT="${1:-/dev/cu.usbmodem21101}"

# `exec` replaces the bash wrapper with python so there's only one process
# to clean up — kill / Ctrl-C goes straight to python and never leaks.
exec python3 - "$PORT" <<'EOF'
import serial, signal, sys, time

port = sys.argv[1]
ser = None

def cleanup(*_):
    global ser
    try:
        if ser: ser.close()
    except Exception: pass
    print('\n[monitor] exit', flush=True)
    sys.exit(0)

signal.signal(signal.SIGINT, cleanup)
signal.signal(signal.SIGTERM, cleanup)
signal.signal(signal.SIGHUP, cleanup)

print(f'[monitor] watching {port} (Ctrl-C to exit)', flush=True)
while True:
    try:
        ser = serial.Serial(port, 115200, timeout=1)
        ser.dtr = True
        ser.rts = True
        print('[monitor] connected', flush=True)
        while True:
            try:
                n = ser.in_waiting
                if n:
                    sys.stdout.buffer.write(ser.read(n))
                    sys.stdout.flush()
                else:
                    time.sleep(0.05)
            except (OSError, serial.SerialException) as e:
                print(f'\n[monitor] disconnect: {e}', flush=True)
                break
        try: ser.close()
        except Exception: pass
        ser = None
    except (OSError, serial.SerialException):
        pass
    time.sleep(0.5)
EOF
