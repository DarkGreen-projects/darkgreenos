; DarkgreenOS - rmgr adaptive profile (learn + tune + classify)

%include "constants.inc"

extern timer_ticks
extern rmgr_delta_free_kb
extern rmgr_delta_ticks
extern rmgr_after
extern rmgr_before
extern rmgr_current
extern rmgr_query_has_mem
extern rmgr_query_has_scan
extern rmgr_throttle_div
extern rmgr_decision
extern rmgr_reason
extern rmgr_audit_push
extern rmgr_budget_irq
extern rmgr_budget_gui
extern rmgr_budget_scan
extern rmgr_budget_chat
extern rmgr_budget_comp
extern dmem_profile_load
extern dmem_profile_write
extern rmgr_irq_kbd_count
extern rmgr_irq_mouse_count
extern rmgr_hook_enter
extern rmgr_hook_leave

global rmgr_profile_blob
global rmgr_resource_class
global rmgr_skip_osview_scan
global rmgr_last_scan_tick
global rmgr_profile_score
global rmgr_throttle_base
global rmgr_free_min_kb_eff
global rmgr_free_pct_eff
global rmgr_profile_defaults
global rmgr_profile_load
global rmgr_profile_save
global rmgr_learn_from_delta
global rmgr_tune_thresholds
global rmgr_classify_action
global rmgr_periodic_tick
global rmgr_format_status
global rmgr_current_action
global rmgr_ema_dticks_class

extern rmgr_current
extern rmgr_refresh

section .bss
align 4
rmgr_profile_blob:    resb RMGR_PROFILE_BYTES
rmgr_resource_class:  resd 1
rmgr_skip_osview_scan: resd 1
rmgr_last_scan_tick:  resd 1
rmgr_periodic_last:   resd 1
rmgr_profile_score:   resd 1
rmgr_throttle_base:   resd 1
rmgr_free_min_kb_eff: resd 1
rmgr_free_pct_eff:    resd 1
rmgr_current_action:  resd 1
rmgr_status_buf:      resb RMGR_STATUS_BYTES
rmgr_ema_dticks_class: resd 5

section .rodata
kw_gui_q:    db "gui", 0
kw_fb_q:     db "fb", 0
kw_screen_q: db "screen", 0
st_pol:      db " pol=", 0
st_thr:      db " thr=", 0
st_score:    db " score=", 0
st_free:     db " free_kb=", 0
st_budget:   db " budget=", 0
st_audit:    db " audit=", 0

extern rmgr_audit_count

section .text
rmgr_profile_defaults:
    push edi
    mov edi, rmgr_profile_blob
    mov ecx, RMGR_PROFILE_BYTES
    xor al, al
    rep stosb
    mov edi, rmgr_profile_blob
    mov dword [edi + RMGR_PROF_THROTTLE], RMGR_THROTTLE_MIN
    mov dword [edi + RMGR_PROF_FREE_MIN], RMGR_FREE_RAM_MIN_KB
    mov dword [edi + RMGR_PROF_FREE_PCT], RMGR_FREE_RAM_PCT
    mov dword [edi + RMGR_PROF_SCORE], RMGR_SCORE_INIT
    call rmgr_sync_effective
    mov dword [rmgr_skip_osview_scan], 0
    pop edi
    ret

rmgr_profile_load:
    push edi
    mov edi, rmgr_profile_blob
    call rmgr_profile_defaults
    call dmem_profile_load
    test al, al
    jz .done
    call rmgr_sync_effective
.done:
    pop edi
    ret

rmgr_profile_save:
    push esi
    mov esi, rmgr_profile_blob
    mov dword [esi], DMTP_MAGIC
    mov eax, [timer_ticks]
    mov [esi + RMGR_PROF_UPTIME], eax
    call dmem_profile_write
    pop esi
    ret

rmgr_sync_effective:
    push eax
    mov eax, [rmgr_profile_blob + RMGR_PROF_THROTTLE]
    cmp eax, RMGR_THROTTLE_MIN
    jge .t_ok
    mov eax, RMGR_THROTTLE_MIN
.t_ok:
    cmp eax, RMGR_THROTTLE_MAX
    jbe .t_cap
    mov eax, RMGR_THROTTLE_MAX
