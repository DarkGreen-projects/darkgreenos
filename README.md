# DarkgreenOS

Sistema operativo **bare-metal** per **i386**, scritto in **NASM**, avviato con **GRUB Multiboot2**. Include una **GUI** 1024×768 (framebuffer lineare), input PS/2 (tastiera e mouse) e un orchestratore di risorse chiamato **DarkMind** — senza LLM generativo nel kernel.

Repository: [DarkGreen-projects/darkgreenos](https://github.com/DarkGreen-projects/darkgreenos)

**Wiki dettagliata** (architettura, ogni modulo/funzione, RMGR, comandi):

- Tab Wiki: https://github.com/DarkGreen-projects/darkgreenos/wiki (dopo la prima pagina creata su GitHub, pubblica con `.\scripts\push-wiki.ps1`)
- Sorgente in repo: [docs/wiki/](docs/wiki/)

## Cos'è

**DarkgreenOS** è un OS didattico/sperimentale orientato alla **governance misurabile delle risorse** (RAM, GUI, allocazioni, IRQ), non a clonare Linux.

**DarkMind** (nel kernel) è un **orchestratore cooperativo**:

- **RMGR** — profilo risorse, policy, audit, budget per azione
- **DMTP** — profilo cross-boot (`darkmind.memory` / `dmem.asm`)
- Risposte in GUI/seriale basate su metriche reali del sistema

**Non** c'è un modello linguistico grande in ring 0: niente Qwen né `darkmind-q4.bin` nell'ISO. L'LLM opzionale gira solo sull'**host** tramite `tools/companion_agent.py` (vedi [docs/darkmind-external-llm.md](docs/darkmind-external-llm.md)).

| Target tipico | Valore |
|---------------|--------|
| ISO | ~5 MB |
| Kernel | ~63–64 KB (limite progetto ~80 KB) |

## Requisiti

- **WSL2** (consigliato su Windows) oppure Linux
- `nasm`, `ld` (i386), `grub-mkrescue`, `python3`, `qemu-system-x86`
- Setup rapido WSL: `bash scripts/setup-wsl.sh`

Su Windows, dalla root del repo:

```bash
wsl -e bash -lc "cd /mnt/c/Users/feded/darkgreenos && bash scripts/setup-wsl.sh"
```

*(Adatta il path se hai clonato altrove.)*

## Build

```bash
cd /mnt/c/Users/feded/darkgreenos   # o la tua directory
make iso
```

Genera `build/darkgreenos.iso` e copia `model/darkmind-memory.bin` in `iso/boot/memory/`.

Verifica opzionale Multiboot2:

```bash
make verify-mb2
```

## Esecuzione in QEMU

| Comando | Uso |
|---------|-----|
| `make run` | GUI GTK, seriale non su stdio (evita crash QEMU su burst I/O) |
| `make run-serial` | GUI + **COM1 su stdio** (comandi `stats`, `snapshot`, `think`, …) |
| `make run-ai` | Seriale TCP `127.0.0.1:4444` + agent host |

**Tastiera:** clicca dentro la finestra QEMU prima di digitare. In basso compare il debug `KBD sc=.. ch=.. n=..` quando arrivano scancode.

**Barra chat:** scrivi testo e premi **Enter** per la risposta DarkMind cooperativa (misura risorse prima/dopo).

Memoria QEMU predefinita: 2048 MB (`QEMU_MEM=512 make run` per stress test RMGR).

## Companion seriale (host)

Con `make run-serial` o `make run-ai`:

```bash
python3 tools/companion_agent.py
```

Comandi utili sul kernel (anche da terminale seriale): `HELP`, `STATS`, `SNAPSHOT`, `AUDIT`, `PROFILE`, `THINK <testo>`, `ALLOC`, `FREE`.

## Struttura del repository

```
src/           Kernel, GUI, PS/2, RMGR, DarkMind, PMM, companion seriale
docs/          RMGR, profilo DMTP, contratto LLM host
scripts/       Build ISO, regress QEMU, merge profilo
tools/         companion_agent.py (LLM / diagnostica su host)
model/         darkmind-memory.bin (in git), darkmind-q4.bin (locale, >100MB)
archive/llm/   Sorgenti LLM storici — solo riferimento, non linkati
```

## Modelli e file grandi

`model/darkmind-q4.bin` (~275 MB) **non** è su GitHub (limite 100 MB/file). Resta in locale o si rigenera con `scripts/build_darkmind_blob.py`. Dettagli: [model/README.md](model/README.md).

## Documentazione

- [docs/rmgr-superiority.md](docs/rmgr-superiority.md) — hook RMGR e criteri
- [docs/darkmind-profile.md](docs/darkmind-profile.md) — profilo DMTP
- [docs/darkmind-external-llm.md](docs/darkmind-external-llm.md) — LLM solo su host

## Regressione RMGR (opzionale)

```bash
python3 scripts/qemu_rmgr_regress.py
```

Richiede WSL, QEMU e (per alcuni test) `pyserial`.

## Licenza e contributi

Progetto **DarkGreen-projects**. Per aggiornare il repo dopo modifiche locali: commit + `git push`, oppure `.\scripts\sync-github.ps1 -Message "descrizione"` su Windows.

---

*DarkgreenOS v0.5 — RMGR-first, no generative LLM in ring 0.*
