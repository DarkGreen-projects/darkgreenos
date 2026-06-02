# LLM esterni (integrazione software)

Il kernel DarkgreenOS **non** carica modelli generativi (`llm_*`, `module2` Qwen).

## Orchestratore kernel (sempre attivo)

- `rmgr.asm` + `rmgr_profile.asm` + `darkmind.asm`
- Metriche, policy, profilo DMTP, emissione cooperativa

## LLM futuro (host)

Contratto implementato:

1. **Kernel** — comando seriale `snapshot` emette una riga machine-readable:
   `SNAP free=<kb> dF=<kb> dT=<ticks> pol=<n> thr=<n> score=<n> audit=<n> |<audit0>|...`
2. **Host** — `tools/companion_agent.py` invia `SNAPSHOT` + `AUDIT` quando l’utente chiede diagnostica (lento, RAM, `/rmgr`, …) e risponde con `SAY` citando metriche reali.
3. **Persistenza** — profilo DMTP in `dmem.asm` / `darkmind.memory` (vedi [darkmind-profile.md](darkmind-profile.md)).

Comando stub nel kernel: `llm <prompt>` risponde che il generativo va su `tools/companion_agent.py`, non in ring 0.

## Vietato nel kernel cooperativo

- Link di `llm_decode`, tokenizer, logits
- Blob da centinaia di MB in ISO
- Decode sincrono su Enter (freeze)

I sorgenti storici restano in `archive/llm/` solo come riferimento.
