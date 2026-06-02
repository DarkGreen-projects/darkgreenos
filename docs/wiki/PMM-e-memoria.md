# PMM e memoria

## PMM (`pmm.asm`)

Gestione memoria fisica alta livello per statistiche RMGR.

| Simbolo | Descrizione |
|---------|-------------|
| `pmm_init` | Da mmap MB2: RAM libera, regioni |
| `pmm_free_kb` | KB liberi stimati |
| `pmm_llm_arena_kb` / `pmm_llm_allowed` | Limiti arena LLM (legacy policy) |
| `pmm_model_kb` | Dimensione modello se presente |

## PMM alloc (`pmm_alloc.asm`)

Arena bump a `PMM_ARENA_BASE` (`0x00200000`), 4 MB.

| Funzione | Descrizione |
|----------|-------------|
| `pmm_alloc_init` | Reset puntatore arena |
| `pmm_alloc_kb` | Alloca N KB (hook RMGR 11) |
| `pmm_free_all` | Libera tutta arena (hook RMGR 14) |
| `pmm_alloc_used_kb` | KB usati |

Comandi companion: **`alloc 64`**, **`free`**.

## Paging (`paging.asm`)

| Simbolo | Descrizione |
|---------|-------------|
| `paging_init` | Page directory identity 4 GiB PSE |
| `page_directory` | Struttura directory |

## mem_safe (`mem_safe.asm`)

| Funzione | Descrizione |
|----------|-------------|
| `ptr_in_identity_map` | Verifica puntatore nel map identity prima di dereference MB2 |

## Sysres (`sysres.asm`)

Snapshot “risorse sistema” per RMGR/GUI.

| Simbolo | Descrizione |
|---------|-------------|
| `sysres_init` | Init da PMM + FB |
| `sysres_set_mem_kb` / `sysres_set_fb` | Aggiornamento |
| `sysres_sync_mouse` | Copia mouse in sysres |
| `sysres_append_ctx` | Append contesto testuale brain |
| `sysres_ram_kb`, `sysres_fb_*`, `sysres_mouse_*`, `sysres_gui_on` | Campi |

Indici in `RMGR_SNAP_*` allineati a questi valori.
