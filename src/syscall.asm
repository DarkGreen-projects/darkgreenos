; DarkgreenOS - syscalls with RMGR hooks (int 0x80, ring-0/ring-3)

%include "constants.inc"

extern rmgr_hook_enter
extern rmgr_hook_leave
extern scheduler_yield
extern scheduler_fault_kill
extern sched_current
extern sched_task_is_user
extern pmm_alloc_kb
extern pmm_free_ptr
extern paging_alloc_user_pages
extern paging_free_user_va
extern err_ring_push
extern fs_open
extern fs_read
extern fs_close
extern serial_write
extern copy_from_user
extern ptr_in_user_region
extern idt_start

global syscall_init
global syscall_entry

section .text
syscall_init:
    push ebx
    push edi
    mov edi, idt_start
    add edi, INT_SYSCALL * 8
    mov ebx, syscall_entry
    mov ax, bx
    mov [edi], ax
    shr ebx, 16
    mov [edi + 6], bx
    mov word [edi + 2], GDT_CODE_SEG
    mov byte [edi + 4], 0
    mov byte [edi + 5], 11101111b
    pop edi
    pop ebx
    ret

syscall_entry:
    push ds
    push es
    push fs
    push gs
    pusha
    mov ax, GDT_DATA_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov eax, RMGR_ACT_SYSCALL
    call rmgr_hook_enter
    test al, al
    jz .deny_log
    mov eax, [esp + 28]
    cmp eax, SYS_EXIT
    je .do_exit
    cmp eax, SYS_YIELD
    je .do_yield
    cmp eax, SYS_WRITE
    je .do_write
    cmp eax, SYS_READ
    je .do_read
    cmp eax, SYS_OPEN
    je .do_open
    cmp eax, SYS_ALLOC
    je .do_alloc
    cmp eax, SYS_FREE
    je .do_free
    mov eax, -1
    jmp .done
.do_exit:
    mov ebx, [sched_current]
    call scheduler_fault_kill
    xor eax, eax
    jmp .done
.do_yield:
    call scheduler_yield
    xor eax, eax
    jmp .done
.do_write:
    mov ebx, [esp + 16]
    mov ecx, [esp + 24]
    mov eax, ebx
    call ptr_in_user_region
    test al, al
    jz .bad_ptr
    push ecx
    push ebx
.write_loop:
    test ecx, ecx
    jz .write_ok
    mov al, [ebx]
    call serial_write
    inc ebx
    dec ecx
    jmp .write_loop
.write_ok:
    pop ebx
    pop eax
    jmp .done
.do_read:
    mov eax, [esp + 16]
    mov ebx, [esp + 24]
    mov ecx, [esp + 20]
    call fs_read
    jmp .done
.do_open:
    mov esi, [esp + 16]
    mov eax, esi
    call ptr_in_user_region
    test al, al
    jz .bad_ptr
    call fs_open
    jmp .done
.do_alloc:
    mov eax, [esp + 16]
    test eax, eax
    jz .bad_ptr
    cmp eax, 64
    ja .bad_ptr
    call paging_alloc_user_pages
    jmp .done
.do_free:
    mov eax, [esp + 16]
    call paging_free_user_va
    movzx eax, al
    jmp .done
.bad_ptr:
    push ecx
    push ebx
    mov eax, ERR_BAD_PTR
    xor ebx, ebx
    xor ecx, ecx
    call err_ring_push
    pop ebx
    pop ecx
    mov eax, -1
    jmp .done
.deny_log:
    push ecx
    push ebx
    mov eax, ERR_SYSCALL_DENY
    xor ebx, ebx
    xor ecx, ecx
    call err_ring_push
    pop ebx
    pop ecx
.denied:
    mov eax, -2
.done:
    mov [esp + 28], eax
    call rmgr_hook_leave
    popa
    pop gs
    pop fs
    pop es
    pop ds
    add esp, 4
    add esp, 4
    iret
