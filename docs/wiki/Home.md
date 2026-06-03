# Wiki DarkgreenOS

Documentazione tecnica del kernel bare-metal **DarkgreenOS** e dell’orchestratore **DarkMind** (RMGR-first).

## Indice

| Pagina | Contenuto |
|--------|-----------|
| [Architettura generale](Architettura-generale) | Stack, obiettivi, cosa non è Linux |
| [Classico vs Orchestrator-Native](Kernel-classico-vs-Orchestrator-Native) | Confronto kernel classico, visione RMGR |
| [Avvio, Multiboot e kernel](Avvio-Multiboot-e-kernel) | Boot, GDT/IDT, IRQ, `kernel_main` |
| [RMGR — orchestratore risorse](RMGR-orchestratore) | Policy, snapshot, decisioni, profilo |
| [RMGR hook, audit e budget](RMGR-hook-audit-budget) | `enter`/`leave`, deny, ring audit |
| [DarkMind e DMTP](DarkMind-e-profilo-DMTP) | `darkmind_start`, `dmem`, cooperativo |
| [GUI, framebuffer e PS/2](GUI-framebuffer-e-PS2) | Desktop 1024×768, tastiera, mouse |
| [PMM e memoria](PMM-e-memoria) | Arena bump, alloc/free, paging |
| [Companion — comandi seriali](Companion-comandi-seriali) | Protocollo COM1, tutti i comandi |
| [Brain, TinyLM, OSView](Brain-TinyLM-osview) | Contesto, scan, inferenza leggera |
| [Riferimento API kernel](Riferimento-API-kernel) | **Ogni simbolo `global` per modulo** |
| [Costanti RMGR e snapshot](Costanti-RMGR-e-snapshot) | `RMGR_ACT_*`, `SNAP`, DMTP |
| [Build, QEMU e regressioni](Build-QEMU-regressioni) | `make`, test, criteri accettazione |
| [LLM su host (esterno)](LLM-host-e-futuro) | `companion_agent.py`, no ring 0 |

## Repo e documenti in-tree

- [README](https://github.com/DarkGreen-projects/darkgreenos/blob/main/README.md)
- `docs/rmgr-superiority.md`, `docs/darkmind-profile.md`, `docs/darkmind-external-llm.md`

## Versione

DarkgreenOS **v0.10** — Kernel core: DGFS RW, err ring, SYS_ALLOC user VA, rmgr_predict su GUI/scan/chat, benchmark CI.
