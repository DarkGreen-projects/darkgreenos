; DarkgreenOS - framebuffer text and primitives

%include "constants.inc"

extern fb_active
extern fb_width
extern fb_height
extern fb_put_pixel
extern fb_fill_rect
extern font8_table

section .text
global gfx_draw_char
global gfx_draw_string
global gfx_draw_string_at

; gfx_draw_char(x, y, char, color)
gfx_draw_char:
    push ebp
    mov ebp, esp
    push ebx
    push ecx
    push edx
    push esi
    push edi
    cmp dword [fb_active], 0
    je .out
    movzx eax, byte [ebp + 16]
    cmp al, 32
    jb .out
    cmp al, 127
    jae .out
    sub al, 32
    movzx eax, al
    shl eax, 3
    lea esi, [font8_table + eax]
    mov edx, [ebp + 12]
    xor ebx, ebx
.row:
    cmp ebx, 8
    jge .out
    mov ecx, [ebp + 8]
    mov al, [esi + ebx]
    xor edi, edi
.bit:
    cmp edi, 8
    jge .next_row
    test al, 0x80
    jz .skip
    push eax
    push dword [ebp + 20]
    push edx
    push ecx
    call fb_put_pixel
    add esp, 12
    pop eax
.skip:
    shl al, 1
    inc ecx
    inc edi
    jmp .bit
.next_row:
    inc edx
    inc ebx
    jmp .row
.out:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop ebp
    ret

; gfx_draw_string_at(text, x, y, color) — push order: color, y, x, text
gfx_draw_string_at:
    push ebp
    mov ebp, esp
    push ebx
    push ecx
    push edx
    push esi
    mov esi, [ebp + 8]
    mov ebx, [ebp + 12]
    mov ecx, [ebp + 16]
    mov edx, [ebp + 20]
.d:
    lodsb
    test al, al
    jz .done
    push edx
    movzx eax, al
    push eax
    push ecx
    push ebx
    call gfx_draw_char
    add esp, 16
    add ebx, 8
    jmp .d
.done:
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop ebp
    ret

; gfx_draw_string(esi, color) — top-left margin
gfx_draw_string:
    push ebx
    push ecx
    mov ebx, GUI_MARGIN
    mov ecx, GUI_MARGIN
    push dword [esp + 12]
    push ecx
    push ebx
    push esi
    call gfx_draw_string_at
    add esp, 16
    pop ecx
    pop ebx
    ret