.t_cap:
    mov [rmgr_throttle_base], eax
    mov [rmgr_profile_blob + RMGR_PROF_THROTTLE], eax
    mov eax, [rmgr_profile_blob + RMGR_PROF_FREE_MIN]
    mov [rmgr_free_min_kb_eff], eax
    mov eax, [rmgr_profile_blob + RMGR_PROF_FREE_PCT]
    mov [rmgr_free_pct_eff], eax
    mov eax, [rmgr_profile_blob + RMGR_PROF_SCORE]
    mov [rmgr_profile_score], eax
    pop eax
    ret

; rmgr_classify_action(eax=action_id, esi=query or 0)
rmgr_classify_action:
    push ebx
    mov [rmgr_current_action], eax
    cmp eax, RMGR_ACTION_PERIODIC
    je .idle
    cmp eax, RMGR_ACTION_COMPANION
    je .comp
    test esi, esi
    jz .chat
    push esi
    mov edi, kw_gui_q
    call prof_contains
    test al, al
    jnz .gui_pop
    pop esi
    push esi
    mov edi, kw_fb_q
    call prof_contains
    test al, al
    jnz .gui_pop
    pop esi
    push esi
    mov edi, kw_screen_q
    call prof_contains
    test al, al
    jnz .gui_pop
    pop esi
    cmp dword [rmgr_query_has_mem], 0
    jne .mem
    cmp dword [rmgr_query_has_scan], 0
    jne .mem
    jmp .chat
.gui_pop:
    pop esi
.gui:
    mov ebx, RMGR_CLASS_GUI_PAINT
    jmp .store
.mem:
    mov ebx, RMGR_CLASS_MEM_SCAN
    jmp .store
.chat:
    mov ebx, RMGR_CLASS_USER_CHAT
    jmp .store
.comp:
    mov ebx, RMGR_CLASS_COMPANION
    jmp .store
.idle:
    mov ebx, RMGR_CLASS_IDLE
.store:
    mov [rmgr_resource_class], ebx
    mov eax, ebx
    shl eax, 2
    add eax, RMGR_PROF_CNT_IDLE
    add eax, rmgr_profile_blob
    inc dword [eax]
    pop ebx
    ret

; prof_ema_update(edi=field_offset, eax=sample)
prof_ema_update:
    push ebx
    mov ebx, [edi]
    cmp dword [rmgr_profile_blob + RMGR_PROF_ACTIONS], 1
    jbe .first
    ; ema = (old*7 + sample) / 8
    shl ebx, 3
    sub ebx, [edi]
    add ebx, eax
    shr ebx, 3
    mov [edi], ebx
    mov eax, ebx
    pop ebx
    ret
.first:
    mov [edi], eax
    pop ebx
    ret

rmgr_learn_from_delta:
    push ebx
    push edi
    mov edi, rmgr_profile_blob
    inc dword [edi + RMGR_PROF_ACTIONS]
    lea edi, [rmgr_profile_blob + RMGR_PROF_EMA_FREE]
    mov eax, [rmgr_after + RMGR_SNAP_RAM_FREE]
    call prof_ema_update
    lea edi, [rmgr_profile_blob + RMGR_PROF_EMA_DFREE]
    mov eax, [rmgr_delta_free_kb]
    call prof_ema_update
    lea edi, [rmgr_profile_blob + RMGR_PROF_EMA_DTICKS]
    mov eax, [rmgr_delta_ticks]
    call prof_ema_update
    mov eax, [rmgr_resource_class]
    cmp eax, 5
    jae .no_cls_ema
    imul eax, 4
    lea edi, [rmgr_ema_dticks_class + eax]
    mov eax, [rmgr_delta_ticks]
    call prof_ema_update
.no_cls_ema:
    mov edi, rmgr_profile_blob
    mov eax, [rmgr_delta_free_kb]
    test eax, eax
    js .bad
    mov eax, [rmgr_delta_ticks]
    cmp eax, RMGR_TICK_BUDGET
    ja .bad
    inc dword [edi + RMGR_PROF_STREAK_OK]
    mov dword [edi + RMGR_PROF_STREAK_BAD], 0
    mov eax, [edi + RMGR_PROF_SCORE]
    cmp eax, RMGR_SCORE_MAX
    jge .cool
    inc dword [edi + RMGR_PROF_SCORE]
    jmp .cool
.bad:
    inc dword [edi + RMGR_PROF_STREAK_BAD]
    mov dword [edi + RMGR_PROF_STREAK_OK], 0
    cmp dword [edi + RMGR_PROF_SCORE], 0
    je .cool
    dec dword [edi + RMGR_PROF_SCORE]
