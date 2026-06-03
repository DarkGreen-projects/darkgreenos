; DarkgreenOS - unified error ring (PF/GPF/syscall/ptr)

%include "constants.inc"

extern rmgr_hook_enter
extern rmgr_hook_leave
extern rmgr_current_action
extern sched_current

global err_ring_push
global err_ring_count
global err_ring_format
global err_ring_clear

section .bss
align 4
err_ring_count: resd 1
err_ring_head:  resd 1
err_ring_buf:   resb ERR_RING_ENTRIES * ERR_ENTRY_BYTES

section .rodata
el_pf_u:  db "ERR pf_user t=", 0
el_gpf_u: db "ERR gpf_user t=", 0
el_sc_d:  db "ERR syscall_deny", 0
el_bp:    db "ERR bad_ptr", 0

section .text
; err_ring_push(eax=code, ebx=eip, ecx=cr2)
err_ring_push:
    push ecx
    push ebx
    push eax
    push edi
    mov eax, RMGR_ACT_ERR_LOG
    call rmgr_hook_enter
    pop edi
    pop edx
    pop ebx
    pop ecx
    mov eax, [err_ring_head]
    imul eax, ERR_ENTRY_BYTES
    lea edi, [err_ring_buf + eax]
    mov [edi + 0], edx
    mov eax, [sched_current]
    mov [edi + 4], eax
    mov [edi + 8], ebx
    mov [edi + 12], ecx
    mov eax, [rmgr_current_action]
    mov [edi + 14], eax
    mov eax, [err_ring_head]
    inc eax
    cmp eax, ERR_RING_ENTRIES
    jb .h
    xor eax, eax
.h:
    mov [err_ring_head], eax
    inc dword [err_ring_count]
    mov eax, RMGR_ACT_ERR_LOG
    jmp rmgr_hook_leave

err_ring_clear:
    xor eax, eax
    mov [err_ring_count], eax
    mov [err_ring_head], eax
    ret

; err_ring_format(esi=buf)
err_ring_format:
    push eax
    push ebx
    push ecx
    push edi
    mov edi, esi
    cmp dword [err_ring_count], 0
    je .empty
    mov eax, [err_ring_head]
    test eax, eax
    jnz .idx
    mov eax, ERR_RING_ENTRIES
.idx:
    dec eax
    imul eax, ERR_ENTRY_BYTES
    lea ebx, [err_ring_buf + eax]
    mov eax, [ebx + 0]
    cmp eax, ERR_PF_USER
    je .pf
    cmp eax, ERR_GPF_USER
    je .gpf
    cmp eax, ERR_SYSCALL_DENY
    je .sc
    cmp eax, ERR_BAD_PTR
    je .bp
    mov byte [edi], '?'
    mov byte [edi + 1], 0
    jmp .out
.pf:
    mov esi, el_pf_u
    jmp .cpy
.gpf:
    mov esi, el_gpf_u
    jmp .cpy
.sc:
    mov esi, el_sc_d
    jmp .cpy
.bp:
    mov esi, el_bp
.cpy:
    lodsb
    test al, al
    jz .out
    mov [edi], al
    inc edi
    jmp .cpy
.empty:
    mov byte [edi], '-'
    inc edi
    mov byte [edi], 0
.out:
    pop edi
    pop ecx
    pop ebx
    pop eax
    ret
