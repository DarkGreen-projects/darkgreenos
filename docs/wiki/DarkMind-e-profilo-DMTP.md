# DarkMind e profilo DMTP

## DarkMind runtime (`darkmind.asm`)

Cooperativo: non blocca il kernel con decode LLM.

| Funzione | Descrizione |
|----------|-------------|
| `darkmind_start(esi=query)` | Copia prompt, `dmem_init`, `rmgr_init`, hook enter USER_QUERY, policy, scan, apply, `darkmind_busy=1` |
| `darkmind_step` | Ogni N tick (`rmgr_throttle_div`) emette prossima riga `rmgr_get_report_line` su GUI |
| `darkmind_busy` | Flag emissione in corso |

Buffer: `darkmind_prompt`, `darkmind_answer` (max `DARKMIND_ANSWER_MAX`).

## DMTP / dmem (`dmem.asm`)

**D**ark**M**ind **T**ransfer **P**rofile — blob persistito in `model/darkmind-memory.bin`, modulo GRUB `darkmind.memory`.

| Funzione | Descrizione |
|----------|-------------|
| `dmem_init` | Puntatore da modulo MB2 o arena |
| `dmem_query` | Lookup chiave nel profilo |
| `dmem_append_interaction` | Aggiorna dopo risposta |
| `dmem_profile_load` / `write` | 64 byte DMTP |
| `dmem_profile_export` | Esportazione seriale (profile export) |
| `dmem_ready`, `dmem_ptr`, `dmem_size` | Stato modulo |

Magic: `DMTP_MAGIC` (`0x50544D44`).

Campi profilo (word index): uptime, actions, EMA free/dfree/dticks, throttle, score — vedi `RMGR_PROF_*` in `constants.inc`.

## Integrazione GUI

- Enter nella barra → `brain_think` → `darkmind_start`
- `gui_panel_refresh` / `rmgr_format_panel` nel pannello “Orchestratore”
- `gui_log_line` per output multi-riga

## Cosa DarkMind **non** fa

- Non carica Qwen / `darkmind-q4.bin` in ring 0  
- Non esegue `llm_decode` (sorgenti in `archive/llm/`)

Per LLM generativo: [LLM host e futuro](LLM-host-e-futuro).
