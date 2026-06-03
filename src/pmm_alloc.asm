; DarkgreenOS - PMM free-list allocator with RMGR hooks

%include "constants.inc"

extern pmm_free_kb
extern rmgr_hook_enter
extern rmgr_hook_leave

global pmm_alloc_init
global pmm_alloc_kb
global pmm_alloc_page
global pmm_free_page
global pmm_free_ptr
global pmm_free_all
global pmm_alloc_used_kb

section .bss
pmm_free_head:     resd 1
pmm_alloc_used_kb: resd 1

section .text
pmm_list_remove:
    ; esi = block header to remove
    push ebx
    push edi
    mov edi, [pmm_free_head]
    cmp edi, esi
    je .head
.find:
    mov ebx, [edi + 4]
    test ebx, ebx
    jz .out
    cmp ebx, esi
    je .unlink
    mov edi, ebx
    jmp .find
.head:
    mov eax, [esi + 4]
    mov [pmm_free_head], eax
    jmp .out
.unlink:
    mov eax, [esi + 4]
    mov [edi + 4], eax
.out:
    pop edi
    pop ebx
    ret

pmm_alloc_init:
    mov dword [pmm_free_head], PMM_ARENA_BASE
    mov eax, PMM_ARENA_BASE
    mov dword [eax], PMM_ARENA_BYTES
    mov dword [eax + 4], 0
    mov dword [pmm_alloc_used_kb], 0
    ret

; pmm_alloc_kb(eax=kb) -> eax=data ptr or 0
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
    add ebx, 8
    push ecx
    mov eax, RMGR_ACT_PMM_ALLOC
    call rmgr_hook_enter
    test al, al
    jz .fail_pop
    pop ecx
    mov edi, [pmm_free_head]
.search:
    test edi, edi
    jz .fail_leave
    mov eax, [edi]
    cmp eax, ebx
    jae .found
    mov edi, [edi + 4]
    jmp .search
.found:
    mov esi, edi
    add [pmm_alloc_used_kb], ecx
    sub [pmm_free_kb], ecx
    mov eax, [esi]
    sub eax, ebx
    cmp eax, 16
    jb .take_all
    mov edx, esi
    add edx, ebx
    mov [edx], eax
    mov eax, [esi + 4]
    mov [edx + 4], eax
    mov dword [esi], ebx
    mov eax, esi
    add eax, 8
    call rmgr_hook_leave
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret
.take_all:
    call pmm_list_remove
    mov eax, esi
    add eax, 8
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
    xor eax, eax
    call rmgr_hook_leave
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; pmm_free_ptr(eax=data ptr) -> al=1 ok
pmm_free_ptr:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    test eax, eax
    jz .fail
    mov esi, eax
    sub esi, 8
    cmp esi, PMM_ARENA_BASE
    jb .fail
    mov edx, PMM_ARENA_BASE
    add edx, PMM_ARENA_BYTES
    cmp esi, edx
    jae .fail
    push esi
    mov eax, RMGR_ACT_PMM_FREE
    call rmgr_hook_enter
    test al, al
    jz .fail_pop
    pop esi
    mov ebx, [esi]
    shr ebx, 10
    sub [pmm_alloc_used_kb], ebx
    add [pmm_free_kb], ebx
    mov edi, [pmm_free_head]
    test edi, edi
    jz .first
    cmp esi, edi
    jb .insert_head
    mov edi, [pmm_free_head]
.next:
    mov ebx, [edi + 4]
    test ebx, ebx
    jz .insert_tail
    cmp esi, ebx
    jb .insert_mid
    mov edi, ebx
    jmp .next
.insert_tail:
    mov [edi + 4], esi
    mov dword [esi + 4], 0
    jmp .merge
.insert_mid:
    mov eax, [edi + 4]
    mov [edi + 4], esi
    mov [esi + 4], eax
    jmp .merge
.insert_head:
    mov eax, [pmm_free_head]
    mov [pmm_free_head], esi
    mov [esi + 4], eax
    jmp .merge
.first:
    mov [pmm_free_head], esi
    mov dword [esi + 4], 0
.merge:
    mov eax, [esi]
    add eax, esi
    mov ebx, [esi + 4]
    test ebx, ebx
    jz .done
    cmp eax, ebx
    jne .done
    mov ecx, [ebx]
    add [esi], ecx
    mov eax, [ebx + 4]
    mov [esi + 4], eax
.done:
    mov al, 1
    call rmgr_hook_leave
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret
.fail_pop:
    pop esi
.fail:
    xor al, al
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; pmm_alloc_page() -> eax=phys addr or 0 (4096 bytes)
pmm_alloc_page:
    mov eax, 4
    call pmm_alloc_kb
    ret

; pmm_free_page(eax=phys addr) -> al=1 ok
pmm_free_page:
    call pmm_free_ptr
    ret

pmm_free_all:
    push eax
    mov eax, [pmm_alloc_used_kb]
    add [pmm_free_kb], eax
    mov dword [pmm_alloc_used_kb], 0
    mov dword [pmm_free_head], PMM_ARENA_BASE
    mov eax, PMM_ARENA_BASE
    mov dword [eax], PMM_ARENA_BYTES
    mov dword [eax + 4], 0
    pop eax
    ret
