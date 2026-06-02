# LLM su host (esterno)

## Principio

Il kernel **non** esegue decode generativo (no Qwen, no `darkmind-q4.bin` in ISO). Sorgenti storici: `archive/llm/`.

## Contratto kernel ↔ host

1. Kernel: comando **`snapshot`** → riga `SNAP free=… dF=… dT=… pol=… thr=… score=… audit=…`
2. Kernel: **`audit`**, **`stats`**, **`policy`**, **`profile`**
3. Kernel: **`llm <prompt>`** → stub che rimanda a host
4. Host: `tools/companion_agent.py` — legge seriale, opzionale LLM cloud/locale, risponde `SAY`

## companion_agent.py

- Connessione: stdio (`run-serial`) o TCP 4444 (`run-ai`)
- Parser riga SNAP
- Modalità diagnostica (parole chiave → SNAPSHOT + AUDIT automatici)

## darkmind-q4.bin (~275 MB)

- Generato da `scripts/build_darkmind_blob.py`
- **Non** su GitHub (limite 100 MB)
- Solo riferimento / sperimenti archive

## Persistenza profilo

- Build: `scripts/build_darkmind_memory.py` → `model/darkmind-memory.bin`
- Merge host: `scripts/merge_dmem_profile.py`
- Doc: `docs/darkmind-profile.md`, `docs/darkmind-external-llm.md`

## Fase B (futuro kernel)

- Syscall con hook RMGR
- Scheduler preempt
- FS minimale

Senza reintrodurre LLM in ring 0 salvo nuova architettura esplicita.
