# Brain, TinyLM e OSView

## Brain (`brain.asm`)

Interfaccia “mente” tra GUI e DarkMind.

| Funzione | Descrizione |
|----------|-------------|
| `brain_init` | Init contesto, `rmgr_boot_init` |
| `brain_refresh` | Aggiorna statistiche OS in `brain_ctx` |
| `brain_think(esi=query)` | Avvia catena: refresh → `darkmind_start` |
| `brain_step` | `tinylm_step` (cooperativo) |
| `brain_infer` | MLP tiny 4→4→2 su RAM/regions/kernel/ticks → `brain_mood` |
| `brain_ctx` | Buffer `BRAIN_CTX_SIZE` testo contesto |

Keyword routing (mem, map, scan, dump, …) per risposte template in modalità legacy.

## TinyLM (`tinylm.asm`)

Motore minimale cooperativo (non Qwen).

| Simbolo | Descrizione |
|---------|-------------|
| `tinylm_start` | Carica blob `tinylm.bin` |
| `tinylm_step` | Step non bloccante |
| `tinylm_busy` | Flag busy (GUI “thinking…”) |

## OSView (`osview.asm`)

Introspezione kernel / memoria.

| Funzione | Descrizione |
|----------|-------------|
| `osview_init` | Setup |
| `osview_scan_stats` | Scan regioni (costoso, RMGR 9) |
| `osview_print_kernel_map` | Mappa moduli |
| `osview_dump` / `osview_find` | Dump / find pattern |
| `os_stat_ram_kb`, `os_stat_regions`, `os_stat_kernel_bytes`, `os_stat_mapped_mb` | Metriche globali |

`rmgr_skip_osview_scan` evita scan ripetuti se policy CAUTELA.
