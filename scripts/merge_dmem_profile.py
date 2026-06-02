#!/usr/bin/env python3
"""Merge DMTP profile hex (from serial 'profile export') into darkmind-memory.bin."""

from __future__ import annotations

import argparse
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_BIN = ROOT / "model" / "darkmind-memory.bin"

MAGIC = b"DMEM"
DMTP = 0x50544D44
VERSION = 1
HEADER_BYTES = 64
RECORD_BYTES = 16
TYPE_MACHINE = 2
PROFILE_BYTES = 64


def align_up(value: int, alignment: int) -> int:
    return (value + alignment - 1) & ~(alignment - 1)


def parse_hex_words(text: str) -> bytes:
    words = text.replace(",", " ").split()
    out = bytearray()
    for w in words:
        w = w.strip()
        if not w:
            continue
        out.extend(struct.pack("<I", int(w, 16)))
    if len(out) < PROFILE_BYTES:
        out.extend(b"\0" * (PROFILE_BYTES - len(out)))
    return bytes(out[:PROFILE_BYTES])


def load_image(path: Path) -> bytearray:
    return bytearray(path.read_bytes())


def strip_dmtp_records(payload: bytearray) -> bytearray:
    out = bytearray()
    pos = 0
    while pos < len(payload):
        if pos + RECORD_BYTES > len(payload):
            break
        rtype, _flags, tlen, _ = struct.unpack_from("<IIII", payload, pos)
        if tlen == 0 or pos + RECORD_BYTES + tlen > len(payload):
            break
        data = payload[pos + RECORD_BYTES : pos + RECORD_BYTES + tlen]
        if rtype == TYPE_MACHINE and len(data) >= 4:
            if struct.unpack_from("<I", data, 0)[0] == DMTP:
                pos = align_up(pos + RECORD_BYTES + tlen, 16)
                continue
        chunk = payload[pos : align_up(pos + RECORD_BYTES + tlen, 16)]
        out.extend(chunk)
        pos = align_up(pos + RECORD_BYTES + tlen, 16)
    return out


def append_record(payload: bytearray, record_type: int, data: bytes) -> None:
    raw = data
    payload.extend(struct.pack("<IIII", record_type, 0, len(raw), 0))
    payload.extend(raw)
    while len(payload) % 16:
        payload.append(0)


def rebuild(header: bytearray, payload: bytearray, capacity: int) -> bytes:
    write_off = HEADER_BYTES + len(payload)
    if write_off > capacity:
        raise ValueError("DMEM capacity exceeded after merge")
    record_count = 0
    pos = 0
    while pos < len(payload):
        if pos + RECORD_BYTES > len(payload):
            break
        _t, _f, tlen, _ = struct.unpack_from("<IIII", payload, pos)
        if tlen == 0:
            break
        record_count += 1
        pos = align_up(pos + RECORD_BYTES + tlen, 16)
    new_header = struct.pack(
        "<4sIIIIII",
        MAGIC,
        VERSION,
        HEADER_BYTES,
        capacity,
        record_count,
        write_off,
        0,
    ).ljust(HEADER_BYTES, b"\0")
    image = bytearray(new_header) + payload
    if len(image) < capacity:
        image.extend(b"\0" * (capacity - len(image)))
    return bytes(image[:capacity])


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bin", type=Path, default=DEFAULT_BIN)
    parser.add_argument("--hex", type=str, help="hex words from profile export")
    parser.add_argument("--hex-file", type=Path, help="file containing export line")
    args = parser.parse_args()

    if args.hex_file:
        text = args.hex_file.read_text(encoding="utf-8")
    elif args.hex:
        text = args.hex
    else:
        raise SystemExit("provide --hex or --hex-file")

    profile = parse_hex_words(text)
    struct.pack_into("<I", profile, 0, DMTP)

    image = load_image(args.bin)
    capacity = struct.unpack_from("<I", image, 12)[0]
    old_payload = image[HEADER_BYTES:]
    payload = strip_dmtp_records(bytearray(old_payload))
    append_record(payload, TYPE_MACHINE, profile)
    out = rebuild(image[:HEADER_BYTES], payload, capacity)
    args.bin.write_bytes(out)
    print(f"merged DMTP profile into {args.bin}")


if __name__ == "__main__":
    main()
