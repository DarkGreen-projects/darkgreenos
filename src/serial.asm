; DarkgreenOS - COM1 UART (NS16550) for Companion link

%include "constants.inc"

section .text
global serial_init
global serial_tx
global serial_rx_ready
global serial_rx
global serial_write
global serial_writeln

serial_init:
    ; Disable interrupts on UART
    mov dx, SERIAL_COM1 + 1
    mov al, 0
    out dx, al

    ; DLAB on -> set baud divisor 3 = 38400
    mov dx, SERIAL_LCR
    mov al, 0x80
    out dx, al
    mov dx, SERIAL_COM1
    mov al, 3
    out dx, al
    mov dx, SERIAL_COM1 + 1
    mov al, 0
    out dx, al

    ; 8N1, DLAB off
    mov dx, SERIAL_LCR
    mov al, 0x03
    out dx, al

    ; FIFO on, clear
    mov dx, SERIAL_COM1 + 2
    mov al, 0xC7
    out dx, al
    ret

serial_tx:
    push edx
    push eax
.wait:
    mov dx, SERIAL_LSR
    in al, dx
    test al, SERIAL_LSR_TX_EMPTY
    jz .wait
    pop eax
    mov dx, SERIAL_COM1
    out dx, al
    pop edx
    ret

serial_rx_ready:
    mov dx, SERIAL_LSR
    in al, dx
    test al, SERIAL_LSR_DATA_READY
    jz .no
    mov al, 1
    ret
.no:
    xor al, al
    ret

serial_rx:
    mov dx, SERIAL_COM1
    in al, dx
    ret

serial_write:
    push esi
.loop:
    lodsb
    test al, al
    jz .done
    call serial_tx
    jmp .loop
.done:
    pop esi
    ret

serial_writeln:
    call serial_write
    push eax
    mov al, 13
    call serial_tx
    mov al, 10
    call serial_tx
    pop eax
    ret
