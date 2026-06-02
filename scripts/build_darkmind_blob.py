#!/usr/bin/env python3
"""Build a DarkMind-Q model blob for GRUB module loading.

Default mode keeps the tiny DMQ1 diagnostic blob used by the fast kernel build.
Passing --model-id converts real Hugging Face safetensors into DMQ2.
"""

from __future__ import annotations

import argparse
import json
import shutil
import struct
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "model" / "darkmind-q4.bin"
CACHE_ROOT = ROOT / ".cache" / "darkmind-models"

DMQ1_MAGIC = b"DMQ1"
DMQ2_MAGIC = b"DMQ2"
DMQ1_VERSION = 1
DMQ2_VERSION = 2
HEADER_BYTES = 128

MODEL_CLASS_1B = 1000
MODEL_CLASS_QWEN25_05B = 525
ARCH_QWEN2 = 2

QUANT_Q4 = 4
DTYPE_Q4_0 = 4
DTYPE_F16 = 16
TOKENIZER_KIND_QWEN_BPE = 2
BYTE_TOKEN_COUNT = 256
TOKENIZER_BIN_MAGIC = b"DMTB1\0\0\0"
TOKENIZER_HASH_SLOTS = 4096
TOKENIZER_MAX_TOKEN_BYTES = 24

TINY_CTX_TOKENS = 128
TINY_VOCAB_SIZE = 256
TINY_TENSOR_COUNT = 1
DMQ1_TENSOR_ENTRY_BYTES = 64
DMQ2_TENSOR_ENTRY_BYTES = 96
DMQ2_TENSOR_NAME_BYTES = 56
Q4_BLOCK = 32
Q4_BLOCK_BYTES = 18

QWEN_MODEL_ID = "Qwen/Qwen2.5-0.5B-Instruct"
DEFAULT_PERSONA = (
    "DarkMind Mini is the personal local LLM of DarkgreenOS. "
    "It runs inside a bare-metal NASM OS, answers as the OS companion, "
    "and must use live machine context before generic knowledge."
)
DEFAULT_MACHINE_PROFILE = (
    "machine.os=DarkgreenOS; boot=GRUB Multiboot2; "
    "display=framebuffer_gui; input=ps2_keyboard_polling,ps2_mouse_polling; "
    "chat=bottom_input_bar; output=DarkMind_center_panel; "
    "model_module=/boot/model/darkmind-q4.bin; serial=COM1_companion;"
)
np = None


def require_numpy():
    global np
    if np is None:
        try:
            import numpy as numpy_module
        except ImportError as exc:
            raise SystemExit(
                "Install numpy before converting real weights: python3 -m pip install numpy"
            ) from exc
        np = numpy_module
    return np


@dataclass(frozen=True)
class TensorEntry:
    name: str
    dtype: int
    shape: tuple[int, ...]
    offset: int
    size: int


class SafeTensorFile:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.handle = path.open("rb")
        header_len = struct.unpack("<Q", self.handle.read(8))[0]
        header = json.loads(self.handle.read(header_len))
        self.data_base = 8 + header_len
        self.index = {
            name: meta
            for name, meta in header.items()
            if name != "__metadata__"
        }

    def close(self) -> None:
        self.handle.close()

    def names(self) -> Iterable[str]:
        return self.index.keys()

    def load_float32(self, name: str) -> np.ndarray:
        numpy = require_numpy()
        meta = self.index[name]
        dtype = meta["dtype"]
        shape = tuple(int(v) for v in meta["shape"])
        start, end = (int(v) for v in meta["data_offsets"])
        size = end - start
        self.handle.seek(self.data_base + start)
        raw = self.handle.read(size)
        if len(raw) != size:
            raise ValueError(f"short read for tensor {name}")

        if dtype == "BF16":
            words = numpy.frombuffer(raw, dtype="<u2").astype(numpy.uint32)
            return (words << 16).view(numpy.float32).reshape(shape)
        if dtype == "F16":
            return numpy.frombuffer(raw, dtype="<f2").astype(numpy.float32).reshape(shape)
        if dtype == "F32":
            return numpy.frombuffer(raw, dtype="<f4").astype(numpy.float32, copy=False).reshape(shape)
        raise ValueError(f"unsupported safetensors dtype {dtype} for {name}")


