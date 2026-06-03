; DarkgreenOS - page fault handler (#PF, vector 14)

%include "constants.inc"

extern vga_print
extern vga_print_ln
extern vga_set_color
extern print_hex32
extern serial_writeln
extern rmgr_begin_action
extern rmgr_end_action
extern scheduler_fault_kill
extern err_ring_push

section .data
pf_title:   db "[#PF] Page fault!", 0
pf_cr2:     db "  CR2 (fault addr): 0x", 0
pf_code:    db "  Error code:       0x", 0
pf_hint:    db "  (bit0: present  bit1: write  bit2: user)", 0
pf_recover: db "[#PF] RMGR recovery: task segnato dead", 0
pf_serial:  db "[#PF] CR2=", 0

section .text
global page_fault_handler

; page_fault_handler(error_code) — al=1 recovered, 0 halt
page_fault_handler:
    push eax
    mov eax, RMGR_ACT_PAGE_FAULT
    call rmgr_begin_action
    call rmgr_end_action
    pop eax
    test dword [esp + 4], 4
    jz .fatal
    push ecx
    push ebx
    mov eax, ERR_PF_USER
    mov ebx, [esp + 12]
    mov ecx, cr2
    call err_ring_push
    pop ebx
    pop ecx
    push esi
    mov esi, pf_recover
    call serial_writeln
    pop esi
    call scheduler_fault_kill
    mov al, 1
    ret
.fatal:
    push ecx
    push ebx
    mov eax, ERR_PF_KERNEL
    mov ebx, [esp + 12]
    mov ecx, cr2
    call err_ring_push
    pop ebx
    pop ecx
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
