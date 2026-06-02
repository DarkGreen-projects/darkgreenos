; DarkgreenOS - DarkMind resource orchestrator (metrics + policy)

%include "constants.inc"

extern mb2_total_ram_kb
extern pmm_free_kb
extern pmm_model_kb
extern os_stat_ram_kb
extern os_stat_regions
extern os_stat_kernel_bytes
extern os_stat_mapped_mb
extern sysres_fb_on
extern sysres_fb_w
extern sysres_fb_h
extern sysres_fb_bpp
extern sysres_gui_on
extern sysres_mouse_x
extern sysres_mouse_y
extern timer_ticks
extern brain_mood
extern brain_infer
extern gui_dirty
extern rmgr_profile_load
extern rmgr_profile_save
extern rmgr_learn_from_delta
extern rmgr_tune_thresholds
extern rmgr_classify_action
extern rmgr_throttle_base
extern rmgr_free_min_kb_eff
extern rmgr_free_pct_eff
extern rmgr_current_action
extern rmgr_profile_score

global rmgr_init
global rmgr_refresh
global rmgr_begin_action
global rmgr_end_action
global rmgr_policy_eval
global rmgr_apply_policy
global rmgr_format_panel
global rmgr_format_snapshot
global rmgr_get_report_line
global rmgr_report_line_count
global rmgr_decision
global rmgr_throttle_div
global rmgr_skip_redraw
global rmgr_delta_free_kb
global rmgr_delta_ticks
global rmgr_query_has_mem
global rmgr_query_has_scan
global rmgr_reason

extern rmgr_audit_push
extern rmgr_hook_init

section .bss
align 4
global rmgr_current
global rmgr_before
global rmgr_after
rmgr_current:     resd RMGR_SNAP_WORDS
rmgr_before:      resd RMGR_SNAP_WORDS
rmgr_after:       resd RMGR_SNAP_WORDS
rmgr_delta:       resd RMGR_SNAP_WORDS
rmgr_decision:    resd 1
rmgr_reason:      resd 1
rmgr_throttle_div: resd 1
rmgr_skip_redraw: resd 1
rmgr_delta_free_kb: resd 1
rmgr_delta_ticks: resd 1
rmgr_report_line_count: resd 1
rmgr_query_has_mem: resd 1
rmgr_query_has_scan: resd 1
rmgr_panel_buf:   resb RMGR_PANEL_BYTES
rmgr_snapshot_buf: resb RMGR_SNAPSHOT_BYTES
rmgr_report_lines: resb RMGR_REPORT_LINES * RMGR_REPORT_LINE_BYTES

section .rodata
panel_title:  db "Risorse live:", 0
panel_free:   db " free_kb=", 0
panel_total:  db " tot=", 0
panel_fb:     db " fb_est=", 0
panel_dec:    db " pol=", 0
panel_dfree:  db " dFree=", 0
panel_dtick:  db " dTick=", 0
panel_thr:    db " thr=", 0
panel_score:  db " score=", 0
panel_audit:  db " audit=", 0
snap_prefix: db "SNAP ", 0
snap_free:   db "free=", 0
snap_dfree:  db " dF=", 0
snap_dtick:  db " dT=", 0
snap_pol:    db " pol=", 0
snap_thr:    db " thr=", 0
snap_score:  db " score=", 0
snap_audit:  db " audit=", 0
snap_sep:    db " |", 0

extern rmgr_audit_count
extern rmgr_audit_format_line
extern rmgr_audit_append_top3

line_banner:  db "[DarkMind] orchestratore risorse kernel - misura prima/dopo ogni azione.", 0
line_before:  db "PRIMA: free_kb=", 0
line_mid1:    db " tot_kb=", 0
line_mid2:    db " fb_est_kb=", 0
line_mid3:    db " ticks=", 0
line_after:   db "DOPO: free_kb=", 0
line_delta:   db "DELTA: dFree_kb=", 0
line_dticks:  db " dTicks=", 0
line_dec:     db "DECISIONE: ", 0
dec_balance:  db "BALANCE (GUI reattiva, nessun throttle)", 0
dec_throttle: db "THROTTLE (RAM bassa: emissione rallentata)", 0
dec_cautela:  db "CAUTELA (stress sistema: lavoro minimo)", 0
dec_save_fb:  db "SAVE_FB (risparmio redraw framebuffer)", 0
dec_explain:  db "EXPLAIN (report esteso memoria/scan)", 0
line_ctx:     db "Contesto OS: ", 0
line_query:   db "Domanda: ", 0

