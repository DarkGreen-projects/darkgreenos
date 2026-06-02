; DarkgreenOS - RMGR universal hooks (enter/leave/budget)

%include "constants.inc"

extern rmgr_begin_action
extern rmgr_end_action
extern rmgr_refresh
extern rmgr_current_action
extern rmgr_decision
extern rmgr_reason
extern rmgr_skip_osview_scan
extern rmgr_skip_redraw
extern rmgr_delta_ticks
extern rmgr_profile_score
extern rmgr_free_min_kb_eff
extern pmm_free_kb
extern rmgr_before
extern rmgr_audit_push
extern rmgr_learn_from_delta
extern rmgr_tune_thresholds
extern rmgr_classify_action
extern rmgr_ema_dticks_class

global rmgr_hook_init
global rmgr_irq_kbd_count
global rmgr_irq_mouse_count
global rmgr_hook_enter
global rmgr_hook_leave
global rmgr_budget_ok
global rmgr_budget_irq
global rmgr_budget_gui
global rmgr_budget_scan
global rmgr_budget_chat
global rmgr_hook_active

section .bss
rmgr_hook_active: resd 1
rmgr_hook_depth:  resd 1
rmgr_irq_kbd_count: resd 1
rmgr_irq_mouse_count: resd 1
rmgr_budget_irq:  resd 1
rmgr_budget_gui:  resd 1
rmgr_budget_scan: resd 1
rmgr_budget_chat: resd 1
rmgr_budget_comp: resd 1
rmgr_budget_pmm:  resd 1

section .text
rmgr_hook_init:
    xor eax, eax
    mov [rmgr_hook_active], eax
    mov [rmgr_hook_depth], eax
    mov [rmgr_irq_kbd_count], eax
    mov [rmgr_irq_mouse_count], eax
    mov [rmgr_audit_count], eax
    mov [rmgr_audit_head], eax
    jmp rmgr_hook_init_budgets

extern rmgr_audit_count
extern rmgr_audit_head

rmgr_hook_init_budgets:
    mov dword [rmgr_budget_irq], RMGR_BUDGET_IRQ
    mov dword [rmgr_budget_gui], RMGR_BUDGET_GUI
    mov dword [rmgr_budget_scan], RMGR_BUDGET_SCAN
    mov dword [rmgr_budget_chat], RMGR_BUDGET_CHAT
    mov dword [rmgr_budget_comp], RMGR_BUDGET_COMP
    mov dword [rmgr_budget_pmm], RMGR_BUDGET_PMM
    ret

; rmgr_budget_ok(eax=action) -> al=1 allow, 0 deny
rmgr_budget_ok:
    push ebx
    push ecx
    push edx
    mov ebx, eax
    mov dword [rmgr_reason], RMGR_REASON_OK
    cmp ebx, RMGR_ACT_OSVIEW_SCAN
    jne .not_scan
    cmp dword [rmgr_skip_osview_scan], 0
    je .not_scan
    mov dword [rmgr_reason], RMGR_REASON_SKIP_SCAN
    mov dword [rmgr_decision], RMGR_DEC_CAUTELA
    xor al, al
    jmp .out
.not_scan:
    mov eax, [pmm_free_kb]
    cmp eax, [rmgr_free_min_kb_eff]
    jae .have_ram
    cmp ebx, RMGR_ACTION_USER_QUERY
    je .have_ram
    mov dword [rmgr_reason], RMGR_REASON_LOW_RAM
    mov dword [rmgr_decision], RMGR_DEC_THROTTLE
    xor al, al
    jmp .out
.have_ram:
    mov ecx, [rmgr_budget_irq]
    cmp ebx, RMGR_ACT_IRQ_KEYBOARD
    je .allow_irq
    cmp ebx, RMGR_ACT_IRQ_MOUSE
    je .allow_irq
    cmp ebx, RMGR_ACT_GUI_REDRAW
    je .gui_b
    cmp ebx, RMGR_ACT_GUI_LOG
    je .gui_b
    cmp ebx, RMGR_ACT_OSVIEW_SCAN
    je .scan_b
    cmp ebx, RMGR_ACTION_USER_QUERY
    je .chat_b
    cmp ebx, RMGR_ACT_COMPANION_CMD
    je .comp_b
    cmp ebx, RMGR_ACT_PMM_ALLOC
    je .pmm_b
    cmp ebx, RMGR_ACT_PMM_FREE
    je .pmm_b
    cmp ebx, RMGR_ACT_PAGE_FAULT
    je .ok_al
    cmp ebx, RMGR_ACT_GPF
    je .ok_al
    mov al, 1
    jmp .out