def align_up(value: int, alignment: int) -> int:
    return (value + alignment - 1) & ~(alignment - 1)


def write_tiny_blob(out: Path) -> None:
    tokenizer = bytes(range(256))
    tokenizer_off = HEADER_BYTES
    tensor_dir_off = tokenizer_off + len(tokenizer)
    tensor_dir_size = DMQ1_TENSOR_ENTRY_BYTES * TINY_TENSOR_COUNT
    payload_off = tensor_dir_off + tensor_dir_size
    payload = bytes((i * 17) & 0xFF for i in range(256))

    header = struct.pack(
        "<4sIIIIIIIIIIIIIII",
        DMQ1_MAGIC,
        DMQ1_VERSION,
        HEADER_BYTES,
        MODEL_CLASS_1B,
        QUANT_Q4,
        TINY_CTX_TOKENS,
        TINY_VOCAB_SIZE,
        1,
        64,
        4,
        1,
        16,
        TINY_TENSOR_COUNT,
        tokenizer_off,
        len(tokenizer),
        tensor_dir_off,
    )
    header += struct.pack("<II", tensor_dir_size, 0)
    header = header.ljust(HEADER_BYTES, b"\0")
    tensor_dir = (
        b"blk0.attn_q.q4".ljust(32, b"\0")
        + struct.pack("<IIIIIII", QUANT_Q4, 2, 64, 64, 0, payload_off, len(payload))
    )
    tensor_dir = tensor_dir.ljust(DMQ1_TENSOR_ENTRY_BYTES, b"\0")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(header + tokenizer + tensor_dir + payload)
    print(f"wrote tiny DMQ1 {out} ({out.stat().st_size} bytes)")


def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def download_model(model_id: str, local_dir: Path) -> Path:
    local_dir.mkdir(parents=True, exist_ok=True)
    patterns = [
        "config.json",
        "generation_config.json",
        "tokenizer.json",
        "tokenizer_config.json",
        "special_tokens_map.json",
        "*.safetensors",
    ]
    try:
        from huggingface_hub import snapshot_download

        return Path(
            snapshot_download(
                repo_id=model_id,
                local_dir=local_dir,
                allow_patterns=patterns,
            )
        )
    except ImportError:
        hf = shutil.which("hf")
        if hf is None:
            raise SystemExit(
                "Install huggingface_hub or hf CLI first: "
                "python3 -m pip install huggingface_hub"
            )
        command = [hf, "download", model_id, "--local-dir", str(local_dir)]
        for pattern in patterns:
            command.extend(["--include", pattern])
        subprocess.run(command, check=True)
        return local_dir


def build_byte_token_map(model_dir: Path) -> bytes:
    ids = list(range(BYTE_TOKEN_COUNT))
    try:
        from tokenizers import Tokenizer

        tokenizer = Tokenizer.from_file(str(model_dir / "tokenizer.json"))
        for value in range(BYTE_TOKEN_COUNT):
            text = bytes([value]).decode("latin1")
            encoded = tokenizer.encode(text, add_special_tokens=False).ids
            if encoded:
                ids[value] = int(encoded[0])
    except Exception as exc:
        print(f"warning: using byte token fallback ids: {exc}", file=sys.stderr)
    return struct.pack("<" + "I" * BYTE_TOKEN_COUNT, *ids)


def fnv1a32(data: bytes) -> int:
    value = 2166136261
    for byte in data:
        value ^= byte
        value = (value * 16777619) & 0xFFFFFFFF
    return value


