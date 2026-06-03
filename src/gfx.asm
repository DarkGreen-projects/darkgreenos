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
global gfx_is_printable_char

extern font8_table
extern font8_it_table

section .text
; gfx_draw_latin1_it(al=char) -> esi=glyph or 0
gfx_draw_latin1_it:
    push ebx
    xor ebx, ebx
    cmp al, 0xA3
    je .found
    inc ebx
    cmp al, 0xA7
    je .found
    inc ebx
    cmp al, 0xE0
    je .found
    inc ebx
    cmp al, 0xE8
    je .found
    inc ebx
    cmp al, 0xE9
    je .found
    inc ebx
    cmp al, 0xEC
    je .found
    inc ebx
    cmp al, 0xF2
    je .found
    inc ebx
    cmp al, 0xF9
    je .found
    inc ebx
    cmp al, 0xE7
    je .found
    xor esi, esi
    jmp .out
.found:
    shl ebx, 3
    lea esi, [font8_it_table + ebx]
.out:
    pop ebx
    ret

; gfx_is_printable_char(al) -> al=1 drawable, al=0 not
gfx_is_printable_char:
    push ebx
    push esi
    cmp al, 32
    jb .no
    cmp al, 127
    jb .yes
    call gfx_draw_latin1_it
    test esi, esi
    jz .no
.yes:
    mov al, 1
    jmp .done
.no:
    xor al, al
.done:
    pop esi
    pop ebx
    ret

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
    jb .ascii
    call gfx_draw_latin1_it
    test esi, esi
    jz .out
    jmp .draw_glyph
.ascii:
    sub al, 32
    movzx eax, al
    shl eax, 3
    lea esi, [font8_table + eax]
.draw_glyph:
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
