#!/usr/bin/env python3
"""Build the persistent DarkMind memory image (orchestrator + DMTP profile)."""

from __future__ import annotations

import argparse
import struct
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "model" / "darkmind-memory.bin"

MAGIC = b"DMEM"
DMTP = 0x50544D44
VERSION = 1
HEADER_BYTES = 64
RECORD_BYTES = 16
CAPACITY = 64 * 1024
PROFILE_BYTES = 64

TYPE_PERSONA = 1
TYPE_MACHINE = 2
TYPE_PREFERENCE = 3
TYPE_CONVERSATION = 4
TYPE_SUMMARY = 5

RMGR_THROTTLE_MIN = 1
RMGR_FREE_RAM_MIN_KB = 32768
RMGR_FREE_RAM_PCT = 25
RMGR_SCORE_INIT = 128


def default_dmtp_profile() -> bytes:
    blob = bytearray(PROFILE_BYTES)
    struct.pack_into("<I", blob, 0, DMTP)
    struct.pack_into("<I", blob, 40, RMGR_THROTTLE_MIN)
    struct.pack_into("<I", blob, 44, RMGR_FREE_RAM_MIN_KB)
    struct.pack_into("<I", blob, 48, RMGR_FREE_RAM_PCT)
    struct.pack_into("<I", blob, 52, RMGR_SCORE_INIT)
    return bytes(blob)


SEED_RECORDS = [
    (
        TYPE_PERSONA,
        "Io sono DarkMind, orchestratore risorse di DarkgreenOS. "
        "Misuro RAM, framebuffer e tick prima e dopo ogni azione.",
    ),
    (
        TYPE_MACHINE,
        "DarkgreenOS e' bare-metal NASM, GRUB Multiboot2, GUI 1024x768, "
        "chat in barra titolo. Nessun LLM generativo nel kernel.",
    ),
    (
        TYPE_MACHINE,
        "Modulo GRUB: darkmind.memory (DMEM1) con profilo DMTP adattivo "
        "per throttle e soglie RAM tra reboot.",
    ),
    (
        TYPE_PREFERENCE,
        "Risposte in italiano con numeri verificabili: PRIMA/DOPO/DELTA "
        "e decisione policy (BALANCE, THROTTLE, CAUTELA, SAVE_FB, EXPLAIN).",
    ),
    (
        TYPE_SUMMARY,
        "LLM futuri solo via host/companion (software), non module2 nel kernel.",
    ),
]


def align_up(value: int, alignment: int) -> int:
    return (value + alignment - 1) & ~(alignment - 1)


def build(records: list[tuple[int, str | bytes]], capacity: int) -> bytes:
    payload = bytearray()
    for record_type, text in records:
        if isinstance(text, bytes):
            raw = text
        else:
            raw = text.encode("utf-8") + b"\0"
        payload.extend(struct.pack("<IIII", record_type, 0, len(raw), 0))
        payload.extend(raw)
        payload.extend(b"\0" * (align_up(len(payload), 16) - len(payload)))

    write_off = HEADER_BYTES + len(payload)
    if write_off > capacity:
        raise ValueError("DMEM seed records exceed capacity")

    header = struct.pack(
        "<4sIIIIII",
        MAGIC,
        VERSION,
        HEADER_BYTES,
        capacity,
        len(records),
        write_off,
        0,
    ).ljust(HEADER_BYTES, b"\0")
    image = header + payload
    return image + b"\0" * (capacity - len(image))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=OUT)
    parser.add_argument("--capacity", type=int, default=CAPACITY)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    args.out.parent.mkdir(parents=True, exist_ok=True)
    records: list[tuple[int, str | bytes]] = [
        (TYPE_MACHINE, default_dmtp_profile()),
        *SEED_RECORDS,
    ]
    args.out.write_bytes(build(records, args.capacity))
    print(f"wrote {args.out} ({args.out.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
