# Riferimento API kernel

Elenco dei simboli **`global`** esportati per modulo (calling convention cdecl salvo note).

---

## `boot.asm`

| Simbolo | Descrizione |
|---------|-------------|
| `_start` | Entry Multiboot |

## `kernel.asm`

| Simbolo | Descrizione |
|---------|-------------|
| `kernel_main` | Entry kernel |
| `isr_handler` | Dispatcher eccezioni/IRQ |
| `print_dec` | Stampa decimale EAX |
| `print_hex32` | Stampa hex 8 cifre |
| `timer_ticks` | Contatore PIT |

## `gdt.asm`

| Simbolo | Descrizione |
|---------|-------------|
| `gdt_load` | Carica GDT + segmenti flat |

## `idt.asm`

| Simbolo | Descrizione |
|---------|-------------|
| `idt_load` | 48 vettori ISR |
| `pic_remap` | Remap PIC a 32+, unmask IRQ |
| `isr0`…`isr47` | Stub interrupt |

## `io.asm`

| Simbolo | Descrizione |
|---------|-------------|
| `irq_vector` | Ultimo vettore servito |
| `io_wait` | Pause I/O port 0x80 |
| `pic_send_eoi` | EOI master/slave |

## `paging.asm`

| Simbolo | Descrizione |
|---------|-------------|
| `page_directory` | Directory paging |
| `paging_init` | Abilita paging identity |

## `pit.asm`

| Simbolo | Descrizione |
|---------|-------------|
| `pit_init` | Channel 0 ~100 Hz |

## `vga.asm`

| Simbolo | Descrizione |
|---------|-------------|
| `vga_init` / `vga_clear` | Text 80×25 |
| `vga_putchar` / `vga_print` / `vga_print_ln` | Output |
| `vga_set_color` | Attributo colore |
| `vga_cursor_x` / `vga_cursor_y` | Cursore |

## `framebuffer.asm`

| Simbolo | Descrizione |
|---------|-------------|
| `fb_addr`, `fb_width`, `fb_height`, `fb_pitch`, `fb_bpp`, `fb_active` | Stato FB |
| `fb_init_from_mb2` | Init da tag MB2 |
| `fb_put_pixel`, `fb_xor_pixel`, `fb_fill_rect`, `fb_clear` | Disegno |

## `gfx.asm` / `font8.asm`

| Simbolo | Descrizione |
|---------|-------------|
| `font8_table` | Font bitmap |
| `gfx_draw_char`, `gfx_draw_string`, `gfx_draw_string_at` | Testo FB |

## `keyboard.asm`

| Simbolo | Descrizione |
|---------|-------------|
| `key_buffer`, `key_buffer_head`, `key_buffer_tail` | Ring buffer ASCII |
| `keyboard_init`, `keyboard_scancode`, `keyboard_poll`, `keyboard_read` | Driver |
| `keyboard_clear_buffer`, `keyboard_port_poll`, `keyboard_may_type` | Utilità |
| `keyboard_last_scancode`, `keyboard_last_char`, `keyboard_rx_count` | Debug |
| `ps2_poll` | Drain PS/2 unificato |

## `mouse.asm`

| Simbolo | Descrizione |
|---------|-------------|
| `mouse_init`, `mouse_scancode`, `mouse_poll` | Driver mouse |
| `mouse_x`, `mouse_y`, `mouse_buttons`, `mouse_wheel_delta` | Stato |
| `mouse_packet_idx`, `mouse_packet_byte` | Assembler pacchetto |
| `ps2_is_mouse_data_byte` | Euristica routing |
| `mouse_suppress_keys_until` | Legacy suppress |

## `gui.asm`

| Simbolo | Descrizione |
|---------|-------------|
| `gui_init`, `gui_poll`, `gui_redraw`, `gui_handle_key` | Loop GUI |
| `gui_log_line`, `gui_show_resources`, `gui_panel_refresh` | Output |
| `gui_dirty` | Flag redraw |

## `serial.asm`

| Simbolo | Descrizione |
|---------|-------------|
| `serial_init`, `serial_tx`, `serial_rx`, `serial_rx_ready` | UART |
| `serial_write`, `serial_writeln` | Stringhe |

## `companion.asm`

| Simbolo | Descrizione |
|---------|-------------|
| `companion_init`, `companion_poll`, `companion_exec_line` | Protocollo |
| `companion_name`, `companion_mood`, `companion_persona` | Data |

## `multiboot_parse.asm` / `mb2_parse.asm`

| Simbolo | Descrizione |
|---------|-------------|
| `mb_init`, `mb_ensure_info`, `mb_has_mmap`, `mb_has_mods` | MB1 |
| `mb_print_map`, `mb_ram_total_kb`, `multiboot_info_ptr`, `multiboot_magic` | Info |
| `mb2_parse` + `mb2_*` | Tag MB2, mmap, moduli |

## `pmm.asm` / `pmm_alloc.asm`

| Simbolo | Descrizione |
|---------|-------------|
| `pmm_init`, `pmm_free_kb`, `pmm_model_kb`, … | PMM |
| `pmm_alloc_init`, `pmm_alloc_kb`, `pmm_free_all`, `pmm_alloc_used_kb` | Arena |