.cool:
    cmp dword [rmgr_resource_class], RMGR_CLASS_MEM_SCAN
    jne .sync
    mov eax, [timer_ticks]
    mov [rmgr_last_scan_tick], eax
.sync:
    call rmgr_update_skip_scan
    call rmgr_sync_effective
    pop edi
    pop ebx
    ret

rmgr_update_skip_scan:
    push eax
    push ebx
    mov dword [rmgr_skip_osview_scan], 0
    cmp dword [rmgr_resource_class], RMGR_CLASS_MEM_SCAN
    je .out
    mov eax, [rmgr_profile_blob + RMGR_PROF_STREAK_OK]
    cmp eax, 3
    jb .out
    mov eax, [timer_ticks]
    sub eax, [rmgr_last_scan_tick]
    cmp eax, RMGR_SCAN_COOLDOWN_TICKS
    jb .set
    jmp .out
.set:
    mov dword [rmgr_skip_osview_scan], 1
.out:
    pop ebx
    pop eax
    ret

rmgr_tune_thresholds:
    push ebx
    push edi
    mov edi, rmgr_profile_blob
    mov ebx, [edi + RMGR_PROF_STREAK_BAD]
    cmp ebx, 3
    jb .check_ok
    mov eax, [edi + RMGR_PROF_THROTTLE]
    inc eax
    cmp eax, RMGR_THROTTLE_MAX
    jbe .th_store
    mov eax, RMGR_THROTTLE_MAX
.th_store:
    mov [edi + RMGR_PROF_THROTTLE], eax
    mov eax, [edi + RMGR_PROF_FREE_MIN]
    add eax, 4096
    mov [edi + RMGR_PROF_FREE_MIN], eax
    mov eax, [edi + RMGR_PROF_FREE_PCT]
    inc eax
    cmp eax, 40
    jbe .pct_store
    mov eax, 40
.pct_store:
    mov [edi + RMGR_PROF_FREE_PCT], eax
    jmp .sync
.check_ok:
    mov ebx, [edi + RMGR_PROF_STREAK_OK]
    cmp ebx, 5
    jb .sync
    mov eax, [edi + RMGR_PROF_THROTTLE]
    cmp eax, RMGR_THROTTLE_MIN
    je .sync
    dec eax
    mov [edi + RMGR_PROF_THROTTLE], eax
    mov eax, [edi + RMGR_PROF_FREE_MIN]
    cmp eax, RMGR_FREE_RAM_MIN_KB
    jbe .sync
    sub eax, 2048
    mov [edi + RMGR_PROF_FREE_MIN], eax
.sync:
    call rmgr_tune_budgets
    call rmgr_sync_effective
    pop edi
    pop ebx
    ret

rmgr_tune_budgets:
    push eax
    push ebx
    push edi
    mov edi, rmgr_profile_blob
    mov ebx, [edi + RMGR_PROF_STREAK_BAD]
    cmp ebx, 2
    jb .grow
    mov eax, [rmgr_budget_gui]
    shr eax, 1
    mov [rmgr_budget_gui], eax
    mov eax, [rmgr_budget_scan]
    shr eax, 1
    mov [rmgr_budget_scan], eax
    jmp .done
.grow:
    mov ebx, [edi + RMGR_PROF_STREAK_OK]
    cmp ebx, 4
    jb .done
    mov eax, [rmgr_budget_gui]
    add eax, 40
    cmp eax, RMGR_BUDGET_GUI
    jbe .g_ok
    mov eax, RMGR_BUDGET_GUI
.g_ok:
    mov [rmgr_budget_gui], eax
.done:
    pop edi
    pop ebx
    pop eax
    ret

; rmgr_periodic_tick() — called from IRQ, keep minimal
rmgr_periodic_tick:
    pushad
    cmp dword [rmgr_irq_kbd_count], 0
    je .irq_mouse_sample
    mov eax, RMGR_ACT_IRQ_KEYBOARD
    call rmgr_hook_enter
    test al, al
    jz .clr_kbd_cnt
    call rmgr_hook_leave
.clr_kbd_cnt:
    mov dword [rmgr_irq_kbd_count], 0
.irq_mouse_sample:
    cmp dword [rmgr_irq_mouse_count], 0
    je .irq_done
    mov eax, RMGR_ACT_IRQ_MOUSE
    call rmgr_hook_enter
    test al, al
    jz .clr_mouse_cnt
    call rmgr_hook_leave
