# Architettura generale

## Stack tecnologico

| Componente | Scelta |
|------------|--------|
| CPU | i386 (32-bit protected mode) |
| Assembler | NASM (`elf32`) |
| Bootloader | GRUB 2, Multiboot2 |
| Display | Linear framebuffer 1024×768×32 (tag MB2) |
| Input | Controller PS/2 (tastiera IRQ1, mouse AUX) |
| Seriale | COM1 @ 38400 (Companion) |
| Emulator | QEMU (`qemu-system-x86_64`) |

## Filosofia: RMGR-first

DarkgreenOS **non** mira a replicare Linux (driver di rete, VFS, processi preemptivi completi). Punta su:

1. **Misurabilità** — ogni percorso costoso passa da RMGR con delta RAM/ticks.
2. **Spiegabilità** — audit ring + comandi `stats`, `policy`, `snapshot`, `audit`.
3. **Profilo adattivo** — blob DMTP (`darkmind.memory`) tra un boot e l’altro.
4. **LLM fuori ring 0** — nessun decode generativo nel kernel; host opzionale.

## Moduli kernel (link attivi)

```
boot.asm → kernel.asm
  ├── gdt / idt / paging / pit
  ├── vga + framebuffer + gfx + gui
  ├── keyboard + mouse (ps2_poll)
  ├── serial + companion
  ├── osview + brain + tinylm
  ├── pmm + pmm_alloc + mem_safe
  ├── rmgr + rmgr_profile + rmgr_audit + rmgr_hook
  └── darkmind + dmem
```

`archive/llm/*` **non** è linkato nel Makefile.

## Loop principale (GUI)

```
gui_loop:
  ps2_poll          → drain porta 0x60
  keyboard_poll     → carattere ASCII da buffer
  gui_handle_key    → barra chat + Enter → brain_think
  gui_poll          → mouse, redraw, caret
  companion_poll    → linea seriale
  brain_step        → darkmind_step + tinylm_step
  hlt
```

## Flusso Enter / DarkMind

1. Utente scrive in `gui_input` e preme Enter.
2. `gui_handle_key` → `brain_think` (copia query in `brain_ctx`).
3. `darkmind_start` → RMGR enter (act=1), policy, scan opzionale, apply policy.
4. `darkmind_step` (periodico) emette righe report su `gui_log_line` / pannelli.
5. `dmem_append_interaction` persiste sintesi nel profilo DMTP.

## Limiti di progetto

- ISO ~5 MB, kernel ~63–64 KB (target &lt; 80 KB).
- Nessun `darkmind-q4.bin` in ISO (solo reference locale / archive).

## Prossima fase (B) — in kernel v0.6

- `syscall.asm` con hook RMGR (`int 0x80`)
- Scheduler preempt RMGR-aware (`scheduler.asm`)
- PMM free-list (`pmm_alloc.asm`)
- FS minimale embedded (`fs_min.asm`)
- `RMGR_ACT_IRQ_TIMER` cablato nel PIT
- Fault recovery RMGR-aware (page fault / GPF user)

Vedi [Classico vs Orchestrator-Native](Kernel-classico-vs-Orchestrator-Native).
