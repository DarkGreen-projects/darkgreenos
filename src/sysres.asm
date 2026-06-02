; DarkgreenOS - system resource state for DarkMind / Companion

%include "constants.inc"

extern fb_width
extern fb_height
extern fb_bpp
extern fb_active
extern mouse_x
extern mouse_y
extern mouse_buttons
extern os_stat_ram_kb

section .bss
global sysres_ram_kb
global sysres_fb_w
global sysres_fb_h
global sysres_fb_bpp
global sysres_fb_on
global sysres_mouse_x
global sysres_mouse_y
global sysres_mouse_btn
global sysres_gui_on
sysres_ram_kb:      resd 1
sysres_fb_w:        resd 1
sysres_fb_h:        resd 1
sysres_fb_bpp:      resd 1
sysres_fb_on:       resd 1
sysres_mouse_x:     resd 1
sysres_mouse_y:     resd 1
sysres_mouse_btn:   resd 1
sysres_gui_on:      resd 1

section .text
global sysres_init
global sysres_set_mem_kb
global sysres_set_fb
global sysres_sync_mouse
global sysres_append_ctx

sysres_init:
    mov eax, [os_stat_ram_kb]
    mov [sysres_ram_kb], eax
    xor eax, eax
    mov [sysres_fb_on], eax
    mov [sysres_gui_on], eax
    mov [sysres_mouse_x], eax
    mov [sysres_mouse_y], eax
    mov [sysres_mouse_btn], eax
    ret

sysres_set_mem_kb:
    mov eax, [esp + 4]
    mov [sysres_ram_kb], eax
    mov [os_stat_ram_kb], eax
    ret

sysres_set_fb:
    cmp dword [fb_active], 0
    je .off
    mov eax, [fb_width]
    mov [sysres_fb_w], eax
    mov eax, [fb_height]
    mov [sysres_fb_h], eax
    mov eax, [fb_bpp]
    mov [sysres_fb_bpp], eax
    mov dword [sysres_fb_on], 1
    ret
.off:
    mov dword [sysres_fb_on], 0
    ret

sysres_sync_mouse:
    mov eax, [mouse_x]
    mov [sysres_mouse_x], eax
    mov eax, [mouse_y]
    mov [sysres_mouse_y], eax
    mov eax, [mouse_buttons]
    mov [sysres_mouse_btn], eax
    ret

; sysres_append_ctx(edi) — append resource summary to buffer at edi (NUL-term)
sysres_append_ctx:
    push esi
    push eax
    mov esi, lbl_fb
    call strcat_edi
    mov eax, [sysres_fb_on]
    call append_dec_edi
    cmp dword [sysres_fb_on], 0
    je .skip_wh
    mov eax, [sysres_fb_w]
    call append_dec_edi
    mov esi, lbl_x
    call strcat_edi
    mov eax, [sysres_fb_h]
    call append_dec_edi
.skip_wh:
    mov esi, lbl_mouse
    call strcat_edi
    mov eax, [sysres_mouse_x]
    call append_dec_edi
    mov al, ','
    call stchar_edi
    mov eax, [sysres_mouse_y]
    call append_dec_edi
    mov esi, lbl_btn
    call strcat_edi
    mov eax, [sysres_mouse_btn]
    call append_dec_edi
    mov esi, lbl_gui
    call strcat_edi
    mov eax, [sysres_gui_on]
    call append_dec_edi
    mov esi, lbl_boot
    call strcat_edi
    mov esi, lbl_input
    call strcat_edi
    mov esi, lbl_model
    call strcat_edi
    mov esi, lbl_serial
    call strcat_edi
    cmp dword [sysres_gui_on], 0
    je .done
    mov esi, lbl_scene
    call strcat_edi
.done:
    pop eax
    pop esi
    ret

section .rodata
lbl_fb:     db " fb=", 0
lbl_x:      db "x", 0
lbl_mouse:  db " mouse=", 0
lbl_btn:    db " btn=", 0
lbl_gui:    db " gui=", 0
lbl_boot:   db " boot=grub_multiboot2", 0
lbl_input:  db " input=ps2_keyboard_polling,ps2_mouse_polling", 0
lbl_model:  db " model=none_orchestrator_only", 0
lbl_serial: db " serial=com1_companion", 0
lbl_scene:  db " scene=desktop(titlebar,left_resource_panel,right_chat_panel,statusbar,xor_cursor)", 0

section .text
strcat_edi:
    push eax
.se:
    mov al, [esi]
    test al, al
    jz .done
    mov [edi], al
    inc esi
    inc edi
    jmp .se
.done:
    pop eax
    ret

stchar_edi:
    mov [edi], al
    inc edi
    ret

append_dec_edi:
    push ebx
    push ecx
    push edx
    mov ebx, 10
    xor ecx, ecx
    test eax, eax
    jnz .split
    mov byte [edi], '0'
    inc edi
    jmp .done
.split:
    xor edx, edx
    div ebx
    push edx
    inc ecx
    test eax, eax
    jnz .split
.emit:
    pop eax
    add al, '0'
    mov [edi], al
    inc edi
    loop .emit
.done:
    pop edx
    pop ecx
    pop ebx
    ret
