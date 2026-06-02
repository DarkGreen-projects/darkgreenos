; DarkgreenOS - page fault handler (#PF, vector 14)

%include "constants.inc"

extern vga_print
extern vga_print_ln
extern vga_set_color
extern print_hex32
extern serial_writeln
extern rmgr_begin_action
extern rmgr_end_action

section .data
pf_title:   db "[#PF] Page fault!", 0
pf_cr2:     db "  CR2 (fault addr): 0x", 0
pf_code:    db "  Error code:       0x", 0
pf_hint:    db "  (bit0: present  bit1: write  bit2: user)", 0
pf_serial:  db "[#PF] CR2=", 0

section .text
global page_fault_handler

; page_fault_handler(error_code) — does not return
page_fault_handler:
    push eax
    mov eax, RMGR_ACT_PAGE_FAULT
    call rmgr_begin_action
    call rmgr_end_action
    pop eax
    push esi
    mov esi, pf_serial
    call serial_writeln
    pop esi
    mov al, COLOR_RED
    call vga_set_color
    mov esi, pf_title
    call vga_print_ln

    mov esi, pf_cr2
    call vga_print
    mov eax, cr2
    call print_hex32
    call vga_print_ln

    mov esi, pf_code
    call vga_print
    mov eax, [esp + 4]
    call print_hex32
    call vga_print_ln

    mov al, COLOR_DIM_GREEN
    call vga_set_color
    mov esi, pf_hint
    call vga_print_ln

    cli
.halt:
    hlt
    jmp .halt
