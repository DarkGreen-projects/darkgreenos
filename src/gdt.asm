; DarkgreenOS - Global Descriptor Table (flat protected mode + user + TSS)

%include "constants.inc"

%define TSS_BYTES                 104

section .bss
align 16
global tss_entry
tss_entry:
    resb 104

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

gdt_user_code:
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 11111010b
    db 11001111b
    db 0x00

gdt_user_data:
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 11110010b
    db 11001111b
    db 0x00

gdt_tss:
    dw TSS_BYTES - 1
    dw 0
    db 0
    db 10001001b
    db 0
    db 0

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
    mov eax, tss_entry
    mov word [gdt_tss + 2], ax
    shr eax, 16
    mov byte [gdt_tss + 4], al
    xor eax, eax
    mov byte [gdt_tss + 7], al
    mov ax, GDT_TSS_SEG
    ltr ax
    ret

; gdt_set_tss_esp0(eax=kernel stack top for ring-3 interrupts)
global gdt_set_tss_esp0
gdt_set_tss_esp0:
    mov [tss_entry + 4], eax
    ret
