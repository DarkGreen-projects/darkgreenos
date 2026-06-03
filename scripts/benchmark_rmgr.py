#!/usr/bin/env python3
"""Benchmark RMGR: compare throttle thr=1 (aggressive) vs thr=16 (relaxed)."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
import time

try:
    import serial
except ImportError:
    print("pip install pyserial", file=sys.stderr)
    sys.exit(0)


def read_until(ser: serial.Serial, timeout: float = 2.0) -> str:
    deadline = time.time() + timeout
    buf = b""
    while time.time() < deadline:
        chunk = ser.read(4096)
        if chunk:
            buf += chunk
        time.sleep(0.05)
    return buf.decode("utf-8", errors="replace")


def send(ser: serial.Serial, cmd: str, wait: float = 0.4) -> str:
    ser.write((cmd + "\r\n").encode())
    time.sleep(wait)
    return read_until(ser, 1.5)


def parse_dt(text: str) -> int | None:
    m = re.search(r"dT=(\d+)", text)
    return int(m.group(1)) if m else None


def run_session(iso: str, port: str, mem: str, thr: int) -> list[tuple[str, int | None]]:
    qemu = subprocess.Popen(
        [
            "qemu-system-i386",
            "-cdrom",
            iso,
            "-m",
            mem,
            "-serial",
            port,
            "-display",
            "none",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    time.sleep(4)
    rows: list[tuple[str, int | None]] = []
    try:
        with serial.Serial(port, 115200, timeout=2) as ser:
            send(ser, f"policy set thr={thr}")
            send(ser, "sync")
            for cmd in ("snapshot", "think bench", "yield", "run", "snapshot"):
                out = send(ser, cmd)
                rows.append((cmd, parse_dt(out)))
    finally:
        qemu.terminate()
    return rows


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", default="/dev/ttyS0")
    parser.add_argument("--iso", default="build/darkgreenos.iso")
    parser.add_argument("--mem", default="2048")
    args = parser.parse_args()

    on_rows = run_session(args.iso, args.port, args.mem, 1)
    time.sleep(1)
    off_rows = run_session(args.iso, args.port, args.mem, 16)

    def sum_dt(rows: list[tuple[str, int | None]]) -> int:
        return sum(d for _, d in rows if d is not None)

    on_sum = sum_dt(on_rows)
    off_sum = sum_dt(off_rows)
    pct = 0
    if off_sum > 0:
        pct = int(100 * (off_sum - on_sum) / off_sum)

    report = [
        "# RMGR benchmark (thr=1 vs thr=16)",
        "",
        f"| Mode | sum(dT) |",
        f"|------|---------|",
        f"| RMGR on (thr=1) | {on_sum} |",
        f"| RMGR relaxed (thr=16) | {off_sum} |",
        "",
        f"Delta reduction with aggressive throttle: ~{pct}%",
        "",
        "## thr=1 steps",
        "| Step | dT |",
        "|------|-----|",
    ]
    for cmd, dt in on_rows:
        report.append(f"| `{cmd}` | {dt if dt is not None else 'n/a'} |")
    report.append("")
    report.append("## thr=16 steps")
    report.append("| Step | dT |")
    report.append("|------|-----|")
    for cmd, dt in off_rows:
        report.append(f"| `{cmd}` | {dt if dt is not None else 'n/a'} |")

    path = "docs/benchmarks/rmgr-benchmark.md"
    import os

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(report) + "\n")
    print(f"Wrote {path} (on={on_sum} off={off_sum})")


if __name__ == "__main__":
    main()