kw_mem:       db "mem", 0
kw_map:       db "map", 0
kw_scan:      db "scan", 0
kw_ram:       db "ram", 0

section .text
rmgr_init:
    mov dword [rmgr_decision], RMGR_DEC_BALANCE
    mov eax, [rmgr_throttle_base]
    test eax, eax
    jnz .have_thr
    mov eax, RMGR_THROTTLE_MIN
.have_thr:
    mov [rmgr_throttle_div], eax
    mov dword [rmgr_skip_redraw], 0
    mov dword [rmgr_report_line_count], 0
    mov dword [rmgr_query_has_mem], 0
    mov dword [rmgr_query_has_scan], 0
    call rmgr_refresh
    ret

global rmgr_boot_init
rmgr_boot_init:
    call rmgr_hook_init
    call rmgr_profile_load
    jmp rmgr_init

; rmgr_refresh() — fill rmgr_current from live kernel metrics
rmgr_refresh:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    mov edi, rmgr_current
    mov eax, [mb2_total_ram_kb]
    test eax, eax
    jnz .have_total
    mov eax, [os_stat_ram_kb]
.have_total:
    mov [edi + RMGR_SNAP_RAM_TOTAL], eax
    mov eax, [pmm_free_kb]
    mov [edi + RMGR_SNAP_RAM_FREE], eax
    mov eax, [os_stat_kernel_bytes]
    add eax, 1023
    shr eax, 10
    mov [edi + RMGR_SNAP_KERNEL_KB], eax
    mov eax, [os_stat_regions]
    mov [edi + RMGR_SNAP_REGIONS], eax
    mov eax, [os_stat_mapped_mb]
    mov [edi + RMGR_SNAP_MAPPED_MB], eax
    mov eax, [pmm_model_kb]
    mov [edi + RMGR_SNAP_MODEL_KB], eax
    mov eax, [sysres_fb_on]
    mov [edi + RMGR_SNAP_FB_ON], eax
    mov eax, [sysres_fb_w]
    mov [edi + RMGR_SNAP_FB_W], eax
    mov eax, [sysres_fb_h]
    mov [edi + RMGR_SNAP_FB_H], eax
    mov eax, [sysres_fb_bpp]
    mov [edi + RMGR_SNAP_FB_BPP], eax
    cmp dword [edi + RMGR_SNAP_FB_ON], 0
    je .fb_zero
    mov eax, [edi + RMGR_SNAP_FB_W]
    imul eax, [edi + RMGR_SNAP_FB_H]
    imul eax, [edi + RMGR_SNAP_FB_BPP]
    shr eax, 13
    jmp .fb_store
.fb_zero:
    xor eax, eax
.fb_store:
    mov [edi + RMGR_SNAP_FB_EST_KB], eax
    mov eax, [sysres_gui_on]
    mov [edi + RMGR_SNAP_GUI_ON], eax
    mov eax, [sysres_mouse_x]
    mov [edi + RMGR_SNAP_MOUSE_X], eax
    mov eax, [sysres_mouse_y]
    mov [edi + RMGR_SNAP_MOUSE_Y], eax
    mov eax, [timer_ticks]
    mov [edi + RMGR_SNAP_TICKS], eax
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; rmgr_begin_action(eax=action_id)
rmgr_begin_action:
    push ecx
    push esi
    push edi
    mov [rmgr_current_action], eax
    call rmgr_refresh
    mov [rmgr_current + RMGR_SNAP_ACTION], eax
    mov esi, rmgr_current
    mov edi, rmgr_before
    mov ecx, RMGR_SNAP_WORDS
    rep movsd
    pop edi
    pop esi
    pop ecx
    ret

