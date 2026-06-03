# Build, QEMU e regressioni

## Prerequisiti

WSL Ubuntu consigliato:

```bash
bash scripts/setup-wsl.sh
```

Pacchetti: `nasm`, `gcc-multilib`, `grub-pc-bin`, `qemu-system-x86`, `python3`.

## Target Makefile

| Target | Azione |
|--------|--------|
| `make` / `make all` | Kernel + `darkmind-memory.bin` |
| `make iso` | `build/darkgreenos.iso` |
| `make run` | QEMU GTK (`-k it`) |
| `make run-serial` | + COM1 stdio |
| `make run-ai` | TCP 4444 per agent |
| `make verify-mb2` | Checksum Multiboot2 |
| `make clean` | Rimuove `build/`, `iso/` |
| `make regress` | `scripts/qemu_rmgr_regress.py` |
| `make cross-boot` | Patch DGFS + test profilo thr |
| `make benchmark` | `scripts/benchmark_rmgr.py` thr=1 vs 16 |

## GRUB (`grub.cfg`)

- `multiboot2` kernel  
- `module2` … `darkmind.memory` (DMTP)  
- `module2` … `dmem1` se configurato  

## Criteri accettazione RMGR (QEMU)

1. **20× Enter** con testo ≤71 char → no crash; `audit` con `act=1`
2. **Scan ripetuto** → `SKIP_SCAN`, dTicks cala
3. **`-m 512`** → `profile`: thr / free_min_kb_eff salgono
4. **`alloc 64`** → dFree_kb negativo coerente; `free` ripristina
5. **Mouse** → no raffica caratteri; tastiera in barra chat
6. **`make regress`** — seriale + policy/errors/run/sync
7. **`make cross-boot`** — `patch_dgfs_profile.py` + profilo thr da DGFS
8. **CI** — `.github/workflows/ci.yml` (build + size gate)
9. **`errors`** / **`errors clear`** su COM1

## Dimensioni attese

- ISO ~5 MB  
- Kernel ~63–64 KB (&lt; 80 KB)  

## Windows

```powershell
wsl -e bash -lc "cd /mnt/c/Users/feded/darkgreenos && make iso"
wsl -e bash -lc "cd /mnt/c/Users/feded/darkgreenos && make run"
```

Oppure `.\make-wsl.ps1` se presente.

## Push GitHub

```powershell
.\scripts\sync-github.ps1 -Message "docs: ..."
```

File &gt;100 MB (es. `darkmind-q4.bin`) restano fuori git — vedi `model/README.md`.
