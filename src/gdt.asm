; DarkgreenOS - Global Descriptor Table (flat protected mode)

%include "constants.inc"

section .data
align 8
gdt_start:
    dq 0

gdt_code:
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 10011010b
    db 11001111b
    db 0x00

gdt_data:
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 10010010b
    db 11001111b
    db 0x00

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

section .text
global gdt_load

gdt_load:
    lgdt [gdt_descriptor]
    jmp GDT_CODE_SEG:.flush
.flush:
    mov ax, GDT_DATA_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    ret
