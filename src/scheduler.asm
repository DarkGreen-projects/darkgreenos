; DarkgreenOS - preemptive scheduler with real kernel-thread context switch

%include "constants.inc"

extern timer_ticks
extern rmgr_throttle_div
extern rmgr_free_min_kb_eff
extern pmm_free_kb
extern gui_poll
extern brain_step
extern companion_poll
extern ps2_poll
extern keyboard_poll
extern gui_handle_key
extern darkmind_busy
extern tinylm_busy
extern rmgr_hook_enter
extern rmgr_hook_leave
extern paging_get_kernel_cr3
extern paging_switch_cr3
extern user_enter_ring3

global scheduler_init
global scheduler_preempt_check
global scheduler_timer_tick
global scheduler_yield
global scheduler_fault_kill
global scheduler_format_status
global scheduler_switch_to
global task0_main
global task1_main
global sched_current
global sched_preempt_req
global sched_bg_ticks
global sched_task_state
global sched_task_prio
global sched_task_quantum
global sched_task_used
global sched_task_started
global sched_task_cr3
global sched_task_is_user
global sched_task_user_eip
global sched_task_user_esp

global sched_force_yield

%define SCH_BG_PRIO_THRESH        128

section .bss
align 16
sched_task_stacks:  resb SCH_MAX_TASKS * SCH_STACK_SIZE
align 4
sched_current:      resd 1
sched_preempt_req:  resd 1
sched_task_state:   resd SCH_MAX_TASKS
sched_task_prio:    resd SCH_MAX_TASKS
sched_task_quantum: resd SCH_MAX_TASKS
sched_task_used:    resd SCH_MAX_TASKS
sched_task_esp:     resd SCH_MAX_TASKS
sched_task_started: resd SCH_MAX_TASKS
sched_task_cr3:     resd SCH_MAX_TASKS
sched_task_is_user: resd SCH_MAX_TASKS
sched_task_user_eip: resd SCH_MAX_TASKS
sched_task_user_esp: resd SCH_MAX_TASKS
sched_bg_ticks:     resd 1
sched_force_yield:  resd 1
sched_status_buf:   resb 64

section .text
scheduler_init:
    push eax
    push ecx
    push edi
    xor eax, eax
    mov [sched_current], eax
    mov [sched_preempt_req], eax
    mov [sched_bg_ticks], eax
    mov [sched_force_yield], eax
    mov edi, sched_task_state
    mov ecx, SCH_MAX_TASKS * 6
    rep stosd
    mov dword [sched_task_state], SCH_STATE_RUNNING
    mov dword [sched_task_prio + 0], 200
    mov dword [sched_task_quantum + 0], 80
    ; Task 1 inactive until explicit yield (background must not steal input)
    mov dword [sched_task_state + 4], SCH_STATE_DEAD
    mov dword [sched_task_prio + 4], 60
    mov dword [sched_task_quantum + 4], 40
    mov dword [sched_task_started], 1
    pop edi
    pop ecx
    pop eax
    ret

scheduler_recalc_quantum:
    push eax
    push ebx
    mov ebx, [sched_current]
    mov eax, [rmgr_throttle_div]
    test eax, eax
    jnz .ok
    mov eax, 1
.ok:
    mov ecx, 120
    xor edx, edx
    div eax
    test eax, eax
    jnz .store
    mov eax, 8
.store:
    cmp ebx, 0
    jne .store_q
    cmp dword [rmgr_throttle_div], 2
    jbe .store_q
    add eax, 20
.store_q:
    mov [sched_task_quantum + ebx * 4], eax
    mov dword [sched_task_used + ebx * 4], 0
    pop ebx
    pop eax
    ret

scheduler_timer_tick:
    push eax
    push ebx
    mov ebx, [sched_current]
    inc dword [sched_task_used + ebx * 4]
    mov eax, [sched_task_used + ebx * 4]
    cmp eax, [sched_task_quantum + ebx * 4]
    jb .out
    ; Never timer-preempt GUI task 0 (keyboard/mouse live only there)
    cmp ebx, 0
    je .out
    mov dword [sched_preempt_req], 1
    call scheduler_recalc_quantum
.out:
    pop ebx
    pop eax
    ret

; Pick highest-priority READY task; deny background under LOW_RAM
scheduler_pick_next:
    push ebx
    push ecx
    push edx
    push esi
    mov ebx, -1
    mov esi, [sched_current]
    xor ecx, ecx
.scan:
    cmp ecx, SCH_MAX_TASKS
    jge .done
    cmp dword [sched_task_state + ecx * 4], SCH_STATE_READY
    jne .next
    mov eax, [sched_task_prio + ecx * 4]
    cmp eax, ebx
    jle .next
    mov edx, [pmm_free_kb]
    cmp edx, [rmgr_free_min_kb_eff]
    jae .take
    cmp eax, SCH_BG_PRIO_THRESH
    jae .take
    jmp .next
.take:
    mov ebx, eax
    mov esi, ecx
.next:
    inc ecx
    jmp .scan
.done:
    mov eax, esi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

scheduler_yield:
    mov dword [sched_task_state + 4], SCH_STATE_READY
    mov dword [sched_preempt_req], 1
    mov dword [sched_force_yield], 1
    call scheduler_preempt_check
    ret

; scheduler_switch_to(eax=to) — cooperative stack switch
scheduler_switch_to:
    push ebp
    push ebx
    push esi
    push edi
    mov edi, eax
    mov esi, [sched_current]
    cmp edi, esi
    je .out
    cmp dword [sched_force_yield], 0
    je .hooked
    mov dword [sched_task_state + esi * 4], SCH_STATE_READY
    mov [sched_current], edi
    mov dword [sched_task_state + edi * 4], SCH_STATE_RUNNING
    call scheduler_recalc_quantum
    jmp .sw_resume
