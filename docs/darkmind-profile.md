# Profilo adattivo DarkMind (DMTP)

DarkMind memorizza soglie e throttle imparati nel blob `darkmind.memory` (DMEM1), record `TYPE_MACHINE` con magic `DMTP`.

## Runtime

- Ogni azione utente aggiorna il profilo (`rmgr_learn_from_delta`, `rmgr_tune_thresholds`).
- Il profilo viene scritto in RAM DMEM1 con `dmem_profile_write`.
- Il tick periodico (~3 s) affina il profilo in background.

## Cross-boot (host)

1. Avvia QEMU con `-serial stdio`.
2. Dopo una sessione: `profile export` su COM1.
3. Copia la riga hex `DMTP export: ...`.
4. Merge:

```bash
python3 scripts/merge_dmem_profile.py --hex-file export.txt
# oppure
python3 scripts/merge_dmem_profile.py --hex "50544D44 ..."
```

5. `make iso` e riavvia: `rmgr_profile_load` ripristina `thr`, `score`, `free_min_kb`.

## Verifica

- `profile` su seriale: mostra `thr`, `base`, `score`, `free_min_kb`.
- Pannello GUI: `thr=` e `score=` nella colonna Orchestratore.
- Status bar: `pol=`, `thr=`, `score=`, `free_kb=`.