def build_binary_tokenizer(model_dir: Path) -> bytes:
    """Build a compact kernel-friendly tokenizer/detokenizer sidecar.

    The kernel cannot afford to parse the full Hugging Face tokenizer JSON and
    regex at runtime. This table stores:
    - byte -> token id fallback
    - token id -> UTF-8 text offsets for detokenization
    - a small open-addressed hash table for longest-prefix token lookup
    """
    try:
        from tokenizers import Tokenizer
    except Exception as exc:
        print(f"warning: binary tokenizer unavailable: {exc}", file=sys.stderr)
        return b""

    tokenizer = Tokenizer.from_file(str(model_dir / "tokenizer.json"))
    vocab = tokenizer.get_vocab()
    vocab_size = max(vocab.values()) + 1
    id_to_text = [b""] * vocab_size
    hash_slots: list[tuple[int, int, int, int]] = [(0, 0, 0, 0)] * TOKENIZER_HASH_SLOTS
    strings = bytearray(b"\0")

    for token_id in range(vocab_size):
        try:
            text = tokenizer.decode([token_id], skip_special_tokens=False)
        except Exception:
            text = ""
        raw = text.encode("utf-8", errors="ignore")
        id_to_text[token_id] = raw
        if raw:
            strings.extend(raw)
            strings.append(0)

    string_offsets: list[tuple[int, int]] = []
    cursor = 1
    for raw in id_to_text:
        if raw:
            string_offsets.append((cursor, len(raw)))
            cursor += len(raw) + 1
        else:
            string_offsets.append((0, 0))

    # Prefer decoded UTF-8 strings that are short enough for prompt matching.
    # Collisions are resolved by linear probing and duplicate strings keep the
    # first token id, which is stable enough for kernel prompt ingestion.
    seen: set[bytes] = set()
    for token_id, raw in enumerate(id_to_text):
        if not raw or len(raw) > TOKENIZER_MAX_TOKEN_BYTES or raw in seen:
            continue
        seen.add(raw)
        key_hash = fnv1a32(raw)
        slot = key_hash & (TOKENIZER_HASH_SLOTS - 1)
        for _ in range(TOKENIZER_HASH_SLOTS):
            if hash_slots[slot][1] == 0:
                offset, length = string_offsets[token_id]
                hash_slots[slot] = (key_hash, length, token_id, offset)
                break
            slot = (slot + 1) & (TOKENIZER_HASH_SLOTS - 1)

    byte_map = build_byte_token_map(model_dir)
    header_size = 64
    byte_map_off = header_size
    detok_off = align_up(byte_map_off + len(byte_map), 16)
    detok = b"".join(struct.pack("<II", off, length) for off, length in string_offsets)
    hash_off = align_up(detok_off + len(detok), 16)
    hash_table = b"".join(struct.pack("<IIII", *slot) for slot in hash_slots)
    strings_off = align_up(hash_off + len(hash_table), 16)
    header = struct.pack(
        "<8sIIIIIIIIIIII",
        TOKENIZER_BIN_MAGIC,
        1,
        vocab_size,
        QWEN_EOS_TOKEN_ID if "QWEN_EOS_TOKEN_ID" in globals() else 151645,
        TOKENIZER_HASH_SLOTS,
        TOKENIZER_MAX_TOKEN_BYTES,
        byte_map_off,
        len(byte_map),
        detok_off,
        len(detok),
        hash_off,
        len(hash_table),
        strings_off,
    ).ljust(header_size, b"\0")
    blob = bytearray(header)
    blob.extend(byte_map)
    blob.extend(b"\0" * (detok_off - len(blob)))
    blob.extend(detok)
    blob.extend(b"\0" * (hash_off - len(blob)))
    blob.extend(hash_table)
    blob.extend(b"\0" * (strings_off - len(blob)))
    blob.extend(strings)
    print(
        f"binary tokenizer: vocab={vocab_size} hash_slots={TOKENIZER_HASH_SLOTS} "
        f"strings={len(strings)} bytes"
    )
    return bytes(blob)


def build_tokenizer_bundle(
    model_dir: Path,
    persona: str,
    machine_profile: str,
) -> bytes:
    required_names = [
        "config.json",
        "tokenizer.json",
        "tokenizer_config.json",
    ]
    optional_names = [
        "generation_config.json",
        "special_tokens_map.json",
    ]
    names = required_names + [name for name in optional_names if (model_dir / name).exists()]
    embedded = {
        "darkmind_persona.txt": persona.encode("utf-8"),
        "darkmind_machine_profile.txt": machine_profile.encode("utf-8"),
        "darkmind_byte_tokens.bin": build_byte_token_map(model_dir),
    }
    binary_tokenizer = build_binary_tokenizer(model_dir)
    if binary_tokenizer:
        embedded["darkmind_tokenizer.bin"] = binary_tokenizer
    chunks = [struct.pack("<8sI", b"DMTOK2\0\0", len(names) + len(embedded))]
    for name in names:
        data = (model_dir / name).read_bytes()
        encoded_name = name.encode("ascii")
        chunks.append(struct.pack("<II", len(encoded_name), len(data)))
        chunks.append(encoded_name)
        chunks.append(data)
        padding = align_up(sum(len(c) for c in chunks), 16) - sum(len(c) for c in chunks)
        if padding:
            chunks.append(b"\0" * padding)
    for name, data in embedded.items():
        encoded_name = name.encode("ascii")
        chunks.append(struct.pack("<II", len(encoded_name), len(data)))
        chunks.append(encoded_name)
        chunks.append(data)
        padding = align_up(sum(len(c) for c in chunks), 16) - sum(len(c) for c in chunks)
        if padding:
            chunks.append(b"\0" * padding)
    return b"".join(chunks)


