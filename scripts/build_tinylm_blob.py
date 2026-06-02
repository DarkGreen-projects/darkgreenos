#!/usr/bin/env python3
"""Build the tiny in-kernel DarkMind model blob.

The first TinyLM runtime is intentionally small: the kernel-side decoder uses a
byte-level vocabulary and quantized prompt scores, while this blob records the
model metadata that NASM embeds with incbin.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "model" / "tinylm.bin"


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(
        b"TINYLM2\n"
        b"vocab=byte-ascii\n"
        b"quant=int8-scripted\n"
        b"decode=greedy\n"
        b"specialization=darkgreenos-gui-kernel\n"
        b"intents=identity,model,boot,keyboard,gui,mouse,mem,files,scan\n"
        b"matching=case-insensitive\n"
    )
    print(f"wrote {OUT} ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
