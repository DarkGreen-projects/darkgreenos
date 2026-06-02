# Model artifacts

| File | In git | Size (typical) | Purpose |
|------|--------|----------------|---------|
| `darkmind-memory.bin` | yes | ~64 KB | DMTP profile / boot module |
| `tinylm.bin` | yes | tiny | TinyLM stub weights |
| `darkmind-q4.bin` | **no** | ~275 MB | Archived Q4 blob (reference / optional GRUB module) |

GitHub rejects files over 100 MB. Keep `darkmind-q4.bin` only on your machine.

## Regenerate `darkmind-q4.bin` (optional)

From repo root (Python 3 + deps for `scripts/build_darkmind_blob.py`):

```bash
python3 scripts/build_darkmind_blob.py
```

For a real Hugging Face model, see `--help` on that script. The default build produces a small DMQ1 diagnostic blob unless you pass `--model-id`.

The running ISO uses `model/darkmind-memory.bin` via `make iso`, not the Q4 file in the kernel link (see handoff: no LLM in ring 0).
