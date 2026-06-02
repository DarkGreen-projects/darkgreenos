; DarkgreenOS - linear framebuffer (Multiboot 2)

%include "constants.inc"

extern ptr_in_identity_map
extern sysres_set_fb

section .bss
align 4
global fb_addr
global fb_width
global fb_height
global fb_pitch
global fb_bpp
global fb_active
fb_addr:    resd 1
fb_width:   resd 1
fb_height:  resd 1
fb_pitch:   resd 1
fb_bpp:     resd 1
fb_active:  resd 1

section .text
global fb_init_from_mb2
global fb_put_pixel
global fb_xor_pixel
global fb_fill_rect
global fb_clear

fb_init_from_mb2:
    push eax
    mov eax, [esp + 8]
    call ptr_in_identity_map
    test al, al
    jz .no
    mov eax, [esp + 8]
    mov [fb_addr], eax
    mov eax, [esp + 12]
    mov [fb_width], eax
    mov eax, [esp + 16]
    mov [fb_height], eax
    mov eax, [esp + 20]
    mov [fb_pitch], eax
    mov eax, [esp + 24]
    mov [fb_bpp], eax
    mov dword [fb_active], 1
    call sysres_set_fb
    pop eax
    ret
.no:
    mov dword [fb_active], 0
    pop eax
    ret

fb_clear:
    cmp dword [fb_active], 0
    je .out
    push FB_COL_BG
    push dword [fb_height]
    push dword [fb_width]
    push 0
    push 0
    call fb_fill_rect
    add esp, 20
.out:
    ret

; fb_fill_rect(x, y, w, h, color) — cdecl stack args
fb_fill_rect:
    push ebp
    mov ebp, esp
    push esi
    push edi
    push ebx
    push ecx
    cmp dword [fb_active], 0
    je .out
    mov esi, [ebp + 12]
    mov ecx, [ebp + 20]
.yloop:
    jecxz .out
    mov edi, [ebp + 8]
    mov ebx, [ebp + 16]
.xloop:
    test ebx, ebx
    jz .ynext
    push dword [ebp + 24]
    push esi
    push edi
    call fb_put_pixel
    add esp, 12
    inc edi
    dec ebx
    jnz .xloop
.ynext:
    inc esi
    dec ecx
    jmp .yloop
.out:
    pop ecx
    pop ebx
    pop edi
    pop esi
    pop ebp
    ret

; fb_put_pixel(x, y, color)
fb_put_pixel:
    push ebx
    push ecx
    push edx
    cmp dword [fb_active], 0
    je .out
    mov eax, [esp + 16]
    mov ebx, [esp + 20]
    cmp eax, [fb_width]
    jae .out
    cmp ebx, [fb_height]
    jae .out
    imul ebx, [fb_pitch]
    shl eax, 2
    add ebx, eax
    add ebx, [fb_addr]
    mov eax, [esp + 24]
    mov [ebx], eax
.out:
    pop edx
    pop ecx
    pop ebx
    ret

; fb_xor_pixel(x, y, color) — software cursor helper
fb_xor_pixel:
    push ebx
    push ecx
    push edx
    cmp dword [fb_active], 0
    je .out
    mov eax, [esp + 16]
    mov ebx, [esp + 20]
    cmp eax, [fb_width]
    jae .out
    cmp ebx, [fb_height]
    jae .out
    imul ebx, [fb_pitch]
    shl eax, 2
    add ebx, eax
    add ebx, [fb_addr]
    mov eax, [esp + 24]
    xor [ebx], eax
.out:
    pop edx
    pop ecx
    pop ebx
    ret
