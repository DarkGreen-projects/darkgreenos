#!/usr/bin/env python3
"""Build DGFS image for DarkgreenOS (read-write profile persistence)."""

from __future__ import annotations

import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "model" / "dgfs.img"

DGFS_MAGIC = 0x53464744
VERSION = 1
BLOCK = 512
HEADER = 32
ENTRY = 44
MAX_FILES = 4
DATA_OFF = HEADER + MAX_FILES * ENTRY

DMTP_MAGIC = 0x50544D44
PROFILE = 64


def default_profile() -> bytes:
    blob = bytearray(PROFILE)
    struct.pack_into("<I", blob, 0, DMTP_MAGIC)
    struct.pack_into("<I", blob, 40, 1)
    struct.pack_into("<I", blob, 44, 32768)
    struct.pack_into("<I", blob, 48, 25)
    struct.pack_into("<I", blob, 52, 128)
    return bytes(blob)


AUDIT_TAIL_BYTES = 512

FILES = [
    ("help.txt", b"DarkgreenOS DGFS - RMGR orchestrator-native kernel v0.10.\n"),
    ("version.txt", b"0.10-orchestrator\n"),
    ("rmgr.profile", default_profile()),
    ("audit.tail", b"\x00" * 4 + b"\x00" * (AUDIT_TAIL_BYTES - 4)),
]


def pack_entry(name: str, offset: int, size: int, flags: int = 0) -> bytes:
    nb = name.encode("ascii")[:31]
    buf = bytearray(ENTRY)
    buf[: len(nb)] = nb
    struct.pack_into("<III", buf, 32, offset, size, flags)
    return bytes(buf)


def build() -> None:
    data = b"".join(content for _, content in FILES)
    # pad to block
    pad = (BLOCK - (DATA_OFF + len(data)) % BLOCK) % BLOCK
    data += b"\x00" * pad
    base = DATA_OFF
    entries = []
    off = base
    for name, content in FILES:
        entries.append(pack_entry(name, off, len(content), 0))
        off += len(content)
    while len(entries) < MAX_FILES:
        entries.append(pack_entry("", 0, 0, 0))
    header = struct.pack(
        "<IIIIIIII",
        DGFS_MAGIC,
        VERSION,
        BLOCK,
        len(FILES),
        DATA_OFF,
        0,
        0,
        0,
    )
    img = header + b"".join(entries) + data
    if len(img) > 131072:
        raise SystemExit(f"DGFS too large: {len(img)}")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(img)
    print(f"Wrote {OUT} ({len(img)} bytes)")


if __name__ == "__main__":
    build()
