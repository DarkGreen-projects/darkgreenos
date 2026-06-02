# RMGR hook, audit e budget

File: `src/rmgr_hook.asm`, `src/rmgr_audit.asm`.

## `rmgr_hook_enter` / `rmgr_hook_leave`

| API | Parametro | Ritorno |
|-----|-----------|---------|
| `rmgr_hook_enter` | `eax` = `RMGR_ACT_*` | `al=1` allow, `al=0` deny |
| `rmgr_hook_leave` | (nessuno) | Aggiorna learn + audit |

`rmgr_hook_depth` permette hook annidati (es. companion dentro GUI).

## `rmgr_budget_ok`

Confronta EMA `rmgr_ema_dticks_class` con budget per classe:

| Azione | Budget tipico (tick EMA) |
|--------|--------------------------|
| IRQ kbd/mouse | `RMGR_BUDGET_IRQ` (80) |
| GUI redraw/log | `RMGR_BUDGET_GUI` (400) |
| OSView scan | `RMGR_BUDGET_SCAN` (600) |
| USER_QUERY / chat | `RMGR_BUDGET_CHAT` (800) |
| Companion cmd | `RMGR_BUDGET_COMP` (400) |
| PMM alloc/free | `RMGR_BUDGET_PMM` (200) |

Deny imposta `rmgr_reason` (`BUDGET_DENY`, `LOW_RAM`, `SKIP_SCAN`).

## Audit ring (`rmgr_audit.asm`)

| Simbolo | Ruolo |
|---------|--------|
| `rmgr_audit_push` | Inserisce entry (act, dFree, dTicks, reason) |
| `rmgr_audit_count` / `rmgr_audit_head` | Ring 32 entry |
| `rmgr_audit_format_line` | Una riga testo |
| `rmgr_audit_append_top3` | Top 3 nel formato snapshot |

Comando seriale **`audit`** — ultime 8 entry.

## IRQ sampling

`rmgr_irq_kbd_count` / `rmgr_irq_mouse_count` incrementati in ISR; azzerati in `rmgr_periodic_tick` per statistiche leggere senza hook in ogni IRQ.

## Fault

| Fault | `RMGR_ACT_*` |
|-------|----------------|
| Page fault | 12 |
| General protection | 13 |

Handler in `pagefault.asm` / `gpfault.asm` + log seriale.