; rmgr_end_action() — snapshot after, compute deltas
rmgr_end_action:
    push ecx
    push esi
    push edi
    call rmgr_refresh
    mov esi, rmgr_current
    mov edi, rmgr_after
    mov ecx, RMGR_SNAP_WORDS
    rep movsd
    mov eax, [rmgr_after + RMGR_SNAP_RAM_FREE]
    sub eax, [rmgr_before + RMGR_SNAP_RAM_FREE]
    mov [rmgr_delta_free_kb], eax
    mov [rmgr_delta + RMGR_SNAP_RAM_FREE], eax
    mov eax, [rmgr_after + RMGR_SNAP_TICKS]
    sub eax, [rmgr_before + RMGR_SNAP_TICKS]
    mov [rmgr_delta_ticks], eax
    mov [rmgr_delta + RMGR_SNAP_TICKS], eax
    mov eax, [rmgr_after + RMGR_SNAP_FB_EST_KB]
    sub eax, [rmgr_before + RMGR_SNAP_FB_EST_KB]
    mov [rmgr_delta + RMGR_SNAP_FB_EST_KB], eax
    call rmgr_audit_push
    mov eax, [rmgr_current_action]
    cmp eax, RMGR_ACTION_USER_QUERY
    je .do_report
    cmp eax, RMGR_ACTION_COMPANION
    je .do_report
    jmp .after_report
.do_report:
    call rmgr_build_report_lines
.after_report:
    cmp eax, RMGR_ACTION_USER_QUERY
    je .do_learn
    cmp eax, RMGR_ACTION_COMPANION
    je .do_learn
    cmp eax, RMGR_ACT_OSVIEW_SCAN
    je .do_learn
    cmp eax, RMGR_ACT_PMM_ALLOC
    je .do_learn
    cmp eax, RMGR_ACT_PMM_FREE
    je .do_learn
    cmp eax, RMGR_ACT_COMPANION_CMD
    je .do_learn
    cmp eax, RMGR_ACT_IRQ_KEYBOARD
    je .do_learn
    cmp eax, RMGR_ACT_IRQ_MOUSE
    je .do_learn
    cmp eax, RMGR_ACTION_PERIODIC
    je .do_learn
    jmp .no_save
.do_learn:
    call rmgr_learn_from_delta
    call rmgr_tune_thresholds
    cmp dword [rmgr_current_action], RMGR_ACTION_USER_QUERY
    je .do_save
    jmp .no_save
.do_save:
    call rmgr_profile_save
.no_save:
    pop edi
    pop esi
    pop ecx
    ret

; rmgr_policy_eval(esi=query) -> eax=decision
rmgr_policy_eval:
    push ebx
    push esi
    mov dword [rmgr_query_has_mem], 0
    mov dword [rmgr_query_has_scan], 0
    push esi
    mov edi, kw_mem
    call rmgr_contains
    test al, al
    jnz .set_mem
    pop esi
    push esi
    mov edi, kw_map
    call rmgr_contains
    test al, al
    jnz .set_mem
    pop esi
    push esi
    mov edi, kw_ram
    call rmgr_contains
    test al, al
    jnz .set_mem
    pop esi
    jmp .mem_done
.set_mem:
    pop esi
    mov dword [rmgr_query_has_mem], 1
.mem_done:
    push esi
    mov edi, kw_scan
    call rmgr_contains
    test al, al
    jnz .set_scan
    pop esi
    jmp .scan_done
.set_scan:
    pop esi
    mov dword [rmgr_query_has_scan], 1
.scan_done:
    call brain_infer
    cmp dword [brain_mood], 2
    je .cautela
    mov eax, [rmgr_before + RMGR_SNAP_RAM_TOTAL]
    test eax, eax
    jz .check_abs
    mov ebx, [rmgr_free_pct_eff]
    mul ebx
    mov ebx, 100
    div ebx
    mov ebx, eax
    mov eax, [rmgr_before + RMGR_SNAP_RAM_FREE]
    cmp eax, ebx
    jb .throttle
    mov ebx, [rmgr_free_min_kb_eff]
    cmp eax, ebx
    jb .throttle
