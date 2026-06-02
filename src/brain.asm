; DarkgreenOS - Internal Mind (kernel-resident inference + full OS context)
;
; Not a cloud LLM: on-device engine that reads live RAM/kernel state and
; produces answers. Designed to load real weights later (PMM + storage).

%include "constants.inc"

extern companion_name
extern companion_persona
extern vga_print
extern vga_print_ln
extern vga_set_color
extern print_dec
extern print_hex32
extern timer_ticks
extern os_stat_ram_kb
extern os_stat_regions
extern os_stat_kernel_bytes
extern os_stat_mapped_mb
extern mb_print_map
extern osview_print_kernel_map
extern osview_find
extern osview_dump
extern osview_scan_stats
extern sysres_sync_mouse
extern sysres_append_ctx
extern gui_log_line
extern gui_redraw
extern fb_active
extern kernel_start
extern kernel_end
extern tinylm_start
extern tinylm_step
extern rmgr_boot_init

global brain_init
global brain_refresh
global brain_think
global brain_step
global brain_ctx

section .bss
align 4
global brain_ctx
brain_ctx:
    resb BRAIN_CTX_SIZE
global brain_mood
brain_mood: resd 1
brain_query_ptr: resd 1
hidden:     resd 4
inp:        resd 4

section .data
lbl_brain_on:   db "[DarkMind] orchestratore risorse attivo - decisioni kernel su RAM/GUI/FB", 0
lbl_ctx:        db "  [context] ", 0
lbl_ram:        db "RAM_kb=", 0
lbl_reg:        db " regions=", 0
lbl_kern:       db " kernel_bytes=", 0
lbl_map:        db " mapped_mb=", 0
lbl_ticks:      db " ticks=", 0
lbl_ans:        db "  [mind] ", 0

section .rodata
; Tiny internal network weights (4 inputs -> 4 hidden -> 2 outputs)
; Inputs: ram_kb>>10, regions, kernel_kb, ticks&0xFF
brain_w_ih:
    dd 0x00010000, 0x00008000, 0x0000C000, 0x00004000
    dd 0x0000E000, 0x00006000, 0x00002000, 0x0000A000
    dd 0x00005000, 0x0000B000, 0x00003000, 0x0000D000
    dd 0x00007000, 0x00009000, 0x00001000, 0x0000F000
brain_w_ho:
    dd 0x00012000, 0x0000A000
    dd 0x0000B000, 0x0000C000
    dd 0x00009000, 0x0000D000
    dd 0x0000E000, 0x00008000

kw_mem:         db "mem", 0
kw_map:         db "map", 0
kw_dump:        db "dump", 0
kw_find:        db "find", 0
kw_file:        db "file", 0
kw_kernel:      db "kernel", 0
kw_scan:        db "scan", 0
kw_addr:        db "0x", 0
kw_gui:         db "gui", 0
kw_mouse:       db "mouse", 0
kw_screen:      db "screen", 0
kw_fb:          db "fb", 0
kw_ciao:        db "ciao", 0
kw_help:        db "help", 0
kw_aiuto:       db "aiuto", 0

reply_mem:      db "Vedo tutta la mappa fisica (mmap). Ecco le regioni:", 0
reply_file:     db "File=regioni kernel in RAM (.text .rodata .data .bss + moduli):", 0
reply_scan:     db "Scansione completa statistiche OS aggiornate.", 0
reply_gui:      db "Vedo il desktop: barra titolo, pannello risorse, chat, statusbar e cursore.", 0
reply_mouse:    db "Mouse: cursore XOR stabile, coordinate e pulsanti nel contesto sysres.", 0
reply_ciao:     db "Ciao, sono DarkMind. Scrivi una domanda o chiedi help.", 0
reply_help:     db "Comandi: gui, mouse, mem/map, files/kernel, scan. Se non capisco, te lo dico.", 0
reply_default:  db "Orchestratore risorse attivo: scrivi mem, scan o una domanda per il report numerico.", 0

section .text
brain_init:
    call rmgr_boot_init
    mov esi, lbl_brain_on
    call gui_log_line
    call brain_refresh
    ret

brain_refresh:
    pusha
    call osview_scan_stats
    mov edi, brain_ctx
    mov ecx, BRAIN_CTX_SIZE
    xor al, al
    rep stosb

    mov edi, brain_ctx
    mov esi, lbl_ram
    call strcat
    mov eax, [os_stat_ram_kb]
    call append_dec
    mov esi, lbl_reg
    call strcat
    mov eax, [os_stat_regions]
    call append_dec
    mov esi, lbl_kern
    call strcat
    mov eax, [os_stat_kernel_bytes]
    call append_dec
    mov esi, lbl_map
    call strcat
    mov eax, [os_stat_mapped_mb]
    call append_dec
    mov esi, lbl_ticks
    call strcat
    mov eax, [timer_ticks]
    call append_dec
    call sysres_sync_mouse
    mov edi, brain_ctx
.ctx_end:
    cmp byte [edi], 0
    je .ctx_ok
    inc edi
    jmp .ctx_end
