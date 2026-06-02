; DarkgreenOS - DarkMind cooperative resource-orchestrator runtime

%include "constants.inc"

extern gui_log_line
extern gui_dirty
extern brain_refresh
extern osview_scan_stats
extern sysres_sync_mouse
extern dmem_init
extern dmem_append_interaction
extern rmgr_init
extern rmgr_policy_eval
extern rmgr_apply_policy
extern rmgr_get_report_line
extern rmgr_hook_enter
extern rmgr_hook_leave
extern rmgr_skip_osview_scan
extern gui_panel_refresh
extern rmgr_classify_action
extern timer_ticks
extern rmgr_throttle_div
extern rmgr_skip_redraw
extern tinylm_busy

global darkmind_start
global darkmind_step
global darkmind_busy

section .bss
darkmind_busy:          resd 1
darkmind_emit_idx:      resd 1
darkmind_emit_last:     resd 1
darkmind_prompt:        resb DARKMIND_QUERY_MAX
darkmind_answer:        resb DARKMIND_ANSWER_MAX

section .text
; darkmind_start(esi=query)
darkmind_start:
    push ebx
    push esi
    push edi
    mov edi, darkmind_prompt
    mov ecx, DARKMIND_QUERY_MAX - 1
.copy:
    test ecx, ecx
    jz .copied
    lodsb
    test al, al
    jz .copied
    mov [edi], al
    inc edi
    dec ecx
    jmp .copy
.copied:
    mov byte [edi], 0
    call dmem_init
    call sysres_sync_mouse
    call brain_refresh
    call rmgr_init
    mov eax, RMGR_ACTION_USER_QUERY
    call rmgr_hook_enter
    test al, al
    jz .no_hook
    cmp dword [rmgr_skip_osview_scan], 0
    jne .policy
    call osview_scan_stats
.policy:
    mov esi, darkmind_prompt
    call rmgr_policy_eval
    mov eax, RMGR_ACTION_USER_QUERY
    mov esi, darkmind_prompt
    call rmgr_classify_action
    call rmgr_apply_policy
    call rmgr_hook_leave
.no_hook:
    mov dword [darkmind_emit_idx], 0
    mov dword [darkmind_emit_last], 0xFFFFFFFF
    mov dword [darkmind_busy], 1
    pop edi
    pop esi
    pop ebx
    ret

darkmind_step:
    cmp dword [darkmind_busy], 0
    je .out
    mov eax, [timer_ticks]
    xor edx, edx
    mov ecx, [rmgr_throttle_div]
    test ecx, ecx
    jnz .div_ok
    mov ecx, 1
.div_ok:
    div ecx
    test edx, edx
    jnz .out
    cmp eax, [darkmind_emit_last]
    je .out
    mov [darkmind_emit_last], eax
    mov eax, [darkmind_emit_idx]
    call rmgr_get_report_line
    test esi, esi
    jz .finish
    push esi
    mov eax, RMGR_ACT_GUI_LOG
    call rmgr_hook_enter
    test al, al
    jnz .log_ok
    pop esi
    jmp .out
.log_ok:
    pop esi
    push esi
    call gui_log_line
    call rmgr_hook_leave
    inc dword [darkmind_emit_idx]
    jmp .out
.finish:
    mov esi, darkmind_prompt
    mov edi, darkmind_answer
    call darkmind_build_answer
    mov esi, darkmind_prompt
    mov edi, darkmind_answer
    call dmem_append_interaction
    cmp dword [rmgr_skip_redraw], 0
    je .refresh
    mov dword [rmgr_skip_redraw], 0
    jmp .done_busy
.refresh:
    call gui_panel_refresh
    mov dword [gui_dirty], 1
.done_busy:
    mov dword [darkmind_busy], 0
    mov dword [tinylm_busy], 0
.out:
    ret

darkmind_build_answer:
    push eax
    push ebx
    push ecx
    push esi
    push edi
    mov edi, darkmind_answer
    mov ecx, DARKMIND_ANSWER_MAX
    xor al, al
    rep stosb
    mov edi, darkmind_answer
    lea ebx, [darkmind_answer + DARKMIND_ANSWER_MAX - 2]
    xor ecx, ecx
.line_loop:
    mov eax, ecx
    call rmgr_get_report_line
    test esi, esi
    jz .done
    call strcat_edi_bounded
    cmp edi, ebx
    jae .done
    mov al, ' '
    mov [edi], al
    inc edi
    inc ecx
    jmp .line_loop
.done:
    mov byte [edi], 0
    pop edi
    pop esi
    pop ecx
    pop ebx
    pop eax
    ret

strcat_edi_bounded:
    push eax
    push ebx
    lea ebx, [darkmind_answer + DARKMIND_ANSWER_MAX - 1]
.seek:
    cmp edi, ebx
    jae .done
    cmp byte [edi], 0
    je .c
    inc edi
    jmp .seek
.c:
    mov al, [esi]
    test al, al
    jz .done
    cmp edi, ebx
    jae .done
    stosb
    inc esi
    jmp .c
.done:
    pop ebx
    pop eax
    ret
