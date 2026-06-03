; DarkgreenOS - DarkMind cooperative resource-orchestrator runtime

%include "constants.inc"

extern gui_log_line
extern gui_ai_draw_last
extern gui_draw_resource_panel
extern gui_dirty
extern osview_scan_stats
extern sysres_sync_mouse
extern dmem_init
extern dmem_append_interaction
extern rmgr_init
extern rmgr_policy_eval
extern rmgr_apply_policy
extern rmgr_get_report_line
extern rmgr_report_line_count
extern rmgr_hook_enter
extern rmgr_hook_leave
extern rmgr_skip_osview_scan
extern rmgr_classify_action
extern tinylm_busy
extern rmgr_begin_action
extern rmgr_end_action
extern rmgr_predict_eval

global darkmind_start
global darkmind_step
global darkmind_busy

section .bss
darkmind_busy:          resd 1
darkmind_emit_idx:      resd 1
darkmind_prompt:        resb DARKMIND_QUERY_MAX
darkmind_answer:        resb DARKMIND_ANSWER_MAX

section .rodata
darkmind_fallback: db "[DarkMind] query registrata (RMGR budget)", 0
darkmind_no_report: db "[DarkMind] nessun report RMGR - riprova", 0

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
    call rmgr_init
    mov eax, RMGR_ACTION_USER_QUERY
    call rmgr_hook_enter
    test al, al
    jz .denied
    mov eax, RMGR_CLASS_USER_CHAT
    call rmgr_predict_eval
    cmp dword [rmgr_skip_osview_scan], 0
    jne .policy
    mov eax, RMGR_CLASS_MEM_SCAN
    call rmgr_predict_eval
    call osview_scan_stats
.policy:
    mov esi, darkmind_prompt
    call rmgr_policy_eval
    mov eax, RMGR_ACTION_USER_QUERY
    mov esi, darkmind_prompt
    call rmgr_classify_action
    call rmgr_apply_policy
    call rmgr_hook_leave
    mov dword [darkmind_emit_idx], 0
    mov dword [darkmind_busy], 1
    pop edi
    pop esi
    pop ebx
    ret
.denied:
    mov esi, darkmind_fallback
    call gui_log_line
    mov eax, RMGR_ACTION_USER_QUERY
    call rmgr_begin_action
    call rmgr_end_action
    cmp dword [rmgr_report_line_count], 0
    jne .denied_busy
    mov esi, darkmind_no_report
    call gui_log_line
    mov dword [darkmind_busy], 0
    mov dword [tinylm_busy], 0
    pop edi
    pop esi
    pop ebx
    ret
.denied_busy:
    mov dword [darkmind_emit_idx], 0
    mov dword [darkmind_busy], 1
    pop edi
    pop esi
    pop ebx
    ret

darkmind_step:
    cmp dword [darkmind_busy], 0
    je .out
.emit_loop:
    mov eax, [darkmind_emit_idx]
    cmp eax, [rmgr_report_line_count]
    jae .finish
    call rmgr_get_report_line
    test esi, esi
    jz .finish
    push esi
    call gui_log_line
    pop esi
    inc dword [darkmind_emit_idx]
    jmp .emit_loop
.finish:
    mov esi, darkmind_prompt
    mov edi, darkmind_answer
    call darkmind_build_answer
    mov esi, darkmind_prompt
    mov edi, darkmind_answer
    call dmem_append_interaction
    call gui_draw_resource_panel
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
