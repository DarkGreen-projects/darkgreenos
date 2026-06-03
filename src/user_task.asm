; DarkgreenOS - user task spawn and ring-3 entry

%include "constants.inc"

extern sched_task_state
extern sched_task_prio
extern sched_task_quantum
extern sched_task_used
extern sched_task_started
extern sched_task_esp
extern sched_current
extern sched_task_cr3
extern sched_task_is_user
extern sched_task_user_eip
extern sched_task_user_esp
extern paging_create_task_dir
extern paging_map_user_page
extern paging_get_kernel_cr3
extern paging_switch_cr3
extern pmm_alloc_page
extern paging_free_task_dir
extern paging_map_task
extern task_map_next

global task_spawn_user
global user_hello_start
global user_enter_ring3

section .rodata
user_spawn_ok:  db "[task] user spawned", 0
user_spawn_fail: db "[task] spawn failed", 0

section .text
; task_spawn_user() -> eax=task id or -1
; Maps embedded hello stub at USER_VA_BASE and starts task 2
task_spawn_user:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    mov edi, 2
.find:
    cmp edi, SCH_MAX_TASKS
    jge .fail
    cmp dword [sched_task_state + edi * 4], SCH_STATE_DEAD
    je .slot
    cmp dword [sched_task_started + edi * 4], 0
    je .slot
    inc edi
    jmp .find
.slot:
    call paging_create_task_dir
    test eax, eax
    jz .fail
    mov ebx, eax
    mov [sched_task_cr3 + edi * 4], ebx
    call pmm_alloc_page
    test eax, eax
    jz .fail_free
    mov esi, eax
    push edi
    push esi
    mov edi, esi
    mov ecx, user_hello_end - user_hello_start
    mov esi, user_hello_start
    rep movsb
    pop esi
    pop edi
    mov [paging_map_task], edi
    xor ebx, ebx
    mov eax, esi
    call paging_map_user_page
    mov dword [paging_map_task], 0
    test al, al
    jz .fail_free
    mov dword [task_map_next + edi * 4], 1
    mov dword [sched_task_is_user + edi * 4], 1
    mov dword [sched_task_user_eip + edi * 4], USER_VA_BASE
    mov dword [sched_task_user_esp + edi * 4], USER_STACK_TOP
    mov dword [sched_task_state + edi * 4], SCH_STATE_READY
    mov dword [sched_task_prio + edi * 4], 80
    mov dword [sched_task_quantum + edi * 4], 40
    mov dword [sched_task_used + edi * 4], 0
    mov eax, edi
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret
.fail_free:
    mov eax, ebx
    call paging_free_task_dir
.fail:
    mov eax, -1
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

global user_enter_ring3
; user_enter_ring3(eax=task_id) — iret to user mode (no return)
user_enter_ring3:
    push ebx
    mov ebx, eax
    mov eax, [sched_task_cr3 + ebx * 4]
    call paging_switch_cr3
    push dword GDT_USER_DATA_SEG
    push dword [sched_task_user_esp + ebx * 4]
    pushfd
    pop eax
    or eax, 0x202
    push eax
    push dword GDT_USER_CODE_SEG
    push dword [sched_task_user_eip + ebx * 4]
    iret

; Minimal user hello (PIC): SYS_WRITE, SYS_YIELD, SYS_EXIT
user_hello_start:
    mov eax, SYS_WRITE
    call .getpc
.getpc:
    pop ebx
    add ebx, (.msg - .getpc)
    mov ecx, .msg_len
    int 0x80
    mov eax, SYS_YIELD
    int 0x80
    mov eax, SYS_EXIT
    xor ebx, ebx
    int 0x80
.msg:
    db "hello user", 10
.msg_len equ $ - .msg
user_hello_end:
