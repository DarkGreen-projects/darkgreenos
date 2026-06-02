; DarkgreenOS - PS/2 mouse (IRQ 12)

%include "constants.inc"

extern fb_width
extern fb_height
extern io_wait
extern keyboard_scancode
extern keyboard_clear_buffer
extern ps2_poll
extern rmgr_irq_mouse_count
extern timer_ticks

; ps2_is_mouse_data_byte(al=port byte) -> al=1 mouse, 0 keyboard
global ps2_is_mouse_data_byte
global mouse_suppress_keys_until

%define MOUSE_KEY_SUPPRESS_TICKS  4

section .bss
mouse_suppress_keys_until: resd 1
global mouse_x
global mouse_y
global mouse_buttons
global mouse_wheel_delta
global mouse_packet_byte
global mouse_packet_idx
mouse_x:            resd 1
mouse_y:            resd 1
mouse_buttons:      resd 1
mouse_wheel_delta:  resd 1
mouse_packet_byte:  resb 4
mouse_packet_idx:   resd 1
mouse_packet_len:   resd 1

section .text
global mouse_init
global mouse_scancode
global mouse_poll

mouse_wait_write:
    in al, MOUSE_PORT_STATUS
    test al, 2
    jnz mouse_wait_write
    ret

mouse_wait_read:
    in al, MOUSE_PORT_STATUS
    test al, 1
    jz mouse_wait_read
    ret

mouse_send_byte:
    call mouse_wait_write
    mov al, 0xD4
    out MOUSE_PORT_STATUS, al
    call mouse_wait_write
    mov al, [esp + 4]
    out MOUSE_PORT_DATA, al
    ret

mouse_init:
    push eax
    mov dword [mouse_suppress_keys_until], 0
    mov eax, [fb_width]
    shr eax, 1
    mov [mouse_x], eax
    mov eax, [fb_height]
    shr eax, 1
    mov [mouse_y], eax
    mov dword [mouse_buttons], 0
    mov dword [mouse_wheel_delta], 0
    mov dword [mouse_packet_idx], 0
    mov dword [mouse_packet_len], 3

    ; Enable auxiliary port only — do not rewrite i8042 config (keyboard_init owns it)
    call mouse_wait_write
    mov al, 0xA8
    out MOUSE_PORT_STATUS, al

    mov al, 0xF6
    push eax
    call mouse_send_byte
    add esp, 4
    call mouse_wait_read
    in al, MOUSE_PORT_DATA

    mov al, 0xF4
    push eax
    call mouse_send_byte
    add esp, 4
    call mouse_wait_read
    in al, MOUSE_PORT_DATA
    pop eax
    ret

; IRQ/poll: al = data byte from port 0x60 (caller must verify AUX for new packets)
mouse_scancode:
    movzx ecx, byte [mouse_packet_idx]
    test ecx, ecx
    jnz .store
    ; First byte of a mouse packet must have bit 3 set (sync).
    test al, 0x08
    jz .done
.store:
    mov [mouse_packet_byte + ecx], al
    inc dword [mouse_packet_idx]
    mov eax, [mouse_packet_len]
    cmp [mouse_packet_idx], eax
    jl .done
    mov dword [mouse_packet_idx], 0
    mov al, [mouse_packet_byte]
    movzx ebx, al
    and ebx, 7
    mov [mouse_buttons], ebx
    movsx eax, byte [mouse_packet_byte + 1]
    mov ebx, eax
    add [mouse_x], eax
    movsx eax, byte [mouse_packet_byte + 2]
    or ebx, eax
    sub [mouse_y], eax
.no_kbd_flush:
    cmp dword [mouse_packet_len], 4
    jne .clip
    movsx eax, byte [mouse_packet_byte + 3]
    add [mouse_wheel_delta], eax
.clip:
    mov eax, [mouse_x]
    test eax, eax
    jns .xok
    mov dword [mouse_x], 0
.xok:
    mov eax, [mouse_x]
    cmp eax, [fb_width]
    jl .yclip
    mov eax, [fb_width]
    dec eax
    mov [mouse_x], eax
.yclip:
    mov eax, [mouse_y]
    test eax, eax
    jns .yok
    mov dword [mouse_y], 0
.yok:
    mov eax, [mouse_y]
    cmp eax, [fb_height]
    jl .done
    mov eax, [fb_height]
    dec eax
    mov [mouse_y], eax
.done:
    ret

; Block GUI/keyboard text for a few ticks after each mouse packet (movement bytes mimic scancodes).
mouse_suppress_keys_bump:
    push eax
    push ebx
    mov eax, [timer_ticks]
    add eax, MOUSE_KEY_SUPPRESS_TICKS
    mov ebx, [mouse_suppress_keys_until]
    cmp eax, ebx
    jbe .out
    mov [mouse_suppress_keys_until], eax
.out:
    pop ebx
    pop eax
    ret

; Mid-packet or AUX = mouse; else only 0x08-style sync (not space/E0/shift prefixes).
ps2_is_mouse_data_byte:
    cmp dword [mouse_packet_idx], 0
    jne .is_mouse
    test al, 0x08
    jz .is_kbd
    cmp al, 0x39
    je .is_kbd
    cmp al, 0xE0
    je .is_kbd
    cmp al, 0xE1
    je .is_kbd
    cmp al, 0xF0
    je .is_kbd
    cmp al, 0x2A
    je .is_kbd
    cmp al, 0x36
    je .is_kbd
.is_mouse:
    mov al, 1
    ret
.is_kbd:
    xor al, al
    ret

; mouse_poll — drain PS/2 (implementation in keyboard.asm)
mouse_poll:
    jmp ps2_poll
