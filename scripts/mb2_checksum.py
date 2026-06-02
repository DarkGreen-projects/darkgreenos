#!/usr/bin/env python3
"""Verify / compute Multiboot 2 header checksum in built kernel ELF."""
import struct
import sys

MB2_MAGIC = 0xE85250D6


def find_header(blob: bytes) -> int:
    for off in range(0, min(len(blob), 32768) - 16, 8):
        if struct.unpack_from("<I", blob, off)[0] == MB2_MAGIC:
            return off
    return -1


def checksum_ok(blob: bytes, off: int) -> bool:
    length = struct.unpack_from("<I", blob, off + 8)[0]
    if length < 16 or off + length > len(blob):
        return False
    total = sum(
        struct.unpack_from("<I", blob, off + i)[0] for i in range(0, length, 4)
    )
    return (total & 0xFFFFFFFF) == 0


def compute_checksum_field(blob: bytes, off: int) -> int:
    length = struct.unpack_from("<I", blob, off + 8)[0]
    partial = sum(
        struct.unpack_from("<I", blob, off + i)[0]
        for i in range(0, length, 4)
        if i != 12
    )
    return (-partial) & 0xFFFFFFFF


def grub_find_header_ok(blob: bytes, off: int) -> bool:
    """GRUB find_header() only sums magic, arch, header_length, checksum."""
    magic, arch, length, checksum = struct.unpack_from("<IIII", blob, off)
    return (magic + arch + length + checksum) & 0xFFFFFFFF == 0


def main() -> int:
    path = sys.argv[1] if len(sys.argv) > 1 else "build/darkgreenos.kernel"
    blob = open(path, "rb").read()
    off = find_header(blob)
    if off < 0:
        print(f"no MB2 magic in first 32KiB of {path}")
        return 1
    length = struct.unpack_from("<I", blob, off + 8)[0]
    stored = struct.unpack_from("<I", blob, off + 12)[0]
    ok_full = checksum_ok(blob, off)
    ok_grub = grub_find_header_ok(blob, off)
    needed_full = compute_checksum_field(blob, off)
    magic, arch, _length, _ = struct.unpack_from("<IIII", blob, off)
    needed_grub = (-(magic + arch + length)) & 0xFFFFFFFF
    print(f"file: {path}")
    print(f"header at file offset: 0x{off:X}")
    print(f"header_length: {length}")
    print(f"checksum stored: 0x{stored:08X}")
    print(f"checksum for full header: 0x{needed_full:08X}")
    print(f"checksum for GRUB find_header: 0x{needed_grub:08X}")
    print(f"full header sum valid: {ok_full}")
    print(f"GRUB 4-field sum valid: {ok_grub}")
    if not ok_grub:
        print("ERROR: GRUB will report 'no multiboot header found'")
        return 2
    if not ok_full:
        print("note: full-header sum != 0 (GRUB does not require it)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
