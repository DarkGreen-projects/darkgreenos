#!/usr/bin/env python3
"""Serial smoke test for RMGR audit/profile/snapshot (optional, needs pyserial)."""

from __future__ import annotations

import argparse
import subprocess
import sys
import time

try:
    import serial
except ImportError:
    print("pip install pyserial for this script", file=sys.stderr)
    sys.exit(0)


def read_until(ser: serial.Serial, timeout: float = 3.0) -> str:
    deadline = time.time() + timeout
    buf = b""
    while time.time() < deadline:
        chunk = ser.read(4096)
        if chunk:
            buf += chunk
        time.sleep(0.1)
    return buf.decode("utf-8", errors="replace")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", default="/dev/ttyS0")
    parser.add_argument("--iso", default="build/darkgreenos.iso")
    parser.add_argument("--mem", default="2048")
    args = parser.parse_args()

    qemu = subprocess.Popen(
        [
            "qemu-system-i386",
            "-cdrom",
            args.iso,
            "-m",
            args.mem,
            "-serial",
            args.port,
            "-display",
            "none",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    time.sleep(4)
    try:
        with serial.Serial(args.port, 115200, timeout=2) as ser:
            ser.write(b"profile\r\n")
            time.sleep(0.6)
            out = read_until(ser)
            print(out)
            if "thr=" not in out:
                raise SystemExit("profile output missing thr=")

            for _ in range(5):
                ser.write(b"think test\r\n")
                time.sleep(0.4)
            out = read_until(ser, 2.0)
            print(out)

            ser.write(b"alloc 64\r\n")
            time.sleep(0.5)
            out = read_until(ser, 1.5)
            print(out)

            ser.write(b"snapshot\r\n")
            time.sleep(0.5)
            snap = read_until(ser, 1.5)
            print(snap)
            if "SNAP" not in snap or "free=" not in snap:
                raise SystemExit("snapshot missing SNAP free=")

            ser.write(b"audit\r\n")
            time.sleep(0.5)
            audit = read_until(ser, 1.5)
            print(audit)
            if "act=" not in audit:
                raise SystemExit("audit missing act=")
            if "act=1" not in audit and "act=11" not in audit:
                raise SystemExit("audit missing act=1 (think) or act=11 (alloc)")

            print("qemu_rmgr_regress: OK")
    finally:
        qemu.terminate()


if __name__ == "__main__":
    main()
