#!/usr/bin/env python3
"""Patch rmgr.profile throttle inside model/dgfs.img for cross-boot regress."""

from __future__ import annotations

import argparse
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DGFS = ROOT / "model" / "dgfs.img"
DGFS_MAGIC = 0x53464744
HEADER = 32
ENTRY = 44
DATA_OFF = HEADER + 4 * ENTRY
PROFILE_OFF_IN_BLOB = 40  # RMGR_PROF_THROTTLE


def find_profile_offset(data: bytes) -> int:
    if len(data) < DATA_OFF:
        raise SystemExit("DGFS too small")
    magic, = struct.unpack_from("<I", data, 0)
    if magic != DGFS_MAGIC:
        raise SystemExit("bad DGFS magic")
    for i in range(4):
        base = HEADER + i * ENTRY
        name = data[base : base + 32].split(b"\x00", 1)[0]
        if name == b"rmgr.profile":
            off, size, _ = struct.unpack_from("<III", data, base + 32)
            if size < PROFILE_OFF_IN_BLOB + 4:
                raise SystemExit("rmgr.profile entry too small")
            return off + PROFILE_OFF_IN_BLOB
    raise SystemExit("rmgr.profile not found")


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--thr", type=int, required=True)
    p.add_argument("--img", type=Path, default=DGFS)
    args = p.parse_args()
    if not 1 <= args.thr <= 16:
        raise SystemExit("thr must be 1..16")
    data = bytearray(args.img.read_bytes())
    pos = find_profile_offset(data)
    struct.pack_into("<I", data, pos, args.thr)
    args.img.write_bytes(data)
    print(f"Patched {args.img} thr={args.thr} at offset {pos}")


if __name__ == "__main__":
    main()