.hooked:
    push edi
    push esi
    mov eax, RMGR_ACT_TASK_SWITCH
    call rmgr_hook_enter
    test al, al
    pop esi
    pop edi
    jz .out
    mov dword [sched_task_state + esi * 4], SCH_STATE_READY
    mov [sched_current], edi
    mov dword [sched_task_state + edi * 4], SCH_STATE_RUNNING
    call scheduler_recalc_quantum
    call .sw_resume
.sw_resume:
    mov [sched_task_esp + esi * 4], esp
    mov eax, [sched_task_cr3 + edi * 4]
    test eax, eax
    jz .use_kcr3
    call paging_switch_cr3
    jmp .cr3_done
.use_kcr3:
    call paging_get_kernel_cr3
    call paging_switch_cr3
.cr3_done:
    cmp dword [sched_task_started + edi * 4], 0
    je .first
    mov esp, [sched_task_esp + edi * 4]
    pop edi
    pop esi
    pop ebx
    pop ebp
    ret
.first:
    mov dword [sched_task_started + edi * 4], 1
    cmp dword [sched_task_is_user + edi * 4], 0
    jne .first_user
    mov eax, edi
    shl eax, 12
    add eax, sched_task_stacks + SCH_STACK_SIZE - 4
    mov esp, eax
    and esp, ~0xF
    cmp dword [sched_force_yield], 0
    jne task1_main
    call rmgr_hook_leave
    cmp edi, 1
    je task1_main
    jmp task0_main
.first_user:
    call rmgr_hook_leave
    mov eax, edi
    jmp user_enter_ring3
.out:
    pop edi
    pop esi
    pop ebx
    pop ebp
    ret

scheduler_preempt_check:
    cmp dword [sched_force_yield], 0
    jne .can_preempt
    cmp dword [darkmind_busy], 0
    jne .stay_gui
    cmp dword [tinylm_busy], 0
    jne .stay_gui
.can_preempt:
    cmp dword [sched_preempt_req], 0
    je .out
    mov dword [sched_preempt_req], 0
    call scheduler_pick_next
    mov ebx, eax
    cmp ebx, [sched_current]
    je .clear_force
    cmp dword [sched_force_yield], 0
    jne .do_switch
    ; Involuntary preempt: only to equal/higher priority
    mov eax, [sched_current]
    mov ecx, [sched_task_prio + eax * 4]
    mov edx, [sched_task_prio + ebx * 4]
    cmp edx, ecx
    jl .clear_force
.do_switch:
    mov eax, ebx
    call scheduler_switch_to
.clear_force:
    mov dword [sched_force_yield], 0
    jmp .out
.stay_gui:
    mov dword [sched_current], 0
    mov dword [sched_preempt_req], 0
    mov dword [sched_task_state], SCH_STATE_RUNNING
    cmp dword [sched_task_state + 4], SCH_STATE_DEAD
    je .out
    mov dword [sched_task_state + 4], SCH_STATE_READY
.out:
    ret

task0_main:
.gui_loop:
    call scheduler_preempt_check
    call ps2_poll
    call keyboard_poll
    test al, al
    jz .gui_no_key
    mov bl, al
    mov al, bl
    call gui_handle_key
    call gui_poll
    call companion_poll
    call brain_step
    hlt
    jmp .gui_loop
.gui_no_key:
    call gui_poll
    call companion_poll
    call brain_step
    hlt
    jmp .gui_loop

task1_main:
.bg_loop:
    inc dword [sched_bg_ticks]
    call companion_poll
    call scheduler_preempt_check
    hlt
    jmp .bg_loop

scheduler_fault_kill:
    push eax
    push ebx
    mov eax, [sched_current]
    mov dword [sched_task_state + eax * 4], SCH_STATE_DEAD
    mov dword [sched_preempt_req], 1
    call scheduler_pick_next
    mov ebx, [sched_current]
    cmp eax, ebx
    je .out
    call scheduler_switch_to
.out:
    pop ebx
    pop eax
    ret

; scheduler_format_status(esi=buf) -> "task=N pre=P bg=B"
scheduler_format_status:
    push eax
    push ebx
    push ecx
    push edi
    mov edi, esi
    mov byte [edi], 't'
    mov byte [edi + 1], 'a'
    mov byte [edi + 2], 's'
    mov byte [edi + 3], 'k'
    mov byte [edi + 4], '='
    mov eax, [sched_current]
    add al, '0'
    mov [edi + 5], al
    mov byte [edi + 6], ' '
    mov byte [edi + 7], 'p'
    mov byte [edi + 8], 'r'
    mov byte [edi + 9], 'e'
    mov byte [edi + 10], '='
    mov eax, [sched_preempt_req]
    add al, '0'
    mov [edi + 11], al
    mov byte [edi + 12], ' '
    mov byte [edi + 13], 'b'
    mov byte [edi + 14], 'g'
    mov byte [edi + 15], '='
    mov eax, [sched_bg_ticks]
    lea edi, [esi + 16]
    mov ebx, 10
    xor ecx, ecx
.bg_fmt:
    xor edx, edx
    div ebx
    push edx
    inc ecx
    test eax, eax
    jnz .bg_fmt
.bg_emit:
    pop eax
    add al, '0'
    mov [edi], al
    inc edi
    loop .bg_emit
    mov byte [edi], 0
.done:
    pop edi
    pop ecx
    pop ebx
    pop eax
    ret
