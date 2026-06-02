; DarkgreenOS - greedy sampling / intent selection baseline

%include "constants.inc"

global llm_sample_greedy
global llm_sample_topk
global llm_route
global llm_sampler_temperature
global llm_sampler_top_k
global llm_sampler_top_p

section .bss
llm_route: resd 1
llm_sampler_temperature: resd 1
llm_sampler_top_k: resd 1
llm_sampler_top_p: resd 1
llm_sampler_rng: resd 1

extern llm_logits_top_ids
extern llm_logits_top_scores
extern timer_ticks

section .rodata
kw_ciao:     db "ciao", 0
kw_hello:    db "hello", 0
kw_help:     db "help", 0
kw_aiuto:    db "aiuto", 0
kw_comandi:  db "comandi", 0
kw_chi:      db "chi", 0
kw_sei:      db "sei", 0
kw_darkmind: db "darkmind", 0
kw_model:    db "modello", 0
kw_llm:      db "llm", 0
kw_qwen:     db "qwen", 0
kw_decode:   db "decode", 0
kw_tokenizer: db "tokenizer", 0
kw_logits:   db "logits", 0
kw_mem:      db "mem", 0
kw_ram:      db "ram", 0
kw_mappa:    db "mappa", 0
kw_gui:      db "gui", 0
kw_screen:   db "screen", 0
kw_framebuffer: db "framebuffer", 0
kw_mouse:    db "mouse", 0
kw_tastiera: db "tastiera", 0
kw_keyboard: db "keyboard", 0
kw_boot:     db "boot", 0
kw_grub:     db "grub", 0
kw_file:     db "file", 0
kw_files:    db "files", 0
kw_kernel:   db "kernel", 0
kw_scan:     db "scan", 0
kw_stato:    db "stato", 0
kw_status:   db "status", 0

section .text
; llm_sample_greedy(esi=prompt) -> eax=route id
llm_sample_greedy:
    push esi
    mov edi, kw_ciao
    call contains
    test al, al
    jnz .hello
    pop esi
    push esi
    mov edi, kw_hello
    call contains
    test al, al
    jnz .hello
    pop esi
    push esi
    mov edi, kw_help
    call contains
    test al, al
    jnz .help
    pop esi
    push esi
    mov edi, kw_aiuto
    call contains
    test al, al
    jnz .help
    pop esi
    push esi
    mov edi, kw_comandi
    call contains
    test al, al
    jnz .help
    pop esi
    push esi
    mov edi, kw_chi
    call contains
    test al, al
    jnz .identity
    pop esi
    push esi
    mov edi, kw_sei
    call contains
    test al, al
    jnz .identity
    pop esi
    push esi
    mov edi, kw_darkmind
    call contains
    test al, al
    jnz .identity
    pop esi
    push esi
    mov edi, kw_model
    call contains
    test al, al
    jnz .model
    pop esi
    push esi
    mov edi, kw_llm
    call contains
    test al, al
    jnz .model
    pop esi
    push esi
    mov edi, kw_qwen
    call contains
    test al, al
    jnz .model
    pop esi
    push esi
    mov edi, kw_decode
    call contains
    test al, al
    jnz .model
    pop esi
    push esi
    mov edi, kw_tokenizer
    call contains
    test al, al
    jnz .model
    pop esi
    push esi
    mov edi, kw_logits
    call contains
    test al, al
    jnz .model
    pop esi
    push esi
    mov edi, kw_mem
    call contains
    test al, al
    jnz .memory
    pop esi
    push esi
    mov edi, kw_ram
    call contains
    test al, al
    jnz .memory
    pop esi
    push esi
    mov edi, kw_mappa
    call contains
    test al, al
    jnz .memory
    pop esi
    push esi
    mov edi, kw_gui
    call contains
    test al, al
    jnz .gui
    pop esi
    push esi
    mov edi, kw_screen
    call contains
    test al, al
    jnz .gui
    pop esi
    push esi
    mov edi, kw_framebuffer
    call contains
    test al, al
    jnz .gui
    pop esi
    push esi
    mov edi, kw_mouse
    call contains
    test al, al
    jnz .mouse
    pop esi
    push esi
    mov edi, kw_tastiera
    call contains
    test al, al
    jnz .keyboard
    pop esi
    push esi
    mov edi, kw_keyboard
    call contains
    test al, al
    jnz .keyboard
    pop esi
    push esi
    mov edi, kw_boot
    call contains
    test al, al
    jnz .boot
    pop esi
    push esi
    mov edi, kw_grub
    call contains
    test al, al
    jnz .boot
    pop esi
    push esi
    mov edi, kw_file
    call contains
    test al, al
    jnz .files
    pop esi
    push esi
    mov edi, kw_files
    call contains
    test al, al
    jnz .files
    pop esi
    push esi
    mov edi, kw_kernel
    call contains
    test al, al
    jnz .files
    pop esi
    push esi
    mov edi, kw_scan
    call contains
    test al, al
    jnz .scan
    pop esi
    push esi
    mov edi, kw_stato
    call contains
    test al, al
    jnz .scan
    pop esi
    push esi
    mov edi, kw_status
    call contains
    test al, al
    jnz .scan
    pop esi
    mov eax, 0
    jmp .set
.hello:
    pop esi
    mov eax, 7
    jmp .set
.help:
    pop esi
    mov eax, 8
    jmp .set
.identity:
    pop esi
    mov eax, 9
    jmp .set
.model:
    pop esi
    mov eax, 1
    jmp .set
.memory:
    pop esi
    mov eax, 2
    jmp .set
.gui:
    pop esi
    mov eax, 3
    jmp .set
.mouse:
    pop esi
    mov eax, 4
    jmp .set
.keyboard:
    pop esi
    mov eax, 5
    jmp .set
.boot:
    pop esi
    mov eax, 6
    jmp .set
.files:
    pop esi
    mov eax, 10
    jmp .set
.scan:
    pop esi
    mov eax, 11
.set:
    mov [llm_route], eax
    ret

contains:
    push ebx
    push edx
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
    mov dl, [esi]
    cmp dl, 'A'
    jb .cmp
    cmp dl, 'Z'
    ja .cmp
    add dl, 32
.cmp:
    cmp dl, bl
    jne .next
    inc esi
    inc edi
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
    pop edx
    pop ebx
    ret

; llm_sample_topk() -> eax=token id from llm_logits_top_ids.
; Supports greedy when temperature/top-p are zero; otherwise deterministic
; top-k sampling from the candidate buffer.
llm_sample_topk:
    push ebx
    push ecx
    push edx
    mov ecx, [llm_sampler_top_k]
    test ecx, ecx
    jnz .k_ok
    mov ecx, 8
.k_ok:
    cmp ecx, 16
    jbe .k_clamped
    mov ecx, 16
.k_clamped:
    cmp dword [llm_sampler_temperature], 0
    jne .sample
    mov eax, [llm_logits_top_ids]
    jmp .out
.sample:
    mov eax, [llm_sampler_rng]
    test eax, eax
    jnz .rng_seeded
    mov eax, [timer_ticks]
    xor eax, 0x6D2B79F5
.rng_seeded:
    imul eax, 1664525
    add eax, 1013904223
    mov [llm_sampler_rng], eax
    xor edx, edx
    div ecx
    mov eax, [llm_logits_top_ids + edx * 4]
.out:
    pop edx
    pop ecx
    pop ebx
    ret
