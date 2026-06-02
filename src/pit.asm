; DarkgreenOS - 8253/8254 PIT (channel 0 -> IRQ0)

%include "constants.inc"
%include "macros.inc"

extern io_wait

section .text
global pit_init

; ~100 Hz (1193182 / 11932)
%define PIT_DIVISOR 11932

pit_init:
    mov al, 0x36
    out 0x43, al
    call io_wait
    mov ax, PIT_DIVISOR
    out 0x40, al
    call io_wait
    mov al, ah
    out 0x40, al
    call io_wait
    ret
