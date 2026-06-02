; DarkgreenOS - invalid opcode handler (#UD, vector 6)

%include "constants.inc"

extern vga_print
extern vga_print_ln
extern vga_set_color
extern print_hex32

section .data
ud_title:   db "[#UD] Invalid opcode!", 0
ud_hint:    db "  (often code placed in .bss by mistake)", 0

section .text
global invalid_opcode_handler

; invalid_opcode_handler() — does not return
invalid_opcode_handler:
    mov al, COLOR_RED
    call vga_set_color
    mov esi, ud_title
    call vga_print_ln

    mov al, COLOR_DIM_GREEN
    call vga_set_color
    mov esi, ud_hint
    call vga_print_ln

    cli
.halt:
    hlt
    jmp .halt
