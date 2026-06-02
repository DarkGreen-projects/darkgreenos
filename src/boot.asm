; DarkgreenOS - Multiboot 2 entry (framebuffer via GRUB)

%include "constants.inc"

%define MB2_FB_TAG_SIZE           20
; GRUB find_header: magic + arch + header_length + checksum == 0 (see scripts/mb2_checksum.py)
%define MB2_HEADER_CHECKSUM       0x17ADAEFA

section .multiboot
align 8
header_start:
    dd MB2_HEADER_MAGIC
    dd MB2_ARCH_I386
    dd header_end - header_start
    dd MB2_HEADER_CHECKSUM

align 8
    dw MB2_TAG_FRAMEBUFFER
    dw 0
    dd MB2_FB_TAG_SIZE
    dd FB_DEFAULT_WIDTH
    dd FB_DEFAULT_HEIGHT
    dd FB_DEFAULT_BPP

align 8
    dw MB2_TAG_END
    dw 0
    dd 8
header_end:

section .text
global _start
extern kernel_main
extern stack_top

_start:
    mov esp, stack_top
    push ebx
    push eax
    call kernel_main
    cli
.hang:
    hlt
    jmp .hang
