; DarkgreenOS - VGA text mode driver

%include "constants.inc"

section .bss
align 4
global vga_cursor_x
global vga_cursor_y
vga_cursor_x: resd 1
vga_cursor_y: resd 1
current_color: resb 1

section .text
global vga_init
global vga_clear
global vga_putchar
global vga_print
global vga_print_ln
global vga_set_color

vga_init:
    mov dword [vga_cursor_x], 0
    mov dword [vga_cursor_y], 0
    mov byte [current_color], COLOR_DARKGREEN
    ret

vga_set_color:
    mov [current_color], al
    ret

vga_clear:
    push edi
    push ecx
    mov edi, VGA_MEM
    mov ecx, VGA_WIDTH * VGA_HEIGHT
    mov al, ' '
    mov ah, [current_color]
    rep stosw
    mov dword [vga_cursor_x], 0
    mov dword [vga_cursor_y], 0
    pop ecx
    pop edi
    ret

vga_putchar:
    push ebx
    push edi
    cmp al, 10
    je .newline
    cmp al, 13
    je .done
    mov ebx, [vga_cursor_y]
    imul ebx, dword VGA_WIDTH
    add ebx, [vga_cursor_x]
    shl ebx, 1
    add ebx, VGA_MEM
    mov ah, [current_color]
    mov [ebx], ax
    inc dword [vga_cursor_x]
    mov eax, [vga_cursor_x]
    cmp eax, VGA_WIDTH
    jl .done
.newline:
    mov dword [vga_cursor_x], 0
    inc dword [vga_cursor_y]
    mov eax, [vga_cursor_y]
    cmp eax, VGA_HEIGHT
    jl .done
    call vga_scroll
.done:
    pop edi
    pop ebx
    ret

vga_scroll:
    push esi
    push edi
    push ecx
    mov esi, VGA_MEM + (VGA_WIDTH * 2)
    mov edi, VGA_MEM
    mov ecx, VGA_WIDTH * (VGA_HEIGHT - 1)
    rep movsw
    mov edi, VGA_MEM + (VGA_WIDTH * (VGA_HEIGHT - 1) * 2)
    mov ecx, VGA_WIDTH
    mov al, ' '
    mov ah, [current_color]
    rep stosw
    mov dword [vga_cursor_y], VGA_HEIGHT - 1
    pop ecx
    pop edi
    pop esi
    ret

vga_print:
    push esi
.loop:
    lodsb
    test al, al
    jz .done
    call vga_putchar
    jmp .loop
.done:
    pop esi
    ret

vga_print_ln:
    call vga_print
    mov al, 10
    call vga_putchar
    ret
