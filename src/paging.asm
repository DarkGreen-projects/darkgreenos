; DarkgreenOS - paging: identity map + per-task user regions (4 KiB pages)

%include "constants.inc"

extern pmm_alloc_page
extern pmm_free_page
extern sched_current

global paging_init
global paging_get_kernel_cr3
global paging_create_task_dir
global paging_map_user_page
global paging_switch_cr3
global paging_free_task_dir
global paging_alloc_user_pages
global paging_free_user_va
global paging_map_task
global task_map_next

section .bss
align 4096
global page_directory
page_directory:
    resd 1024

align 4
task_page_dirs:     resd SCH_MAX_TASKS
task_dir_used:      resd SCH_MAX_TASKS
task_user_pts:      resd SCH_MAX_TASKS
task_map_next:      resd SCH_MAX_TASKS
task_page_phys:     resd SCH_MAX_TASKS * 256
kernel_cr3:         resd 1
paging_map_task:    resd 1

section .text
paging_init:
    push ebx
    push ecx
    push edi

    mov eax, cr4
    or eax, CR4_PSE
    mov cr4, eax

    mov edi, page_directory
    mov ecx, IDENTITY_MAP_MB / 4
    xor ebx, ebx
.map_loop:
    mov eax, ebx
    or eax, PDE_KERNEL_RW_4MB
    mov [edi], eax
    add ebx, 0x400000
    add edi, 4
    dec ecx
    jnz .map_loop

    mov eax, page_directory
    mov [kernel_cr3], eax
    mov cr3, eax

    mov eax, cr0
    or eax, CR0_PG
    mov cr0, eax

    xor eax, eax
    mov edi, task_page_dirs
    mov ecx, SCH_MAX_TASKS * 4
    rep stosd
    mov edi, task_dir_used
    mov ecx, SCH_MAX_TASKS
    rep stosd
    mov edi, task_user_pts
    rep stosd
    mov edi, task_map_next
    rep stosd
    mov edi, task_page_phys
    mov ecx, SCH_MAX_TASKS * 256
    rep stosd
    mov dword [paging_map_task], 0

    pop edi
    pop ecx
    pop ebx
    ret

paging_get_kernel_cr3:
    mov eax, [kernel_cr3]
    ret

paging_create_task_dir:
    push ebx
    push ecx
    push edi
    push esi
    call pmm_alloc_page
    test eax, eax
    jz .fail
    mov ebx, eax
    mov edi, eax
    mov esi, page_directory
    mov ecx, 1024
    rep movsd
    call pmm_alloc_page
    test eax, eax
    jz .free_pd
    mov esi, eax
    mov edi, esi
    mov ecx, 1024
    xor eax, eax
    rep stosd
    mov eax, USER_VA_BASE
    shr eax, 22
    lea ecx, [ebx + eax * 4]
    mov eax, esi
    or eax, PTE_KERNEL_RW | PAGE_USER
    mov [ecx], eax
    xor ecx, ecx
.find_slot:
    cmp ecx, SCH_MAX_TASKS
    jge .free_both
    cmp dword [task_dir_used + ecx * 4], 0
    je .slot
    inc ecx
    jmp .find_slot
.slot:
    mov [task_page_dirs + ecx * 4], ebx
    mov [task_user_pts + ecx * 4], esi
    mov dword [task_dir_used + ecx * 4], 1
    mov dword [task_map_next + ecx * 4], 0
    imul eax, ecx, 256 * 4
    lea edi, [task_page_phys + eax]
    mov ecx, 256
    xor eax, eax
    rep stosd
    mov eax, ebx
    jmp .out
.free_both:
    mov eax, esi
    call pmm_free_page
.free_pd:
    mov eax, ebx
    call pmm_free_page
    xor eax, eax
.fail:
.out:
    pop esi
    pop edi
    pop ecx
    pop ebx
    ret

