; DarkgreenOS - general protection fault handler (#GP, vector 13)

%include "constants.inc"

extern vga_print
extern vga_print_ln
extern vga_set_color
extern print_hex32
extern serial_writeln
extern rmgr_begin_action
extern rmgr_end_action

section .data
gp_title:   db "[#GP] General protection fault!", 0
gp_eip:     db "  EIP:              0x", 0
gp_cs:      db "  CS:               0x", 0
gp_code:    db "  Error code:       0x", 0
gp_hint:    db "  (low EIP = bad iret/stack; check kernel stack)", 0
gp_serial:  db "[#GP] audit registrato", 0

section .text
global general_protection_handler

; general_protection_handler(error_code, fault_eip, fault_cs) — does not return
general_protection_handler:
    push eax
    mov eax, RMGR_ACT_GPF
    call rmgr_begin_action
    call rmgr_end_action
    pop eax
    push esi
    mov esi, gp_serial
    call serial_writeln
    pop esi
    mov al, COLOR_RED
    call vga_set_color
    mov esi, gp_title
    call vga_print_ln

    mov esi, gp_eip
    call vga_print
    mov eax, [esp + 8]
    call print_hex32
    call vga_print_ln

    mov esi, gp_cs
    call vga_print
    mov eax, [esp + 12]
    call print_hex32
    call vga_print_ln

    mov esi, gp_code
    call vga_print
    mov eax, [esp + 4]
    call print_hex32
    call vga_print_ln

    mov al, COLOR_DIM_GREEN
    call vga_set_color
    mov esi, gp_hint
    call vga_print_ln

    cli
.halt:
    hlt
    jmp .halt