## `mem_safe.asm`

| Simbolo | Descrizione |
|---------|-------------|
| `ptr_in_identity_map` | Validazione puntatore |

## `sysres.asm`

| Simbolo | Descrizione |
|---------|-------------|
| `sysres_init`, `sysres_set_mem_kb`, `sysres_set_fb`, `sysres_sync_mouse`, `sysres_append_ctx` | API |
| `sysres_ram_kb`, `sysres_fb_*`, `sysres_mouse_*`, `sysres_gui_on` | Campi |

## `osview.asm`

| Simbolo | Descrizione |
|---------|-------------|
| `osview_init`, `osview_scan_stats`, `osview_print_kernel_map`, `osview_dump`, `osview_find` | Scan |
| `os_stat_*` | Statistiche |

## `brain.asm`

| Simbolo | Descrizione |
|---------|-------------|
| `brain_init`, `brain_refresh`, `brain_think`, `brain_step`, `brain_infer` | Mind |
| `brain_ctx`, `brain_mood` | Stato |

## `tinylm.asm`

| Simbolo | Descrizione |
|---------|-------------|
| `tinylm_start`, `tinylm_step`, `tinylm_busy` | Tiny LM |

## `darkmind.asm`

| Simbolo | Descrizione |
|---------|-------------|
| `darkmind_start`, `darkmind_step`, `darkmind_busy` | Orchestratore UI |

## `dmem.asm`

| Simbolo | Descrizione |
|---------|-------------|
| `dmem_init`, `dmem_query`, `dmem_append_interaction` | Profilo |
| `dmem_profile_load`, `dmem_profile_write`, `dmem_profile_export` | DMTP |
| `dmem_ready`, `dmem_ptr`, `dmem_size`, `dmem_result` | Stato |

## `rmgr.asm`

| Simbolo | Descrizione |
|---------|-------------|
| `rmgr_boot_init`, `rmgr_init`, `rmgr_refresh` | Lifecycle |
| `rmgr_begin_action`, `rmgr_end_action` | Coppia azione |
| `rmgr_policy_eval`, `rmgr_apply_policy` | Policy |
| `rmgr_format_panel`, `rmgr_format_snapshot`, `rmgr_format_status` | Testo |
| `rmgr_get_report_line`, `rmgr_report_line_count` | Report |
| `rmgr_decision`, `rmgr_reason`, `rmgr_throttle_div`, `rmgr_skip_*` | Policy state |
| `rmgr_delta_free_kb`, `rmgr_delta_ticks` | Delta |
| `rmgr_query_has_mem`, `rmgr_query_has_scan` | Flag query |
| `rmgr_current`, `rmgr_before`, `rmgr_after` | Snapshot |

## `rmgr_profile.asm`

| Simbolo | Descrizione |
|---------|-------------|
| `rmgr_profile_blob`, `rmgr_profile_load`, `rmgr_profile_save` | Blob |
| `rmgr_learn_from_delta`, `rmgr_tune_thresholds`, `rmgr_classify_action` | Learn |
| `rmgr_periodic_tick`, `rmgr_format_status`, `rmgr_current_action` | Tick |
| `rmgr_profile_score`, `rmgr_throttle_base`, `rmgr_free_min_kb_eff`, `rmgr_free_pct_eff` | Soglie |
| `rmgr_skip_osview_scan`, `rmgr_last_scan_tick`, `rmgr_resource_class` | Scan |
| `rmgr_profile_defaults`, `rmgr_ema_dticks_class` | Default/EMA |

## `rmgr_hook.asm`

| Simbolo | Descrizione |
|---------|-------------|
| `rmgr_hook_init`, `rmgr_hook_enter`, `rmgr_hook_leave` | Hook |
| `rmgr_budget_ok` | Deny/allow |
| `rmgr_budget_irq/gui/scan/chat` (+ comp/pmm in BSS) | Budget |
| `rmgr_irq_kbd_count`, `rmgr_irq_mouse_count` | IRQ stats |
| `rmgr_hook_active`, `rmgr_hook_depth` | Stato hook |

## `rmgr_audit.asm`

| Simbolo | Descrizione |
|---------|-------------|
| `rmgr_audit_push`, `rmgr_audit_format_line`, `rmgr_audit_append_top3` | Audit |
| `rmgr_audit_count`, `rmgr_audit_head`, `rmgr_audit_line` | Ring |

## `pagefault.asm` / `gpfault.asm` / `invalidop.asm`

| Simbolo | Descrizione |
|---------|-------------|
| `page_fault_handler` | #PF + RMGR |
| `general_protection_handler` | #GP + RMGR |
| `invalid_opcode_handler` | #UD |

## `longmode64.asm`

| Simbolo | Descrizione |
|---------|-------------|
| `longmode64_scaffold` | Scaffold 64-bit (non boot path) |

---

Per costanti numeriche delle azioni RMGR vedere [Costanti RMGR e snapshot](Costanti-RMGR-e-snapshot).