.check_abs:
    cmp dword [rmgr_query_has_mem], 0
    je .check_scan
    mov eax, RMGR_DEC_EXPLAIN
    jmp .set
.check_scan:
    cmp dword [rmgr_query_has_scan], 0
    je .check_fb
    mov eax, RMGR_DEC_EXPLAIN
    jmp .set
.check_fb:
    cmp dword [rmgr_before + RMGR_SNAP_FB_ON], 0
    je .balance
    mov eax, [rmgr_before + RMGR_SNAP_RAM_FREE]
    mov ebx, [rmgr_free_min_kb_eff]
    cmp eax, ebx
    jb .save_fb
.balance:
    mov eax, RMGR_DEC_BALANCE
    jmp .set
.save_fb:
    mov eax, RMGR_DEC_SAVE_FB
    jmp .set
.throttle:
    mov eax, RMGR_DEC_THROTTLE
    jmp .set
.cautela:
    mov eax, RMGR_DEC_CAUTELA
.set:
    mov [rmgr_decision], eax
    pop esi
    pop ebx
    ret

rmgr_apply_policy:
    mov eax, [rmgr_throttle_base]
    test eax, eax
    jnz .base_ok
    mov eax, RMGR_THROTTLE_MIN
.base_ok:
    mov ebx, [rmgr_decision]
    cmp ebx, RMGR_DEC_THROTTLE
    je .throttle
    cmp ebx, RMGR_DEC_CAUTELA
    je .cautela
    cmp ebx, RMGR_DEC_SAVE_FB
    je .save_fb
    mov [rmgr_throttle_div], eax
    mov dword [rmgr_skip_redraw], 0
    ret
.throttle:
    shl eax, 1
    jmp .cap
.cautela:
    shl eax, 2
    jmp .cap
.save_fb:
    inc eax
    jmp .cap
.cap:
    cmp eax, RMGR_THROTTLE_MAX
    jbe .store_thr
    mov eax, RMGR_THROTTLE_MAX
.store_thr:
    mov [rmgr_throttle_div], eax
    cmp ebx, RMGR_DEC_CAUTELA
    je .skip_on
    cmp ebx, RMGR_DEC_SAVE_FB
    je .skip_on
    mov dword [rmgr_skip_redraw], 0
    ret
.skip_on:
    mov dword [rmgr_skip_redraw], 1
    ret

; rmgr_format_panel() -> esi=rmgr_panel_buf
rmgr_format_panel:
    push eax
    push ebx
    push ecx
    push edi
    mov edi, rmgr_panel_buf
    mov ecx, RMGR_PANEL_BYTES
    xor al, al
    rep stosb
    mov edi, rmgr_panel_buf
    mov esi, panel_title
    call rmgr_strcat
    mov eax, [rmgr_current + RMGR_SNAP_RAM_FREE]
    mov esi, panel_free
    call rmgr_strcat
    call rmgr_append_dec
    mov esi, panel_total
    call rmgr_strcat
    mov eax, [rmgr_current + RMGR_SNAP_RAM_TOTAL]
    call rmgr_append_dec
    mov esi, panel_fb
    call rmgr_strcat
    mov eax, [rmgr_current + RMGR_SNAP_FB_EST_KB]
    call rmgr_append_dec
    mov esi, panel_dfree
    call rmgr_strcat
    mov eax, [rmgr_delta_free_kb]
    call rmgr_append_dec_signed
    mov esi, panel_dtick
    call rmgr_strcat
    mov eax, [rmgr_delta_ticks]
    call rmgr_append_dec_signed
    mov esi, panel_dec
    call rmgr_strcat
    mov eax, [rmgr_decision]
    call rmgr_append_dec
    mov esi, panel_thr
    call rmgr_strcat
    mov eax, [rmgr_throttle_div]
    call rmgr_append_dec
    mov esi, panel_score
    call rmgr_strcat
    mov eax, [rmgr_profile_score]
    call rmgr_append_dec
    mov esi, panel_audit
    call rmgr_strcat
    mov eax, [rmgr_audit_count]
    call rmgr_append_dec
    call rmgr_panel_seek_end
    call rmgr_audit_append_top3
    mov esi, rmgr_panel_buf
    pop edi
    pop ecx
    pop ebx
    pop eax
    ret

