# Avvio, Multiboot e kernel

## `_start` (`boot.asm`)

Punto di ingresso Multiboot: magic in `eax`, info pointer in `ebx`. Salta a `kernel_main`.

## `mb_init` / `mb2_parse` (`multiboot_parse.asm`, `mb2_parse.asm`)

| Simbolo | Ruolo |
|---------|--------|
| `mb_init` | Inizializza da MB1 o MB2 |
| `mb2_parse` | Scorre tag MB2: framebuffer, mmap, moduli |
| `mb2_total_ram_kb` | RAM totale da mmap |
| `mb2_model_*` | Modulo GRUB `darkmind.memory` / modelli |
| `fb_init_from_mb2` | Imposta `fb_*` da tag framebuffer |

## `kernel_main` (`kernel.asm`)

Sequenza boot:

1. `gdt_load`, `idt_load`, `pic_remap`, `paging_init`
2. `vga_init`, banner testuale
3. `osview_init`, `pmm_init`, `pmm_alloc_init`, `sysres_init`
4. **`keyboard_init`** poi **`mouse_init`** (se `fb_active`)
5. `gui_init`, `brain_init`, `companion_init`
6. `pit_init`, `sti` → loop GUI o shell testo

## ISR (`idt.asm` + `isr_handler`)

| IRQ/EC | Vector | Handler |
|--------|--------|---------|
| Timer | 32 | `timer_ticks++`, `rmgr_periodic_tick` ogni N tick |
| Keyboard | 33 | Drain non-AUX → `keyboard_scancode` |
| Mouse | 44 | Solo byte AUX → `mouse_scancode` |
| Page fault | 14 | `page_fault_handler` + RMGR act 12 |
| GPF | 13 | `general_protection_handler` + RMGR act 13 |

**Importante:** dopo IRQ tastiera c’è `jmp .done` (non si cascata nel handler mouse).

## PIC (`pic_remap`)

Maschere: `0xF8` master, `0xEF` slave — IRQ0 (PIT), IRQ1 (kbd), IRQ12 (mouse) abilitati.

## Paging (`paging.asm`)

Identity map 4 GiB con PSE 4 MB; `ptr_in_identity_map` valida puntatori Multiboot.

## Utility

| Funzione | File |
|----------|------|
| `print_dec`, `print_hex32` | `kernel.asm` |
| `io_wait`, `pic_send_eoi` | `io.asm` |
| `timer_ticks` | BSS globale, ~100 Hz PIT |
