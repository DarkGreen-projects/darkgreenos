# Companion — comandi seriali

File: `src/companion.asm`, UART `src/serial.asm`.

## UART COM1

| Funzione | Descrizione |
|----------|-------------|
| `serial_init` | 38400 8N1, FIFO on |
| `serial_tx` / `serial_rx` | Byte TX/RX |
| `serial_write` / `serial_writeln` | Stringa |
| `serial_rx_ready` | Poll ricezione |

## Loop

`companion_poll` legge COM1 fino a CR/LF → `companion_exec_line`.

Ogni comando passa da **`rmgr_hook_enter`** act `RMGR_ACT_COMPANION_CMD` (10) quando applicabile.

## Elenco comandi

| Comando | Effetto |
|---------|---------|
| `help` | Lista comandi |
| `ping` | `PONG DarkgreenOS` |
| `hello` / `ciao` | Saluto |
| `status` | Nome, mood, persona, ticks |
| `say <testo>` | Stampa messaggio |
| `name` / `mood` / `persona` / `patch` | Personalità companion |
| `color` | Colore VGA |
| `clear` | Pulisce schermo |
| `ticks` | Timer |
| `think <testo>` | `brain_think` come GUI Enter |
| `map` | Mappa kernel Multiboot |
| `files` / `find` / `dump` | OSView |
| `scan` | `osview_scan_stats` (RMGR 9) |
| `gui` / `redraw` / `fb` | Stato framebuffer |
| `mouse` | Posizione pulsanti |
| `stats` | Pannello RMGR completo |
| `policy` | Decision, dFree, dTicks |
| `profile` | Profilo DMTP |
| `profile export` | Export blob seriale |
| `audit` | Ultime entry audit |
| `snapshot` | Riga `SNAP free=…` + top audit |
| `alloc <kb>` | `pmm_alloc_kb` |
| `free` | `pmm_free_all` |
| `llm <prompt>` | Stub → usa host `companion_agent.py` |

## Formato snapshot

```
SNAP free=<kb> dF=<kb> dT=<ticks> pol=<n> thr=<n> score=<n> audit=<n> |<line0>|...
```

Parser host: `tools/companion_agent.py`.

## Host agent

```bash
make run-ai          # QEMU TCP 4444
python3 tools/companion_agent.py
```

Modalità diagnostica: parole chiave `lento`, `rmgr`, `ram`, ecc. → invio automatico SNAPSHOT+AUDIT.