.clr_mouse_cnt:
    mov dword [rmgr_irq_mouse_count], 0
.irq_done:
    mov eax, RMGR_ACTION_PERIODIC
    mov [rmgr_current_action], eax
    mov dword [rmgr_resource_class], RMGR_CLASS_IDLE
    inc dword [rmgr_profile_blob + RMGR_PROF_CNT_IDLE]
    call rmgr_refresh_profile_snap
    call rmgr_learn_from_delta
    call rmgr_tune_thresholds
    cmp dword [rmgr_delta_free_kb], 0
    je .check_tick
    mov eax, [rmgr_delta_free_kb]
    cmp eax, RMGR_PERIODIC_DFREE_THRESH
    jg .significant
    neg eax
    cmp eax, RMGR_PERIODIC_DFREE_THRESH
    jbe .check_tick
.significant:
    jmp .save
.check_tick:
    mov eax, [rmgr_delta_ticks]
    cmp eax, RMGR_TICK_BUDGET
    jb .out
.save:
    call rmgr_profile_save
.out:
    popad
    ret

rmgr_refresh_profile_snap:
    ; inlined mini begin/end without report
    call rmgr_refresh
    mov esi, rmgr_current
    mov edi, rmgr_before
    mov ecx, RMGR_SNAP_WORDS
    push ecx
    rep movsd
    pop ecx
    call rmgr_refresh
    mov esi, rmgr_current
    mov edi, rmgr_after
    mov ecx, RMGR_SNAP_WORDS
    rep movsd
    mov eax, [rmgr_after + RMGR_SNAP_RAM_FREE]
    sub eax, [rmgr_before + RMGR_SNAP_RAM_FREE]
    mov [rmgr_delta_free_kb], eax
    mov eax, [rmgr_after + RMGR_SNAP_TICKS]
    sub eax, [rmgr_before + RMGR_SNAP_TICKS]
    mov [rmgr_delta_ticks], eax
    mov dword [rmgr_decision], RMGR_DEC_BALANCE
    mov dword [rmgr_reason], RMGR_REASON_OK
    call rmgr_audit_push
    ret

; rmgr_format_status() -> esi=rmgr_status_buf
rmgr_format_status:
    push eax
    push edi
    mov edi, rmgr_status_buf
    mov ecx, RMGR_STATUS_BYTES
    xor al, al
    rep stosb
    mov edi, rmgr_status_buf
    mov esi, st_free
    call prof_strcat
    mov eax, [rmgr_current + RMGR_SNAP_RAM_FREE]
    call prof_append_dec
    mov esi, st_pol
    call prof_strcat
    mov eax, [rmgr_decision]
    call prof_append_dec
    mov esi, st_thr
    call prof_strcat
    mov eax, [rmgr_throttle_div]
    call prof_append_dec
    mov esi, st_score
    call prof_strcat
    mov eax, [rmgr_profile_score]
    call prof_append_dec
    mov esi, st_budget
    call prof_strcat
    mov eax, [rmgr_budget_gui]
    call prof_append_dec
    mov esi, st_audit
    call prof_strcat
    mov eax, [rmgr_audit_count]
    call prof_append_dec
    mov esi, rmgr_status_buf
    pop edi
    pop eax
    ret

prof_contains:
    push ebx
    push edx
.outer:
    mov al, [esi]
    test al, al
    jz .no
    push esi
    push edi
.inner:
    mov bl, [edi]
    test bl, bl
    jz .yes
    mov dl, [esi]
    cmp dl, 'A'
    jb .cmp
    cmp dl, 'Z'
    ja .cmp
    add dl, 32
.cmp:
    cmp dl, bl
    jne .next
    inc esi
    inc edi
    jmp .inner
.next:
    pop edi
    pop esi
    inc esi
    jmp .outer
.yes:
    pop edi
    pop esi
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop edx
    pop ebx
    ret

prof_strcat:
    push eax
.se:
    mov al, [esi]
    test al, al
    jz .done
    mov [edi], al
    inc esi
    inc edi
    jmp .se
.done:
    pop eax
    ret

prof_append_dec:
    push ebx
    push ecx
    push edx
    mov ebx, 10
    xor ecx, ecx
.s:
    xor edx, edx
    div ebx
    push edx
    inc ecx
    test eax, eax
    jnz .s
.e:
    pop eax
    add al, '0'
    mov [edi], al
    inc edi
    loop .e
    pop edx
    pop ecx
    pop ebx
    ret
