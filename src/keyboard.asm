; DarkgreenOS - PS/2 keyboard (set 1 + set 2 fallback, polling + IRQ)

%include "constants.inc"

%define PS2_WAIT_ITERS           250000

extern rmgr_irq_kbd_count
extern mouse_packet_idx
extern mouse_scancode

section .bss
global key_buffer
global key_buffer_head
global key_buffer_tail
global keyboard_last_scancode
global keyboard_last_char
global keyboard_rx_count
key_buffer:       resb 128
key_buffer_head:  resd 1
key_buffer_tail:  resd 1
key_down:         resb 128
shift_down:       resd 1
kbd_e0_prefix:    resb 1
keyboard_last_scancode: resb 1
keyboard_last_char:     resb 1
keyboard_rx_count:      resd 1

section .text
global keyboard_init
global keyboard_poll
global keyboard_read
global keyboard_clear_buffer
global keyboard_port_poll
global keyboard_may_type
global keyboard_scancode

keyboard_wait_write:
    push ecx
    mov ecx, PS2_WAIT_ITERS
.kww:
    in al, MOUSE_PORT_STATUS
    test al, 2
    jz .kww_out
    dec ecx
    jnz .kww
.kww_out:
    pop ecx
    ret

keyboard_wait_read:
    push ecx
    mov ecx, PS2_WAIT_ITERS
.kwr:
    in al, MOUSE_PORT_STATUS
    test al, 1
    jnz .kwr_out
    dec ecx
    jnz .kwr
.kwr_out:
    pop ecx
    ret

keyboard_drain_port:
    push eax
.kd:
    in al, MOUSE_PORT_STATUS
    test al, 1
    jz .kd_done
    in al, MOUSE_PORT_DATA
    jmp .kd
.kd_done:
    pop eax
    ret

keyboard_init:
    push eax
    push edi
    push ecx
    mov dword [key_buffer_head], 0
    mov dword [key_buffer_tail], 0
    mov dword [shift_down], 0
    mov dword [keyboard_rx_count], 0
    mov byte [kbd_e0_prefix], 0
    mov edi, key_down
    mov ecx, 128
    xor al, al
    rep stosb
    call keyboard_drain_port
    call keyboard_wait_write
    mov al, 0x20
    out MOUSE_PORT_STATUS, al
    call keyboard_wait_read
    in al, MOUSE_PORT_DATA
    or al, 0x41
    and al, 0xCF
    mov ah, al
    call keyboard_wait_write
    mov al, 0x60
    out MOUSE_PORT_STATUS, al
    call keyboard_wait_write
    mov al, ah
    out MOUSE_PORT_DATA, al
    call keyboard_wait_write
    mov al, 0xAE
    out MOUSE_PORT_STATUS, al
    call keyboard_drain_port
    pop ecx
    pop edi
    pop eax
    ret

; Drain port 0x60: non-AUX -> keyboard, AUX -> mouse (if enabled)
global ps2_poll
ps2_poll:
    push ebx
    push edx
.pp:
    in al, MOUSE_PORT_STATUS
    test al, 1
    jz .pp_done
    mov dl, al
    in al, MOUSE_PORT_DATA
    mov ah, al
    test dl, MOUSE_STATUS_AUX
    jnz .pp_mouse
    cmp dword [mouse_packet_idx], 0
    je .pp_kbd
    mov dword [mouse_packet_idx], 0
.pp_kbd:
    mov al, ah
    call keyboard_scancode
    jmp .pp
.pp_mouse:
    mov al, ah
    call mouse_scancode
    jmp .pp
.pp_done:
    pop edx
    pop ebx
    ret

keyboard_scancode:
    push ebx
    push edx
    mov dl, al
    inc dword [keyboard_rx_count]
    mov [keyboard_last_scancode], dl
    cmp dword [mouse_packet_idx], 0
    je .proc
    mov dword [mouse_packet_idx], 0
.proc:
    cmp dl, 0xE0
    jne .not_e0
    mov byte [kbd_e0_prefix], 1
    jmp .done
.not_e0:
    cmp byte [kbd_e0_prefix], 0
    je .normal
    mov byte [kbd_e0_prefix], 0
.normal:
    cmp dl, 0xE1
    je .done
    cmp dl, 0xF0
    je .done
    cmp dl, 0xFA
    je .done
    cmp dl, 0xAA
    je .done
    test dl, 0x80
    jnz .release
    cmp dl, 0x2A
    je .shift_press
    cmp dl, 0x36
    je .shift_press
    cmp dl, 128
    jae .done
    movzx eax, dl
    mov byte [key_down + eax], 1
    mov bl, [scancode_map + eax]
    cmp dword [shift_down], 0
    je .map1
    mov bl, [scancode_map_shift + eax]
.map1:
    test bl, bl
    jnz .enqueue
    mov bl, [scancode_map_set2 + eax]
.enqueue:
    test bl, bl
    jz .done
    mov [keyboard_last_char], bl
    mov eax, [key_buffer_head]
    mov ecx, eax
    inc ecx
    and ecx, 127
    cmp ecx, [key_buffer_tail]
    je .done
    mov [key_buffer + eax], bl
    inc eax
    and eax, 127
    mov [key_buffer_head], eax
    jmp .done
.shift_press:
    mov dword [shift_down], 1
    jmp .done
.release:
    movzx eax, dl
    and eax, 0x7F
    cmp eax, 0x2A
    je .shift_release
    cmp eax, 0x36
    je .shift_release
    cmp eax, 128
    jae .done
    mov byte [key_down + eax], 0
    jmp .done
.shift_release:
    mov dword [shift_down], 0
.done:
    pop edx
    pop ebx
    ret

keyboard_may_type:
    mov al, 1
    ret

keyboard_clear_buffer:
    mov eax, [key_buffer_head]
    mov [key_buffer_tail], eax
    ret

keyboard_port_poll:
    jmp ps2_poll

keyboard_poll:
    push ebx
    call ps2_poll
    mov eax, [key_buffer_tail]
    cmp eax, [key_buffer_head]
    je .empty
    mov bl, [key_buffer + eax]
    inc eax
    and eax, 127
    mov [key_buffer_tail], eax
    mov al, bl
    pop ebx
    ret
.empty:
    xor al, al
    pop ebx
    ret

keyboard_read:
    hlt
    call keyboard_poll
    test al, al
    jz keyboard_read
    ret

section .rodata
scancode_map:
    db 0, 27, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 8
    db 9, 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', 10
    db 0, 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', 39, '`', 0
    db 0, '\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0, '*'
    db ' ', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

scancode_map_shift:
    db 0, 27, '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+', 8
    db 9, 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', 10
    db 0, 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', '"', '~', 0
    db 0, '|', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?', 0, '*'
    db ' ', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

; Set 2 make codes (when controller translation is off)
scancode_map_set2:
    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 0, 0, 0, 0, 0, 113, 0, 0, 0, 0, 122, 0, 97, 119, 0, 115
    db 0, 99, 120, 100, 101, 0, 0, 0, 0, 32, 118, 102, 116, 114, 0, 0
    db 0, 110, 98, 104, 103, 121, 0, 0, 0, 0, 109, 106, 117, 0, 0, 0
    db 0, 0, 107, 105, 111, 0, 0, 0, 0, 0, 0, 108, 0, 112, 0, 0
    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10, 0, 0, 0, 0, 0
    db 0, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
