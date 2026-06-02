# Costanti RMGR e snapshot

File: `src/constants.inc`.

## Azioni RMGR (`RMGR_ACT_*`)

| Valore | Nome | Uso |
|--------|------|-----|
| 1 | `RMGR_ACTION_USER_QUERY` | Enter / think / chat GUI |
| 2 | `RMGR_ACTION_PERIODIC` | Tick periodico |
| 3 | `RMGR_ACTION_COMPANION` | (legacy alias) |
| 4 | `RMGR_ACT_IRQ_TIMER` | PIT |
| 5 | `RMGR_ACT_IRQ_KEYBOARD` | IRQ1 / poll |
| 6 | `RMGR_ACT_IRQ_MOUSE` | IRQ12 / poll |
| 7 | `RMGR_ACT_GUI_REDRAW` | `gui_redraw` |
| 8 | `RMGR_ACT_GUI_LOG` | Log line |
| 9 | `RMGR_ACT_OSVIEW_SCAN` | `osview_scan_stats` |
| 10 | `RMGR_ACT_COMPANION_CMD` | Comando seriale |
| 11 | `RMGR_ACT_PMM_ALLOC` | `pmm_alloc_kb` |
| 12 | `RMGR_ACT_PAGE_FAULT` | Page fault |
| 13 | `RMGR_ACT_GPF` | General protection |
| 14 | `RMGR_ACT_PMM_FREE` | `pmm_free_all` |

## Motivi deny (`RMGR_REASON_*`)

| Valore | Nome |
|--------|------|
| 0 | OK |
| 1 | BUDGET_DENY |
| 2 | LOW_RAM |
| 3 | SKIP_SCAN |
| 4 | DEFER_REDRAW |

## Decisioni (`RMGR_DEC_*`)

0 BALANCE, 1 THROTTLE, 2 CAUTELA, 3 SAVE_FB, 4 EXPLAIN.

## Snapshot words (`RMGR_SNAP_*`)

Offset dword in `rmgr_before` / `rmgr_after`:

| Offset | Campo |
|--------|--------|
| 0 | RAM total kb |
| 4 | RAM free kb |
| 8 | Kernel kb |
| 12 | Regions |
| 16 | Mapped MB |
| 20 | Model kb |
| 24 | FB on |
| 28–36 | FB w, h, bpp, est kb |
| 44 | GUI on |
| 48–52 | Mouse x, y |
| 56 | Ticks |
| 60 | Action id |

## Profilo DMTP (`RMGR_PROF_*`)

Blob 64 byte, magic `DMTP_MAGIC`. Campi: uptime, actions, EMA free/dfree/dticks, throttle, score, free_min_kb, streak counters.

## Budget default

`RMGR_BUDGET_IRQ=80`, `GUI=400`, `SCAN=600`, `CHAT=800`, `COMP=400`, `PMM=200`.

## Limiti testo

- `DARKMIND_QUERY_MAX` = 128  
- `DARKMIND_ANSWER_MAX` = 1024  
- `GUI_INPUT_MAX` = 72  