.gui_b:
    mov ecx, [rmgr_budget_gui]
    jmp .chk
.scan_b:
    mov ecx, [rmgr_budget_scan]
    jmp .chk
.chat_b:
    mov ecx, [rmgr_budget_chat]
    jmp .chk
.comp_b:
    mov ecx, [rmgr_budget_comp]
    jmp .chk
.pmm_b:
    mov ecx, [rmgr_budget_pmm]
    jmp .chk
.chk:
    mov eax, [rmgr_profile_score]
    cmp eax, 128
    jge .ok_al
    shr ecx, 1
    test ecx, ecx
    jnz .ok_al
    mov ecx, 1
.ok_al:
    mov eax, ebx
    call rmgr_action_class_idx
    shl eax, 2
    add eax, rmgr_ema_dticks_class
    mov edx, [eax]
    test edx, edx
    jz .allow
    cmp edx, ecx
    jbe .allow
    mov dword [rmgr_reason], RMGR_REASON_BUDGET_DENY
    mov dword [rmgr_decision], RMGR_DEC_CAUTELA
    xor al, al
    jmp .out
.allow_irq:
    mov al, 1
    jmp .out
.allow:
    mov al, 1
    jmp .out
.out:
    pop edx
    pop ecx
    pop ebx
    ret

; eax=action -> eax=class 0..4 for EMA budget
rmgr_action_class_idx:
    cmp eax, RMGR_ACT_IRQ_KEYBOARD
    je .idle
    cmp eax, RMGR_ACT_IRQ_MOUSE
    je .idle
    cmp eax, RMGR_ACT_GUI_REDRAW
    je .gui
    cmp eax, RMGR_ACT_GUI_LOG
    je .gui
    cmp eax, RMGR_ACT_OSVIEW_SCAN
    je .mem
    cmp eax, RMGR_ACT_PMM_ALLOC
    je .mem
    cmp eax, RMGR_ACT_PMM_FREE
    je .mem
    cmp eax, RMGR_ACTION_USER_QUERY
    je .chat
    cmp eax, RMGR_ACT_COMPANION_CMD
    je .comp
    cmp eax, RMGR_ACTION_COMPANION
    je .comp
    cmp eax, RMGR_ACTION_PERIODIC
    je .idle
.idle:
    xor eax, eax
    ret
.chat:
    mov eax, RMGR_CLASS_USER_CHAT
    ret
.mem:
    mov eax, RMGR_CLASS_MEM_SCAN
    ret
.gui:
    mov eax, RMGR_CLASS_GUI_PAINT
    ret
.comp:
    mov eax, RMGR_CLASS_COMPANION
    ret

; rmgr_hook_enter(eax=action) -> al=1 started, 0 denied
rmgr_hook_enter:
    push ebx
    mov ebx, eax
    cmp dword [rmgr_hook_depth], 0
    je .top
    inc dword [rmgr_hook_depth]
    mov al, 1
    jmp .done
.top:
    call rmgr_budget_ok
    test al, al
    jz .deny
    mov eax, ebx
    call rmgr_begin_action
    mov dword [rmgr_hook_active], 1
    mov dword [rmgr_hook_depth], 1
    mov al, 1
    jmp .done
.deny:
    cmp ebx, RMGR_ACT_GUI_REDRAW
    jne .no_defer
    mov dword [rmgr_reason], RMGR_REASON_DEFER_REDRAW
    mov dword [gui_dirty], 1
.no_defer:
    xor al, al
.done:
    pop ebx
    ret

extern gui_dirty

; rmgr_hook_leave() — end action, audit, conditional learn
rmgr_hook_leave:
    cmp dword [rmgr_hook_depth], 0
    je .out
    dec dword [rmgr_hook_depth]
    jnz .out
    mov dword [rmgr_hook_active], 0
    call rmgr_end_action
.out:
    ret