; rmgr_format_snapshot() -> esi=rmgr_snapshot_buf (machine-readable one line)
rmgr_format_snapshot:
    push eax
    push ebx
    push ecx
    push edi
    mov edi, rmgr_snapshot_buf
    mov ecx, RMGR_SNAPSHOT_BYTES
    xor al, al
    rep stosb
    mov edi, rmgr_snapshot_buf
    mov esi, snap_prefix
    call rmgr_strcat
    mov esi, snap_free
    call rmgr_strcat
    mov eax, [rmgr_current + RMGR_SNAP_RAM_FREE]
    call rmgr_append_dec
    mov esi, snap_dfree
    call rmgr_strcat
    mov eax, [rmgr_delta_free_kb]
    call rmgr_append_dec_signed
    mov esi, snap_dtick
    call rmgr_strcat
    mov eax, [rmgr_delta_ticks]
    call rmgr_append_dec_signed
    mov esi, snap_pol
    call rmgr_strcat
    mov eax, [rmgr_decision]
    call rmgr_append_dec
    mov esi, snap_thr
    call rmgr_strcat
    mov eax, [rmgr_throttle_div]
    call rmgr_append_dec
    mov esi, snap_score
    call rmgr_strcat
    mov eax, [rmgr_profile_score]
    call rmgr_append_dec
    mov esi, snap_audit
    call rmgr_strcat
    mov eax, [rmgr_audit_count]
    call rmgr_append_dec
    xor ecx, ecx
.snap_loop:
    cmp ecx, 3
    jae .snap_done
    push ecx
    mov eax, ecx
    call rmgr_audit_format_line
    test esi, esi
    jz .snap_pop
    push esi
    call rmgr_panel_seek_end
    mov esi, snap_sep
    call rmgr_strcat
    pop esi
    push esi
    call rmgr_strcat
    pop esi
.snap_pop:
    pop ecx
    inc ecx
    jmp .snap_loop
.snap_done:
    mov esi, rmgr_snapshot_buf
    pop edi
    pop ecx
    pop ebx
    pop eax
    ret

; rmgr_get_report_line(eax=index) -> esi=line ptr or 0
rmgr_get_report_line:
    cmp eax, [rmgr_report_line_count]
    jae .none
    imul eax, RMGR_REPORT_LINE_BYTES
    lea esi, [rmgr_report_lines + eax]
    ret
.none:
    xor esi, esi
    ret

rmgr_build_report_lines:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    mov dword [rmgr_report_line_count], 0
    mov ebx, 0
    call rmgr_store_line_ro
    mov ebx, 1
    mov edi, line_before
    call rmgr_store_line_metrics_before
    mov ebx, 2
    mov edi, line_after
    call rmgr_store_line_metrics_after
    mov ebx, 3
    call rmgr_store_line_delta
    mov ebx, 4
    call rmgr_store_line_decision
    cmp dword [rmgr_query_has_mem], 0
    je .no_extra
    mov ebx, 5
    mov edi, line_ctx
    call rmgr_store_line_ctx_hint
.no_extra:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

rmgr_store_line_ro:
    push esi
    call rmgr_line_slot
    mov esi, line_banner
    call rmgr_strcat_edi
    pop esi
    ret

rmgr_store_line_metrics_before:
    push edi
    call rmgr_line_slot
    mov esi, line_before
    call rmgr_strcat_edi
    mov eax, [rmgr_before + RMGR_SNAP_RAM_FREE]
    call rmgr_append_dec_edi
    mov esi, line_mid1
    call rmgr_strcat_edi
    mov eax, [rmgr_before + RMGR_SNAP_RAM_TOTAL]
    call rmgr_append_dec_edi
    mov esi, line_mid2
    call rmgr_strcat_edi
    mov eax, [rmgr_before + RMGR_SNAP_FB_EST_KB]
    call rmgr_append_dec_edi
    mov esi, line_mid3
    call rmgr_strcat_edi
    mov eax, [rmgr_before + RMGR_SNAP_TICKS]
    call rmgr_append_dec_edi
    pop edi
    ret