.ctx_ok:
    call sysres_append_ctx
    call brain_infer
    popa
    ret

; brain_think(esi=query) - uses full OS visibility
brain_think:
    pusha
    mov [brain_query_ptr], esi
    call brain_refresh
    mov esi, [brain_query_ptr]
    call tinylm_start
    popa
    ret

brain_step:
    call tinylm_step
    ret

brain_say:
    push esi
    call gui_log_line
    cmp dword [fb_active], 0
    je .vga
    pop esi
    ret
.vga:
    mov al, COLOR_DARKGREEN
    call vga_set_color
    mov esi, lbl_ans
    call vga_print
    pop esi
    call vga_print_ln
    ret

brain_say_generic:
    pusha
    mov al, COLOR_DARKGREEN
    call vga_set_color
    mov esi, lbl_ans
    call vga_print
    mov esi, brain_ctx
    call vga_print
    mov al, ' '
    call vga_putchar
    mov eax, [brain_mood]
    cmp eax, 1
    je .calm
    cmp eax, 2
    je .alert
    mov esi, msg_active
    jmp .p
.calm:
    mov esi, msg_calm
    jmp .p
.alert:
    mov esi, msg_alert
.p:
    call gui_log_line
    cmp dword [fb_active], 0
    jne .gui_done
    call vga_print_ln
.gui_done:
    popa
    ret

msg_active: db "Stato: attivo. Chiedi: mem map, os files, find <txt>, dump 0xADDR", 0
msg_calm:   db "Stato: calmo. Ho letto tutta la RAM mappata.", 0
msg_alert:  db "Stato: allerta. Molti tick/eventi.", 0

brain_arg_after_space:
    push esi
.bas:
    lodsb
    test al, al
    jz .out
    cmp al, ' '
    je .found
    jmp .bas
.found:
    dec esi
.out:
    pop esi
    ret

str_contains:
    push esi
    push edi
.outer:
    mov al, [esi]
    test al, al
    jz .no
    push esi
    push edi
.inner:
    mov bl, [edi]
    test bl, bl
    jz .yes
    cmp al, bl
    jne .next
    inc esi
    inc edi
    mov al, [esi]
    jmp .inner
.next:
    pop edi
    pop esi
    inc esi
    jmp .outer
.yes:
    pop edi
    pop esi
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop edi
    pop esi
    ret

strcat:
    push esi
    push edi
    push eax
.seek:
    cmp byte [edi], 0
    je .c
    inc edi
    jmp .seek
.c:
    mov al, [esi]
    test al, al
    jz .done
    stosb
    inc esi
    jmp .c
.done:
    mov byte [edi], 0
    pop eax
    pop edi
    pop esi
    ret

append_dec:
    push ebx
    push ecx
    push edx
    push edi
    mov ebx, 10
    xor ecx, ecx
.s:
    xor edx, edx
    div ebx
    push edx
    inc ecx
    test eax, eax
    jnz .s
.e:
    pop eax
    add al, '0'
    stosb
    loop .e
    mov byte [edi], 0
    pop edi
    pop edx
    pop ecx
    pop ebx
    ret

extern vga_putchar

; Simple MLP -> brain_mood in [1..3]
global brain_infer
brain_infer:
    push ebx
    push ecx
    push edx
    push esi
    push edi

    xor eax, eax
    mov ebx, [os_stat_ram_kb]
    shr ebx, 10
    mov [inp + 0], ebx
    mov ebx, [os_stat_regions]
    mov [inp + 4], ebx
    mov ebx, [os_stat_kernel_bytes]
    shr ebx, 10
    mov [inp + 8], ebx
    mov ebx, [timer_ticks]
    and ebx, 0xFF
    mov [inp + 12], ebx

    xor edi, edi
    mov ecx, 4
    xor eax, eax
    push edi
    mov edi, hidden
    rep stosd
    pop edi
    xor ecx, ecx
.hloop:
    mov dword [hidden + ecx * 4], 0
    xor ebx, ebx
    mov edx, 4
.hacc:
    push eax
    push edx
    mov eax, ecx
    shl eax, 4
    add eax, ebx
    shl eax, 2
    add eax, brain_w_ih
    mov edx, [inp + ebx * 4]
    imul edx, dword [eax]
    add [hidden + ecx * 4], edx
    pop edx
    pop eax
    inc ebx
    dec edx
    jnz .hacc
    mov eax, [hidden + ecx * 4]
    sar eax, 16
    mov [hidden + ecx * 4], eax
    inc ecx
    cmp ecx, 4
    jl .hloop

    xor eax, eax
    mov ebx, [hidden + 0]
    imul ebx, [brain_w_ho + 0]
    add eax, ebx
    mov ebx, [hidden + 1]
    imul ebx, [brain_w_ho + 4]
    add eax, ebx
    sar eax, 16
    mov ebx, eax

    mov eax, 1
    cmp ebx, 50
    jl .set
    mov eax, 2
    cmp ebx, 120
    jl .set
    mov eax, 3
.set:
    mov [brain_mood], eax

    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret
