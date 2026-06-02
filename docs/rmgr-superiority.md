# RMGR-first: superiorità logica misurabile

DarkgreenOS non compete con Linux su driver/rete/processi. Vince su **governance risorse spiegabile**.

## Criteri

1. **Spiegabilità** — ogni azione costosa passa da `rmgr_hook_enter` / `leave` con delta numerici.
2. **Coerenza** — un solo motore (`rmgr` + profilo DMTP) per GUI, scan, chat, PMM.
3. **Apprendimento** — `rmgr_learn_from_delta` + `rmgr_tune_thresholds` + budget per classe.
4. **Costo prevedibile** — `rmgr_budget_ok` confronta EMA `dTicks` per classe con budget dinamico.
5. **Audit** — ring 32 entry; comando seriale `audit` (ultime 8).

## Copertura hook (Fase A)

| Path | Azione RMGR |
|------|-------------|
| GUI redraw/log | 7 / 8 |
| Enter / `think` | 1 (via darkmind) |
| osview scan | 9 |
| PMM alloc/free | 11 / 14 |
| Companion stats/policy/audit/snapshot | 10 |
| IRQ keyboard/mouse (poll) | 5 / 6 |
| Page fault / GPF | 12 / 13 |

## Test QEMU

```bash
make iso && make run-serial
# opzionale (WSL + pyserial):
python3 scripts/qemu_rmgr_regress.py
```

- GUI: 20× Enter con testo corto → `audit` mostra `act=1` (USER_QUERY).
- `scan` ripetuto → skip scan visibile (`rmgr_skip_osview_scan`), meno costo.
- `alloc 64` → `dFree_kb` negativo nel audit; `free` ripristina arena.
- `snapshot` → riga `SNAP free=... dF=... pol=... thr=...` + top audit.
- `-m 512` → `profile` mostra `thr` e `free_min_kb` in aumento.
- Kernel &lt; ~80 KB, ISO &lt; ~6 MB.

## Cross-boot

Vedi [darkmind-profile.md](darkmind-profile.md).

## LLM

Solo host: [darkmind-external-llm.md](darkmind-external-llm.md).
