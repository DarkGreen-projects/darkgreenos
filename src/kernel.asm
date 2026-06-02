; DarkgreenOS - kernel main

%include "constants.inc"

extern gdt_load
extern idt_load
extern pic_remap
extern pic_send_eoi
extern paging_init
extern page_fault_handler
extern general_protection_handler
extern invalid_opcode_handler
extern companion_init
extern companion_poll
extern mb_init
extern osview_init
extern brain_init
extern brain_step
extern rmgr_periodic_tick
extern rmgr_irq_kbd_count
extern rmgr_irq_mouse_count
extern pmm_init
extern pmm_alloc_init
extern sysres_init
extern gui_init
extern gui_poll
extern gui_handle_key
extern gui_log_line
extern fb_clear
extern mouse_init
extern mouse_scancode
extern mouse_poll
extern ps2_poll
extern keyboard_port_poll
extern vga_init
extern vga_clear
extern vga_print
extern vga_print_ln
extern vga_set_color
extern vga_putchar
extern keyboard_init
extern keyboard_poll
extern keyboard_scancode
extern pit_init
extern irq_vector
extern fb_active

global kernel_main
global isr_handler
global print_dec
global print_hex32

section .data
banner:     db "========================================", 0
title:      db "  DarkgreenOS v0.5 + DarkMind GUI", 0
subtitle:   db "  Linear FB | mouse | local mind sees resources", 0
paging_ok:  db "  [paging] identity 4 GiB VA | QEMU -m 2048", 0
ready:      db "  GUI desktop + serial Companion (HELP/GUI/THINK)", 0
prompt:     db "> ", 0
unknown:    db "[isr] vector ", 0

section .rodata
hex_digits: db "0123456789ABCDEF"

section .text
kernel_main:
    mov eax, [esp + 4]
    mov ebx, [esp + 8]
    call mb_init

    call gdt_load
    call idt_load
    call pic_remap
    call paging_init

    mov ax, GDT_DATA_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    call vga_init
    call vga_clear

    mov al, COLOR_DARKGREEN
    call vga_set_color
    mov esi, banner
    call vga_print_ln
    call vga_print_ln
    mov esi, title
    call vga_print_ln
    mov esi, subtitle
    call vga_print_ln
    mov esi, paging_ok
    call vga_print_ln
    call vga_print_ln

    call osview_init
    call pmm_init
    call pmm_alloc_init
    call sysres_init

    call keyboard_init
    cmp dword [fb_active], 0
    je .init_ui
    call mouse_init
.init_ui:
    call gui_init
    call brain_init
    call companion_init

    cmp dword [fb_active], 0
    je .text_ui

    mov esi, ready
    call gui_log_line
    jmp .post_dev

.text_ui:
    mov al, COLOR_DIM_GREEN
    call vga_set_color
    mov esi, ready
    call vga_print_ln
    call vga_print_ln

.post_dev:
    call pit_init
    mov dword [timer_ticks], 0
    sti

.shell:
    cmp dword [fb_active], 0
    je .text_shell
.gui_loop:
    call ps2_poll
    call keyboard_poll
    test al, al
    jz .gui_no_key
    mov bl, al
    mov al, bl
    call gui_handle_key
    call gui_poll
    call companion_poll
    call brain_step
    hlt
    jmp .gui_loop

.gui_no_key:
    call gui_poll
    call companion_poll
    call brain_step
    hlt
    jmp .gui_loop

.text_shell:
    mov al, COLOR_DARKGREEN
    call vga_set_color
    mov esi, prompt
    call vga_print
.input_loop:
    sti
    call companion_poll
    call ps2_poll
    call keyboard_poll
    test al, al
    jnz .got_key
    call brain_step
    hlt
    jmp .input_loop
.got_key:
    cmp al, 8
    je .backspace
    cmp al, 10
    je .newline
    cmp al, 27
    je .shell
    call vga_putchar
    jmp .input_loop
.backspace:
    mov al, 8
    call vga_putchar
    mov al, ' '
    call vga_putchar
    mov al, 8
    call vga_putchar
    jmp .input_loop
.newline:
    mov al, 10
    call vga_putchar
    jmp .shell

extern gui_dirty

isr_handler:
    mov eax, [esp + 4]
    mov edx, [esp + 8]

    cmp eax, INT_INVALID_OPCODE
    je .invalid_opcode
    cmp eax, INT_GENERAL_PROTECTION
    je .general_protection
    cmp eax, INT_PAGE_FAULT
    je .page_fault
    cmp eax, INT_IRQ0 + IRQ_TIMER
    je .timer
    cmp eax, INT_IRQ0 + IRQ_KEYBOARD
    je .keyboard
    cmp eax, INT_IRQ0 + IRQ_MOUSE
    je .mouse

    push eax
    mov al, COLOR_RED
    call vga_set_color
    mov esi, unknown
    call vga_print
    pop eax
    call print_dec
    mov al, 10
    call vga_putchar
    jmp .done

.invalid_opcode:
    call invalid_opcode_handler

.general_protection:
    mov ecx, [esp + 16]
    mov ebx, [esp + 12]
    mov edx, [esp + 8]
    push ecx
    push ebx
    push edx
    call general_protection_handler

.page_fault:
    push edx
    call page_fault_handler

.timer:
    push eax
    push edx
    inc dword [timer_ticks]
    mov eax, [timer_ticks]
    xor edx, edx
    mov ecx, RMGR_PERIODIC_INTERVAL
    div ecx
    test edx, edx
    jnz .timer_done
    call rmgr_periodic_tick
.timer_done:
    pop edx
    pop eax
    jmp .done

.keyboard:
    inc dword [rmgr_irq_kbd_count]
.kbd_irq_drain:
    in al, MOUSE_PORT_STATUS
    test al, 1
    jz .done
    test al, MOUSE_STATUS_AUX
    jnz .done
    in al, MOUSE_PORT_DATA
    call keyboard_scancode
    jmp .kbd_irq_drain

.mouse:
    inc dword [rmgr_irq_mouse_count]
    in al, MOUSE_PORT_STATUS
    test al, 1
    jz .done
    test al, MOUSE_STATUS_AUX
    jz .done
    in al, MOUSE_PORT_DATA
    call mouse_scancode
    jmp .done

.done:
    cmp dword [irq_vector], INT_IRQ0
    jl .ret
    call pic_send_eoi
.ret:
    ret

print_hex32:
    push eax
    push ebx
    push ecx
    push edx
    mov ecx, 8
    mov ebx, hex_digits
.ph_loop:
    mov edx, eax
    shr edx, 28
    and edx, 0x0F
    mov dl, [ebx + edx]
    push eax
    mov al, dl
    call vga_putchar
    pop eax
    shl eax, 4
    dec ecx
    jnz .ph_loop
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

print_dec:
    push ebx
    push ecx
    push edx
    mov ebx, 10
    xor ecx, ecx
.split:
    xor edx, edx
    div ebx
    push edx
    inc ecx
    test eax, eax
    jnz .split
.emit:
    pop eax
    add al, '0'
    call vga_putchar
    loop .emit
    pop edx
    pop ecx
    pop ebx
    ret

section .bss
align 4
global timer_ticks
timer_ticks:
    resd 1
