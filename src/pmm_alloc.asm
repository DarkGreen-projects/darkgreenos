; DarkgreenOS - bump allocator (PMM v2) with live free_kb

%include "constants.inc"

extern pmm_free_kb
extern rmgr_hook_enter
extern rmgr_hook_leave

global pmm_alloc_init
global pmm_alloc_kb
global pmm_free_all
global pmm_alloc_used_kb

section .bss
pmm_arena_ptr:     resd 1
pmm_arena_end:     resd 1
pmm_alloc_used_kb: resd 1
pmm_last_alloc:    resd 1

section .text
pmm_alloc_init:
    mov dword [pmm_arena_ptr], PMM_ARENA_BASE
    mov eax, PMM_ARENA_BASE
    add eax, PMM_ARENA_BYTES
    mov [pmm_arena_end], eax
    mov dword [pmm_alloc_used_kb], 0
    mov dword [pmm_last_alloc], 0
    ret

; pmm_alloc_kb(eax=kb) -> eax=ptr or 0
pmm_alloc_kb:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    test eax, eax
    jz .fail
    mov ecx, eax
    mov ebx, eax
    shl ebx, 10
    push ecx
    mov eax, RMGR_ACT_PMM_ALLOC
    call rmgr_hook_enter
    test al, al
    jz .fail_pop
    pop ecx
    mov eax, [pmm_arena_ptr]
    mov esi, eax
    lea edi, [eax + ebx]
    cmp edi, [pmm_arena_end]
    ja .fail_leave
    mov [pmm_arena_ptr], edi
    mov [pmm_last_alloc], esi
    mov eax, ecx
    add [pmm_alloc_used_kb], eax
    sub [pmm_free_kb], eax
    mov eax, esi
    call rmgr_hook_leave
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret
.fail_pop:
    pop ecx
.fail:
    xor eax, eax
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret
.fail_leave:
    pop ecx
    xor eax, eax
    call rmgr_hook_leave
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; pmm_free_all() — reset bump arena (caller may wrap with RMGR_ACT_PMM_FREE)
pmm_free_all:
    push eax
    mov eax, [pmm_alloc_used_kb]
    add [pmm_free_kb], eax
    mov dword [pmm_alloc_used_kb], 0
    mov dword [pmm_arena_ptr], PMM_ARENA_BASE
    mov dword [pmm_last_alloc], 0
    pop eax
    ret