rmgr_store_line_metrics_after:
    push edi
    call rmgr_line_slot
    mov esi, line_after
    call rmgr_strcat_edi
    mov eax, [rmgr_after + RMGR_SNAP_RAM_FREE]
    call rmgr_append_dec_edi
    mov esi, line_mid1
    call rmgr_strcat_edi
    mov eax, [rmgr_after + RMGR_SNAP_RAM_TOTAL]
    call rmgr_append_dec_edi
    mov esi, line_mid2
    call rmgr_strcat_edi
    mov eax, [rmgr_after + RMGR_SNAP_FB_EST_KB]
    call rmgr_append_dec_edi
    mov esi, line_mid3
    call rmgr_strcat_edi
    mov eax, [rmgr_after + RMGR_SNAP_TICKS]
    call rmgr_append_dec_edi
    pop edi
    ret

rmgr_store_line_delta:
    push edi
    call rmgr_line_slot
    mov esi, line_delta
    call rmgr_strcat_edi
    mov eax, [rmgr_delta_free_kb]
    call rmgr_append_dec_signed_edi
    mov esi, line_dticks
    call rmgr_strcat_edi
    mov eax, [rmgr_delta_ticks]
    call rmgr_append_dec_signed_edi
    pop edi
    ret

rmgr_store_line_decision:
    push edi
    call rmgr_line_slot
    mov esi, line_dec
    call rmgr_strcat_edi
    mov eax, [rmgr_decision]
    cmp eax, RMGR_DEC_THROTTLE
    je .t
    cmp eax, RMGR_DEC_CAUTELA
    je .c
    cmp eax, RMGR_DEC_SAVE_FB
    je .s
    cmp eax, RMGR_DEC_EXPLAIN
    je .e
    mov esi, dec_balance
    jmp .copy
.t:
    mov esi, dec_throttle
    jmp .copy
.c:
    mov esi, dec_cautela
    jmp .copy
.s:
    mov esi, dec_save_fb
    jmp .copy
.e:
    mov esi, dec_explain
.copy:
    call rmgr_strcat_edi
    pop edi
    ret

rmgr_store_line_ctx_hint:
    push edi
    call rmgr_line_slot
    mov esi, line_ctx
    call rmgr_strcat_edi
    mov esi, hint_mem
    call rmgr_strcat_edi
    pop edi
    ret

hint_mem: db "usa mem/map/scan; orchestratore adattivo (nessun LLM in kernel).", 0

rmgr_line_slot:
    mov eax, ebx
    imul eax, RMGR_REPORT_LINE_BYTES
    add eax, rmgr_report_lines
    mov edi, eax
    mov ecx, RMGR_REPORT_LINE_BYTES
    xor al, al
    push edi
    rep stosb
    pop edi
    inc dword [rmgr_report_line_count]
    ret

rmgr_contains:
    push ebx
    push edx
    push esi
    push edi
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
    pop edi
    pop esi
    pop edx
    pop ebx
    ret

rmgr_strcat:
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

rmgr_strcat_edi:
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

rmgr_append_dec:
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

rmgr_append_dec_edi:
    jmp rmgr_append_dec

rmgr_append_dec_signed:
    test eax, eax
    jns rmgr_append_dec
    push eax
    mov al, '-'
    mov [edi], al
    inc edi
    pop eax
    neg eax
    jmp rmgr_append_dec

rmgr_append_dec_signed_edi:
    jmp rmgr_append_dec_signed

; edi = rmgr_panel_buf, seek to end of string
rmgr_panel_seek_end:
    push eax
.seek:
    cmp byte [edi], 0
    je .done
    inc edi
    jmp .seek
.done:
    pop eax
    ret
