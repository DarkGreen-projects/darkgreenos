# RMGR — orchestratore risorse

File: `src/rmgr.asm`, `src/rmgr_profile.asm`, `src/constants.inc`.

## Concetto

**RMGR** (Resource Manager) tiene snapshot **before/after** per ogni azione classificata, calcola Δfree_kb e Δticks, valuta policy e aggiorna profilo DMTP.

## Ciclo di un’azione

```
rmgr_hook_enter(eax=RMGR_ACT_*)
  → rmgr_begin_action: copia sysres in rmgr_before
  → rmgr_budget_ok (può deny)
lavoro kernel...
rmgr_hook_leave
  → rmgr_end_action: snapshot after, delta, audit push
  → rmgr_learn_from_delta, rmgr_tune_thresholds
```

## Funzioni principali (`rmgr.asm`)

| Simbolo | Descrizione |
|---------|-------------|
| `rmgr_boot_init` | Init a boot da profilo DMTP |
| `rmgr_init` | Inizio sessione query (before snapshot) |
| `rmgr_refresh` | Aggiorna metriche sysres correnti |
| `rmgr_begin_action` / `rmgr_end_action` | Coppia per azione interna |
| `rmgr_policy_eval` | Valuta testo query (memoria, scan, …) |
| `rmgr_apply_policy` | Applica throttle, skip redraw, decision string |
| `rmgr_format_panel` | Buffer testo pannello GUI orchestratore |
| `rmgr_format_snapshot` | Riga `SNAP free=…` per seriale |
| `rmgr_get_report_line` | Righe report per `darkmind_step` |

## Variabili globali utili

| Simbolo | Significato |
|---------|-------------|
| `rmgr_decision` | `RMGR_DEC_*` (BALANCE, THROTTLE, …) |
| `rmgr_reason` | OK, BUDGET_DENY, LOW_RAM, SKIP_SCAN, DEFER_REDRAW |
| `rmgr_delta_free_kb` / `rmgr_delta_ticks` | Ultimo delta |
| `rmgr_skip_redraw` / `rmgr_skip_osview_scan` | Flag policy |
| `rmgr_throttle_div` | Divisore emissione righe DarkMind |
| `rmgr_before` / `rmgr_after` / `rmgr_current` | Snapshot 16× dword |

## Profilo (`rmgr_profile.asm`)

| Simbolo | Descrizione |
|---------|-------------|
| `rmgr_profile_load` / `save` | Blob 64 byte DMTP |
| `rmgr_learn_from_delta` | EMA su free/dfree/dticks |
| `rmgr_tune_thresholds` | Adatta `rmgr_free_min_kb_eff`, score |
| `rmgr_periodic_tick` | Campionamento IRQ kbd/mouse (~3 s) |
| `rmgr_format_status` | Riga corta barra stato GUI |
| `rmgr_classify_action` | Classifica testo utente |

## Decisioni (`RMGR_DEC_*`)

- **BALANCE** — situazione normale  
- **THROTTLE** — RAM bassa o budget negato  
- **CAUTELA** — scan saltato  
- **SAVE_FB** — ridisegno differito  
- **EXPLAIN** — modalità spiegazione risorse  

Vedi anche [Costanti RMGR e snapshot](Costanti-RMGR-e-snapshot).
