; DarkgreenOS - port I/O helpers

%include "constants.inc"

section .bss
global irq_vector
irq_vector: resd 1

section .text
global io_wait
global pic_send_eoi

io_wait:
    push eax
    in al, 0x80
    pop eax
    ret

pic_send_eoi:
    push eax
    mov eax, [irq_vector]
    cmp eax, 40
    jl .master_only
    mov al, PIC_EOI
    out PIC2_COMMAND, al
.master_only:
    mov al, PIC_EOI
    out PIC1_COMMAND, al
    pop eax
    ret