; paging_map_user_page(eax=phys, ebx=page_index) -> al=1 ok
paging_map_user_page:
    push ecx
    push edi
    test eax, eax
    jz .no
    cmp ebx, 1024
    jae .no
    mov ecx, [paging_map_task]
    test ecx, ecx
    jnz .have
    mov ecx, [sched_current]
.have:
    cmp ecx, SCH_MAX_TASKS
    jae .no
    mov edi, [task_user_pts + ecx * 4]
    test edi, edi
    jz .no
    or eax, PTE_KERNEL_RW | PAGE_USER
    mov [edi + ebx * 4], eax
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop edi
    pop ecx
    ret

paging_switch_cr3:
    mov cr3, eax
    ret

; paging_alloc_user_pages(eax=page_count) -> eax=VA or 0
paging_alloc_user_pages:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp
    test eax, eax
    jz .fail
    mov ebx, [sched_current]
    cmp ebx, SCH_MAX_TASKS
    jae .fail
    mov ebp, eax
    mov edx, [task_map_next + ebx * 4]
    mov eax, edx
    add eax, ebp
    cmp eax, 256
    ja .fail
    mov eax, edx
    shl eax, 12
    add eax, USER_VA_BASE
    push eax
    imul esi, ebx, 256 * 4
    lea edi, [task_page_phys + esi]
    mov esi, [task_user_pts + ebx * 4]
.loop:
    push ebp
    push edx
    push edi
    push esi
    call pmm_alloc_page
    test eax, eax
    jz .fail_pop
    mov ecx, eax
    mov [edi + edx * 4], ecx
    or ecx, PTE_KERNEL_RW | PAGE_USER
    mov [esi + edx * 4], ecx
    inc edx
    pop esi
    pop edi
    pop edx
    pop ebp
    dec ebp
    jnz .loop
    mov [task_map_next + ebx * 4], edx
    pop eax
    jmp .out
.fail_pop:
    pop esi
    pop edi
    pop edx
    pop ebp
    add esp, 4
.fail:
    xor eax, eax
.out:
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; paging_free_user_va(eax=va) -> al=1 ok
paging_free_user_va:
    push ebx
    push ecx
    push esi
    mov ebx, [sched_current]
    cmp ebx, SCH_MAX_TASKS
    jae .no
    sub eax, USER_VA_BASE
    jb .no
    shr eax, 12
    cmp eax, [task_map_next + ebx * 4]
    jae .no
    mov ecx, eax
    imul eax, ebx, 256 * 4
    lea esi, [task_page_phys + eax]
    mov eax, [esi + ecx * 4]
    test eax, eax
    jz .no
    push eax
    mov edi, [task_user_pts + ebx * 4]
    mov dword [edi + ecx * 4], 0
    pop eax
    call pmm_free_page
    mov dword [esi + ecx * 4], 0
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop esi
    pop ecx
    pop ebx
    ret

paging_free_task_dir:
    push ebx
    push ecx
    push edi
    mov ebx, eax
    xor ecx, ecx
.scan:
    cmp ecx, SCH_MAX_TASKS
    jge .out
    cmp [task_page_dirs + ecx * 4], ebx
    jne .next
    push ecx
    imul eax, ecx, 256 * 4
    lea edi, [task_page_phys + eax]
    mov ecx, 256
    xor eax, eax
    rep stosd
    pop ecx
    mov eax, [task_user_pts + ecx * 4]
    test eax, eax
    jz .free_pd
    call pmm_free_page
.free_pd:
    mov eax, ebx
    call pmm_free_page
    mov dword [task_page_dirs + ecx * 4], 0
    mov dword [task_dir_used + ecx * 4], 0
    mov dword [task_user_pts + ecx * 4], 0
    mov dword [task_map_next + ecx * 4], 0
    jmp .out
.next:
    inc ecx
    jmp .scan
.out:
    pop edi
    pop ecx
    pop ebx
    ret