def quantize_q4_0(values: np.ndarray) -> bytes:
    numpy = require_numpy()
    flat = numpy.asarray(values, dtype=numpy.float32).reshape(-1)
    pad = (-flat.size) % Q4_BLOCK
    if pad:
        flat = numpy.pad(flat, (0, pad))

    out = bytearray((flat.size // Q4_BLOCK) * Q4_BLOCK_BYTES)
    dst = 0
    for index in range(0, flat.size, Q4_BLOCK):
        block = flat[index : index + Q4_BLOCK]
        max_abs = float(numpy.max(numpy.abs(block)))
        scale = max_abs / 7.0 if max_abs else 1.0
        inv_scale = 1.0 / scale
        packed = numpy.clip(numpy.rint(block * inv_scale), -8, 7).astype(numpy.int8)
        out[dst : dst + 2] = numpy.float16(scale).tobytes()
        dst += 2
        for pair in range(0, Q4_BLOCK, 2):
            lo = int(packed[pair]) & 0x0F
            hi = int(packed[pair + 1]) & 0x0F
            out[dst] = lo | (hi << 4)
            dst += 1
    return bytes(out)


def tensor_payload(name: str, values: np.ndarray) -> tuple[int, bytes]:
    numpy = require_numpy()
    if values.ndim == 2:
        return DTYPE_Q4_0, quantize_q4_0(values)
    if values.ndim == 1:
        return DTYPE_F16, numpy.asarray(values, dtype=numpy.float16).tobytes()
    raise ValueError(f"unsupported tensor rank for {name}: {values.shape}")


def pack_dmq2_tensor_entry(entry: TensorEntry) -> bytes:
    encoded = entry.name.encode("ascii")
    if len(encoded) > DMQ2_TENSOR_NAME_BYTES:
        raise ValueError(f"tensor name too long for DMQ2 directory: {entry.name}")
    dims = list(entry.shape[:4]) + [0] * (4 - len(entry.shape))
    return (
        encoded.ljust(DMQ2_TENSOR_NAME_BYTES, b"\0")
        + struct.pack(
            "<IIIIIIQQ",
            entry.dtype,
            len(entry.shape),
            dims[0],
            dims[1],
            dims[2],
            dims[3],
            entry.offset,
            entry.size,
        )
    ).ljust(DMQ2_TENSOR_ENTRY_BYTES, b"\0")


def find_safetensors(model_dir: Path) -> list[Path]:
    files = sorted(model_dir.glob("*.safetensors"))
    if not files:
        raise FileNotFoundError(f"no .safetensors files found in {model_dir}")
    return files


def read_text_arg(path: Path | None, default: str) -> str:
    if path is None:
        return default
    return path.read_text(encoding="utf-8").strip()


def convert_qwen(
    model_id: str,
    out: Path,
    model_dir: Path | None,
    ctx_tokens: int,
    persona: str,
    machine_profile: str,
) -> None:
    model_dir = model_dir or CACHE_ROOT / model_id.replace("/", "--")
    model_dir = download_model(model_id, model_dir)
    config = load_json(model_dir / "config.json")

    hidden = int(config["hidden_size"])
    layers = int(config["num_hidden_layers"])
    heads = int(config["num_attention_heads"])
    kv_heads = int(config["num_key_value_heads"])
    head_dim = int(config.get("head_dim", hidden // heads))
    intermediate = int(config["intermediate_size"])
    vocab = int(config["vocab_size"])
    rope_theta = int(config.get("rope_theta", 1000000))

    if model_id != QWEN_MODEL_ID:
        print(f"warning: converter tuned for {QWEN_MODEL_ID}, got {model_id}", file=sys.stderr)
    expected = (layers, hidden, heads, kv_heads, head_dim, intermediate)
    if expected != (24, 896, 14, 2, 64, 4864):
        raise ValueError(f"unexpected Qwen2.5-0.5B shape tuple: {expected}")

    tokenizer = build_tokenizer_bundle(model_dir, persona, machine_profile)
    tokenizer_off = HEADER_BYTES
    tensor_dir_off = align_up(tokenizer_off + len(tokenizer), 16)

    entries: list[TensorEntry] = []
    payload_chunks: list[bytes] = []
    payload_cursor = 0

    tensor_files = [SafeTensorFile(path) for path in find_safetensors(model_dir)]
    try:
        names = sorted(name for tensor_file in tensor_files for name in tensor_file.names())
        tensor_dir_size = len(names) * DMQ2_TENSOR_ENTRY_BYTES
        payload_base = align_up(tensor_dir_off + tensor_dir_size, 16)
        payload_cursor = payload_base

        for name in names:
            owner = next(tensor_file for tensor_file in tensor_files if name in tensor_file.index)
            values = owner.load_float32(name)
            dtype, payload = tensor_payload(name, values)
            payload_cursor = align_up(payload_cursor, 16)
            payload_chunks.append(b"\0" * (payload_cursor - (payload_base + sum(len(c) for c in payload_chunks))))
            entries.append(
                TensorEntry(
                    name=name,
                    dtype=dtype,
                    shape=tuple(int(v) for v in values.shape),
                    offset=payload_cursor,
                    size=len(payload),
                )
            )
            payload_chunks.append(payload)
            payload_cursor += len(payload)
            print(f"{name}: shape={tuple(values.shape)} dtype={dtype} bytes={len(payload)}")
    finally:
        for tensor_file in tensor_files:
            tensor_file.close()

    tensor_dir = b"".join(pack_dmq2_tensor_entry(entry) for entry in entries)
    padding_after_tokenizer = b"\0" * (tensor_dir_off - (tokenizer_off + len(tokenizer)))
    payload = b"".join(payload_chunks)
    header = struct.pack(
        "<4sIIIIIIIIIIIIIII",
        DMQ2_MAGIC,
        DMQ2_VERSION,
        HEADER_BYTES,
        MODEL_CLASS_QWEN25_05B,
        QUANT_Q4,
        ctx_tokens,
        vocab,
        layers,
        hidden,
        heads,
        kv_heads,
        head_dim,
        len(entries),
        tokenizer_off,
        len(tokenizer),
        tensor_dir_off,
    )
    header += struct.pack("<II", len(tensor_dir), 0)
    header += struct.pack(
        "<IIIIII",
        intermediate,
        rope_theta,
        TOKENIZER_KIND_QWEN_BPE,
        ARCH_QWEN2,
        DMQ2_TENSOR_ENTRY_BYTES,
        0,
    )
    header = header.ljust(HEADER_BYTES, b"\0")

    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("wb") as handle:
        handle.write(header)
        handle.write(tokenizer)
        handle.write(padding_after_tokenizer)
        handle.write(tensor_dir)
        handle.write(b"\0" * (align_up(handle.tell(), 16) - handle.tell()))
        handle.write(payload)
    print(f"wrote Qwen DMQ2 {out} ({out.stat().st_size} bytes, {len(entries)} tensors)")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model-id", help="Hugging Face model id to convert")
    parser.add_argument("--model-dir", type=Path, help="existing local HF snapshot")
    parser.add_argument("--out", type=Path, default=OUT)
    parser.add_argument("--ctx-tokens", type=int, default=128)
    parser.add_argument("--persona-file", type=Path, help="UTF-8 DarkMind Mini persona text")
    parser.add_argument("--machine-profile-file", type=Path, help="UTF-8 machine profile text")
    parser.add_argument("--tiny", action="store_true", help="force tiny DMQ1 diagnostic blob")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.tiny or not args.model_id:
        write_tiny_blob(args.out)
        return
    convert_qwen(
        args.model_id,
        args.out,
        args.model_dir,
        args.ctx_tokens,
        read_text_arg(args.persona_file, DEFAULT_PERSONA),
        read_text_arg(args.machine_profile_file, DEFAULT_MACHINE_PROFILE),
    )


if __name__ == "__main__":
    main()
