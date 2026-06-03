; DarkgreenOS - Companion core (runtime-adaptive agent + serial protocol)

%include "constants.inc"

extern serial_init
extern serial_write
extern serial_writeln
extern serial_rx_ready
extern serial_rx
extern vga_print
extern vga_print_ln
extern vga_clear
extern vga_set_color
extern print_dec
extern timer_ticks
extern brain_think
extern mb_print_map
extern osview_print_kernel_map
extern osview_find
extern osview_dump
extern brain_refresh
extern gui_redraw
extern gui_log_line
extern gui_show_resources
extern fb_active
extern sysres_fb_w
extern sysres_fb_h
extern sysres_fb_on
extern sysres_mouse_x
extern sysres_mouse_y
extern rmgr_refresh
extern rmgr_format_panel
extern rmgr_decision
extern rmgr_delta_free_kb
extern rmgr_delta_ticks
extern rmgr_throttle_div
extern rmgr_profile_score
extern rmgr_throttle_base
extern rmgr_free_min_kb_eff
extern dmem_profile_export
extern dmem_init
extern sysres_mouse_btn
extern rmgr_audit_format_line
extern rmgr_audit_count
extern rmgr_hook_enter
extern rmgr_hook_leave
extern rmgr_format_snapshot
extern rmgr_format_status
extern rmgr_status_buf
extern pmm_alloc_kb
extern pmm_free_all
extern pmm_free_ptr
extern pmm_alloc_used_kb
extern fs_open
extern fs_read
extern fs_close
extern scheduler_yield
extern task_spawn_user
extern fs_sync
extern fs_save_profile
extern fs_deferred_profile_load
extern rmgr_profile_blob
extern err_ring_format
extern err_ring_clear
extern rmgr_budget_gui
extern scheduler_format_status
extern sched_current
extern print_hex32
extern vga_putchar

global companion_init
global companion_poll
global companion_exec_line

section .data
companion_name:
    db "DarkMind", 0
    times COMPANION_NAME_MAX - 9 db 0
companion_mood:
    db "curious", 0
    times 32 - 8 db 0
companion_persona:
    db "Adaptive kernel companion. I change while DarkgreenOS runs.", 0
    times COMPANION_PERSONA_MAX - 54 db 0

msg_boot:       db "[DarkMind] internal LLM core - full OS read access", 0
msg_help:       db "SNAPSHOT STATS POLICY PROFILE AUDIT ALLOC FREE TASKS YIELD CAT THINK ...", 0
msg_ok:         db "OK", 0
msg_err:        db "ERR unknown command", 0
msg_pong:       db "PONG DarkgreenOS", 0
prefix_out:     db "[Companion] ", 0
label_name:     db "name=", 0
label_mood:     db " mood=", 0
label_persona:  db " persona=", 0
label_ticks:    db "ticks=", 0

section .bss
serial_cmd_buf:     resb COMPANION_CMD_MAX
serial_cmd_len:     resd 1
sched_status_buf:   resb 64
cat_read_buf:       resb 128
err_line_buf:       resb 64

section .rodata
kw_help:    db "help", 0
kw_ping:    db "ping", 0
kw_status:  db "status", 0
kw_say:     db "say", 0
kw_color:   db "color", 0
kw_mood:    db "mood", 0
kw_name:    db "name", 0
kw_patch:   db "patch", 0
kw_persona: db "persona", 0
kw_ticks:   db "ticks", 0
kw_clear:   db "clear", 0
kw_think:   db "think", 0
kw_map:     db "map", 0
kw_files:   db "files", 0
kw_find:    db "find", 0
kw_dump:    db "dump", 0
kw_scan:    db "scan", 0
kw_gui:     db "gui", 0
kw_mouse:   db "mouse", 0
kw_fb:      db "fb", 0
kw_redraw:  db "redraw", 0
kw_stats:   db "stats", 0
kw_policy:  db "policy", 0
kw_profile: db "profile", 0
kw_profex:  db "profile export", 0
kw_llm:     db "llm", 0
kw_audit:   db "audit", 0
kw_alloc:   db "alloc", 0
kw_free:    db "free", 0
kw_tasks:   db "tasks", 0
kw_yield:   db "yield", 0
kw_run:     db "run", 0
kw_sync:    db "sync", 0
kw_errors:  db "errors", 0
kw_errclr:  db "errors clear", 0
kw_pset:    db "policy set ", 0
kw_cat:     db "cat", 0
kw_snapshot: db "snapshot", 0
kw_hello:   db "hello", 0
kw_ciao:    db "ciao", 0
reply_hi:   db "Ciao! Sono nel kernel con te.", 0
reply_def:  db "Elaboro. Posso mutare nome/mood/persona in RAM.", 0

section .text
companion_init:
    call serial_init
    mov dword [serial_cmd_len], 0
    mov al, COLOR_DIM_GREEN
    call vga_set_color
    mov esi, msg_boot
    call vga_print_ln
    call serial_writeln
.drain:
    call serial_rx_ready
    test al, al
    jz .drained
    call serial_rx
    jmp .drain
.drained:
    mov dword [serial_cmd_len], 0
    ret

companion_poll:
    call fs_deferred_profile_load
    call serial_rx_ready
    test al, al
    jz .ret
    call serial_rx
    cmp al, 13
    je .ret
    cmp al, 10
    je .exec
    mov ecx, [serial_cmd_len]
    cmp ecx, COMPANION_CMD_MAX - 2
    jae .ret
    mov [serial_cmd_buf + ecx], al
    inc ecx
    mov [serial_cmd_len], ecx
    ret
.exec:
    mov ecx, [serial_cmd_len]
    test ecx, ecx
    jz .ret
    ; strip trailing CR (TCP often sends CRLF)
.strip_cr:
    dec ecx
    js .ret
    cmp byte [serial_cmd_buf + ecx], 13
    je .strip_cr
    inc ecx
    mov byte [serial_cmd_buf + ecx], 0
    mov [serial_cmd_len], ecx
    mov esi, serial_cmd_buf
    call companion_exec_line
    mov dword [serial_cmd_len], 0
.ret:
    ret

companion_exec_line:
    push esi
    call cmd_ping
    test al, al
    jnz .done
    call cmd_cat
    test al, al
    jnz .done
    call cmd_help
    test al, al
    jnz .done
    call cmd_status
    test al, al
    jnz .done
    call cmd_say
    test al, al
    jnz .done
    call cmd_color
    test al, al
    jnz .done
    call cmd_mood
    test al, al
    jnz .done
    call cmd_name
    test al, al
    jnz .done
    call cmd_patch
    test al, al
    jnz .done
    call cmd_ticks
    test al, al
    jnz .done
    call cmd_clear
    test al, al
    jnz .done
    call cmd_map
    test al, al
    jnz .done
    call cmd_files
    test al, al
    jnz .done
    call cmd_find
    test al, al
    jnz .done
    call cmd_dump
    test al, al
    jnz .done
    call cmd_scan
    test al, al
    jnz .done
    call cmd_gui
    test al, al
    jnz .done
    call cmd_mouse
    test al, al
    jnz .done
    call cmd_fb
    test al, al
    jnz .done
    call cmd_redraw
    test al, al
    jnz .done
    call cmd_snapshot
    test al, al
    jnz .done
    call cmd_stats
    test al, al
    jnz .done
    call cmd_policy
    test al, al
    jnz .done
    call cmd_profile_export
    test al, al
    jnz .done
    call cmd_profile
    test al, al
    jnz .done
    call cmd_llm_stub
    test al, al
    jnz .done
    call cmd_audit
    test al, al
    jnz .done
    call cmd_alloc
    test al, al
    jnz .done
    call cmd_pmm_free
    test al, al
    jnz .done
    call cmd_tasks
    test al, al
    jnz .done
    call cmd_yield
    test al, al
    jnz .done
    call cmd_run
    test al, al
    jnz .done
    call cmd_sync
    test al, al
    jnz .done
    call cmd_errors_clear
    test al, al
    jnz .done
    call cmd_errors
    test al, al
    jnz .done
    call cmd_policy_set
    test al, al
    jnz .done
    call cmd_think
    test al, al
    jnz .done
    mov esi, msg_err
    call companion_reply
.done:
    pop esi
    ret

; companion_reply(esi) -> VGA + serial
companion_reply:
    push esi
    call serial_writeln
    pop esi
    mov al, COLOR_DARKGREEN
    call vga_set_color
    mov edi, prefix_out
    push esi
    mov esi, edi
    call vga_print
    pop esi
    call vga_print_ln
    ret

companion_reply_ok:
    mov esi, msg_ok
    call serial_writeln
    ret

companion_show_status:
    mov al, COLOR_DIM_GREEN
    call vga_set_color
    mov esi, prefix_out
    call vga_print
    mov esi, label_name
    call vga_print
    mov esi, companion_name
    call vga_print
    mov esi, label_mood
    call vga_print
    mov esi, companion_mood
    call vga_print
    mov esi, label_persona
    call vga_print
    mov esi, companion_persona
    call vga_print_ln
    ret

; streq_prefix: esi=line, edi=keyword -> al=1, esi past keyword
streq_prefix:
    push ebx
.loop:
    mov al, [edi]
    test al, al
    jz .endkw
    mov bl, [esi]
    cmp al, bl
    jne .fail
    inc esi
    inc edi
    jmp .loop
.endkw:
    mov al, [esi]
    cmp al, 0
    je .ok
    cmp al, ' '
    je .ok
    cmp al, 9
    je .ok
    cmp al, '|'
    je .ok
.fail:
    xor al, al
    jmp .out
.ok:
    mov al, 1
.out:
    pop ebx
    ret

skip_spaces:
    push eax
.sp:
    lodsb
    cmp al, ' '
    je .sp
    cmp al, 9
    je .sp
    dec esi
    pop eax
    ret

strcopy:
    push eax
    push edi
    push esi
.cp:
    test ecx, ecx
    jz .done
    lodsb
    test al, al
    jz .done
    stosb
    dec ecx
    jmp .cp
.done:
    mov byte [edi], 0
    pop esi
    pop edi
    pop eax
    ret

substring:
    push esi
    push edi
    push ebx
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
    cmp al, bl
    jne .next
    inc esi
    inc edi
    mov al, [esi]
    jmp .inner
.next:
    pop edi
    pop esi
    inc esi
    jmp .outer
.yes:
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop ebx
    pop edi
    pop esi
    ret

hex2byte:
    push ebx
    call hex_nibble
    jc .bad
    mov bl, al
    inc esi
    call hex_nibble
    jc .bad
    shl bl, 4
    or al, bl
    clc
    jmp .done
.bad:
    stc
.done:
    pop ebx
    ret

hex_nibble:
    mov al, [esi]
    cmp al, '0'
    jb .bad
    cmp al, '9'
    jbe .d
    or al, 0x20
    cmp al, 'a'
    jb .bad
    cmp al, 'f'
    ja .bad
    sub al, 'a' - 10
    clc
    ret
.d:
    sub al, '0'
    clc
    ret
.bad:
    stc
    ret

cmd_ping:
    push esi
    mov esi, serial_cmd_buf
    mov edi, kw_ping
    call streq_prefix
    test al, al
    jz .no
    mov esi, msg_pong
    call companion_reply
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop esi
    ret

cmd_help:
    push esi
    mov esi, serial_cmd_buf
    mov edi, kw_help
    call streq_prefix
    test al, al
    jz .no
    mov esi, msg_help
    call companion_reply
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop esi
    ret

cmd_status:
    push esi
    mov edi, kw_status
    call streq_prefix
    test al, al
    jz .no
    call companion_show_status
    call companion_reply_ok
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop esi
    ret

cmd_say:
    push esi
    mov edi, kw_say
    call streq_prefix
    test al, al
    jz .no
    call skip_spaces
    call companion_reply
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop esi
    ret

cmd_color:
    push esi
    mov edi, kw_color
    call streq_prefix
    test al, al
    jz .no
    call skip_spaces
    call hex2byte
    jc .no
    call vga_set_color
    call companion_reply_ok
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop esi
    ret

cmd_mood:
    push esi
    push edi
    mov edi, kw_mood
    call streq_prefix
    test al, al
    jz .no
    call skip_spaces
    mov edi, companion_mood
    mov ecx, 31
    call strcopy
    call companion_reply_ok
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop edi
    pop esi
    ret

cmd_name:
    push esi
    push edi
    mov edi, kw_name
    call streq_prefix
    test al, al
    jz .no
    call skip_spaces
    mov edi, companion_name
    mov ecx, COMPANION_NAME_MAX - 1
    call strcopy
    call companion_reply_ok
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop edi
    pop esi
    ret

cmd_patch:
    push esi
    push edi
    mov edi, kw_patch
    call streq_prefix
    test al, al
    jz .no
    call skip_spaces
    mov edi, kw_persona
    push esi
    call streq_prefix
    pop esi
    test al, al
    jnz .persona
    mov edi, kw_name
    push esi
    call streq_prefix
    pop esi
    test al, al
    jnz .name
    jmp .no
.persona:
    cmp byte [esi], '|'
    jne .no
    inc esi
    mov edi, companion_persona
    mov ecx, COMPANION_PERSONA_MAX - 1
    call strcopy
    jmp .ok
.name:
    cmp byte [esi], '|'
    jne .no
    inc esi
    mov edi, companion_name
    mov ecx, COMPANION_NAME_MAX - 1
    call strcopy
.ok:
    call companion_show_status
    call companion_reply_ok
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop edi
    pop esi
    ret

cmd_ticks:
    push esi
    mov edi, kw_ticks
    call streq_prefix
    test al, al
    jz .no
    mov esi, label_ticks
    call vga_print
    mov eax, [timer_ticks]
    call print_dec
    call vga_print_ln
    call companion_reply_ok
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop esi
    ret

cmd_clear:
    push esi
    mov edi, kw_clear
    call streq_prefix
    test al, al
    jz .no
    call vga_clear
    call companion_reply_ok
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop esi
    ret

cmd_map:
    push esi
    mov edi, kw_map
    call streq_prefix
    test al, al
    jz .no
    call mb_print_map
    call companion_reply_ok
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop esi
    ret

cmd_files:
    push esi
    mov edi, kw_files
    call streq_prefix
    test al, al
    jz .no
    call osview_print_kernel_map
    call companion_reply_ok
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop esi
    ret

cmd_find:
    push esi
    mov edi, kw_find
    call streq_prefix
    test al, al
    jz .no
    call skip_spaces
    call osview_find
    call companion_reply_ok
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop esi
    ret

cmd_dump:
    push esi
    mov edi, kw_dump
    call streq_prefix
    test al, al
    jz .no
    call skip_spaces
    call osview_dump
    call companion_reply_ok
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop esi
    ret

cmd_scan:
    push esi
    mov edi, kw_scan
    call streq_prefix
    test al, al
    jz .no
    call brain_refresh
    mov esi, brain_ctx
    call companion_reply
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop esi
    ret

extern brain_ctx

cmd_gui:
    push esi
    mov edi, kw_gui
    call streq_prefix
    test al, al
    jz .no
    call gui_redraw
    mov esi, brain_ctx
    call companion_reply
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop esi
    ret

cmd_mouse:
    push esi
    mov edi, kw_mouse
    call streq_prefix
    test al, al
    jz .no
    mov esi, label_mouse
    call vga_print
    mov eax, [sysres_mouse_x]
    call print_dec
    mov al, ','
    call vga_putchar
    mov eax, [sysres_mouse_y]
    call print_dec
    mov esi, label_btn
    call vga_print
    mov eax, [sysres_mouse_btn]
    call print_dec
    call vga_print_ln
    call companion_reply_ok
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop esi
    ret

label_mouse: db "mouse=", 0
label_btn:   db " btn=", 0

cmd_fb:
    push esi
    mov edi, kw_fb
    call streq_prefix
    test al, al
    jz .no
    mov esi, label_fb
    call vga_print
    mov eax, [sysres_fb_on]
    call print_dec
    cmp dword [sysres_fb_on], 0
    je .done_fb
    mov al, ' '
    call vga_putchar
    mov eax, [sysres_fb_w]
    call print_dec
    mov al, 'x'
    call vga_putchar
    mov eax, [sysres_fb_h]
    call print_dec
.done_fb:
    call vga_print_ln
    call companion_reply_ok
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop esi
    ret

label_fb: db "fb_on=", 0

cmd_redraw:
    push esi
    mov edi, kw_redraw
    call streq_prefix
    test al, al
    jz .no
    call gui_redraw
    call companion_reply_ok
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop esi
    ret

; companion_rmgr_wrap(eax=action) -> call inner with esi preserved
; eax=RMGR action; preserves esi; returns al=1 if hook started
companion_rmgr_wrap:
    push esi
    push eax
    call rmgr_hook_enter
    test al, al
    jz .denied
    pop eax
    pop esi
    mov al, 1
    ret
.denied:
    pop eax
    pop esi
    xor al, al
    ret

companion_rmgr_done:
    jmp rmgr_hook_leave

cmd_stats:
    push esi
    mov edi, kw_stats
    call streq_prefix
    test al, al
    jz .no
    mov eax, RMGR_ACT_COMPANION_CMD
    call companion_rmgr_wrap
    test al, al
    jz .out
    call rmgr_refresh
    call rmgr_format_panel
    call companion_reply
    call gui_log_line
    call companion_rmgr_done
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop esi
    ret

cmd_policy:
    push esi
    push eax
    mov edi, kw_policy
    call streq_prefix
    test al, al
    jz .no
    mov eax, RMGR_ACT_COMPANION_CMD
    call companion_rmgr_wrap
    test al, al
    jz .out
    call rmgr_refresh
    mov esi, lbl_policy_dec
    call vga_print
    mov eax, [rmgr_decision]
    call print_dec
    mov esi, lbl_policy_dfree
    call vga_print
    mov eax, [rmgr_delta_free_kb]
    call print_dec
    mov esi, lbl_policy_dtick
    call vga_print
    mov eax, [rmgr_delta_ticks]
    call print_dec
    call vga_print_ln
    call companion_reply_ok
    call companion_rmgr_done
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop eax
    pop esi
    ret

cmd_snapshot:
    push esi
    mov edi, kw_snapshot
    call streq_prefix
    test al, al
    jz .no
    mov eax, RMGR_ACT_COMPANION_CMD
    call companion_rmgr_wrap
    test al, al
    jz .out
    call rmgr_refresh
    call rmgr_format_snapshot
    call companion_reply
    call companion_rmgr_done
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop esi
    ret

lbl_policy_dec:  db "policy decision=", 0
lbl_policy_dfree: db " dFree_kb=", 0
lbl_policy_dtick: db " dTicks=", 0

cmd_profile:
    push esi
    mov esi, serial_cmd_buf
    mov edi, kw_profile
    call streq_prefix
    test al, al
    jz .no
    cmp byte [esi], 0
    jne .export
    call dmem_init
    call rmgr_refresh
    mov esi, lbl_prof_thr
    call vga_print
    mov eax, [rmgr_throttle_div]
    call print_dec
    mov esi, lbl_prof_base
    call vga_print
    mov eax, [rmgr_throttle_base]
    call print_dec
    mov esi, lbl_prof_score
    call vga_print
    mov eax, [rmgr_profile_score]
    call print_dec
    mov esi, lbl_prof_fmin
    call vga_print
    mov eax, [rmgr_free_min_kb_eff]
    call print_dec
    call vga_print_ln
    call rmgr_format_status
    mov esi, rmgr_status_buf
    call companion_reply
    mov al, 1
    jmp .out
.export:
    jmp cmd_profile_export.do
.no:
    xor al, al
.out:
    pop esi
    ret

cmd_profile_export:
    push esi
.do:
    mov edi, kw_profex
    call streq_prefix
    test al, al
    jz .no
    call dmem_init
    call dmem_profile_export
    mov esi, lbl_prof_hex
    call vga_print
    mov esi, eax
    call vga_print
    call vga_print_ln
    call companion_reply
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop esi
    ret

lbl_prof_thr:   db "profile thr=", 0
lbl_prof_base:  db " base=", 0
lbl_prof_score: db " score=", 0
lbl_prof_fmin:  db " free_min_kb=", 0
lbl_prof_hex:   db "DMTP export: ", 0

cmd_llm_stub:
    push esi
    mov edi, kw_llm
    call streq_prefix
    test al, al
    jz .no
    mov esi, msg_llm_host
    call companion_reply
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop esi
    ret

msg_llm_host: db "LLM generativo solo via host (companion_agent); kernel=orchestratore risorse.", 0

cmd_audit:
    push esi
    push ebx
    push eax
    mov edi, kw_audit
    call streq_prefix
    test al, al
    jz .no
    mov eax, RMGR_ACT_COMPANION_CMD
    call companion_rmgr_wrap
    test al, al
    jz .out
    xor ebx, ebx
    mov ecx, RMGR_AUDIT_SERIAL_MAX
.a_loop:
    cmp ebx, ecx
    jae .a_done
    mov eax, ebx
    call rmgr_audit_format_line
    test esi, esi
    jz .a_done
    call companion_reply
    inc ebx
    jmp .a_loop
.a_done:
    call companion_rmgr_done
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop eax
    pop ebx
    pop esi
    ret

cmd_alloc:
    push esi
    push eax
    mov edi, kw_alloc
    call streq_prefix
    test al, al
    jz .no
    call skip_spaces
    call parse_dec
    test eax, eax
    jz .default_kb
    jmp .do_alloc
.default_kb:
    mov eax, 64
.do_alloc:
    call pmm_alloc_kb
    test eax, eax
    jz .fail
    mov esi, msg_alloc_ok
    call companion_reply
    mov al, 1
    jmp .out
.fail:
    mov esi, msg_alloc_fail
    call companion_reply
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop eax
    pop esi
    ret

cmd_pmm_free:
    push esi
    mov edi, kw_free
    call streq_prefix
    test al, al
    jz .no
    mov eax, RMGR_ACT_PMM_FREE
    call rmgr_hook_enter
    test al, al
    jz .deny_free
    call pmm_free_all
    call rmgr_hook_leave
    mov esi, msg_free_ok
    call companion_reply
    mov al, 1
    jmp .out
.deny_free:
    mov esi, msg_alloc_fail
    call companion_reply
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop esi
    ret

msg_alloc_ok:  db "alloc OK (vedi audit/profile per dFree_kb)", 0
msg_alloc_fail: db "alloc negata (budget/RAM/arena)", 0
msg_free_ok:   db "arena PMM liberata", 0
msg_tasks:     db "tasks: ", 0
msg_cat_fail:  db "cat: file not found", 0

cmd_tasks:
    push esi
    mov edi, kw_tasks
    call streq_prefix
    test al, al
    jz .no
    mov esi, msg_tasks
    call companion_reply
    mov esi, sched_status_buf
    call scheduler_format_status
    mov esi, sched_status_buf
    call serial_writeln
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop esi
    ret

cmd_yield:
    push esi
    mov edi, kw_yield
    call streq_prefix
    test al, al
    jz .no
    call scheduler_yield
    mov esi, msg_ok
    call companion_reply
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop esi
    ret

cmd_run:
    push esi
    mov edi, kw_run
    call streq_prefix
    test al, al
    jz .no
    call task_spawn_user
    cmp eax, -1
    je .fail
    call scheduler_yield
    mov esi, msg_ok
    call companion_reply
    mov al, 1
    jmp .out
.fail:
    mov esi, msg_err
    call companion_reply
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop esi
    ret

cmd_sync:
    push esi
    mov esi, serial_cmd_buf
    mov edi, kw_sync
    call streq_prefix
    test al, al
    jz .no
    call fs_sync
    mov esi, msg_ok
    call companion_reply
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop esi
    ret

cmd_errors_clear:
    push esi
    mov edi, kw_errclr
    call streq_prefix
    test al, al
    jz .no
    call err_ring_clear
    mov esi, msg_ok
    call companion_reply
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop esi
    ret

cmd_errors:
    push esi
    mov edi, kw_errors
    call streq_prefix
    test al, al
    jz .no
    mov esi, err_line_buf
    call err_ring_format
    call companion_reply
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop esi
    ret

cmd_policy_set:
    push esi
    push ebx
    mov esi, serial_cmd_buf
    mov edi, kw_pset
    call streq_prefix
    test al, al
    jz .no
    mov edi, kw_thr
    call streq_prefix
    test al, al
    jnz .set_thr
    mov edi, kw_bgui
    call streq_prefix
    test al, al
    jnz .set_gui
    jmp .no
.set_thr:
    call parse_dec
    cmp eax, RMGR_THROTTLE_MAX
    ja .no
    cmp eax, RMGR_THROTTLE_MIN
    jb .no
    mov [rmgr_throttle_base], eax
    mov [rmgr_throttle_div], eax
    mov [rmgr_profile_blob + RMGR_PROF_THROTTLE], eax
    call fs_save_profile
    mov esi, msg_ok
    call companion_reply
    mov al, 1
    jmp .out
.set_gui:
    call parse_dec
    test eax, eax
    jz .no
    mov [rmgr_budget_gui], eax
    mov esi, msg_ok
    call companion_reply
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop ebx
    pop esi
    ret

kw_thr:  db "thr=", 0
kw_bgui: db "budget_gui=", 0

cmd_cat:
    push esi
    push ebx
    mov esi, serial_cmd_buf
    mov edi, kw_cat
    call streq_prefix
    test al, al
    jz .no
    call skip_spaces
    test byte [esi], 0
    jz .no
    call fs_open
    cmp eax, -1
    je .fail
    mov ebx, eax
    mov eax, ebx
    mov ecx, 127
    push ebx
    mov ebx, cat_read_buf
    call fs_read
    pop ebx
    test eax, eax
    js .fail_close
    mov byte [cat_read_buf + eax], 0
    mov esi, cat_read_buf
    call companion_reply
.fail_close:
    mov eax, ebx
    call fs_close
    mov al, 1
    jmp .out
.fail:
    mov esi, msg_cat_fail
    call companion_reply
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop ebx
    pop esi
    ret

; parse_dec: esi -> eax number, esi advanced
parse_dec:
    push ebx
    push ecx
    xor eax, eax
    xor ecx, ecx
.pd:
    mov bl, [esi]
    cmp bl, '0'
    jb .pd_done
    cmp bl, '9'
    ja .pd_done
    sub bl, '0'
    imul eax, 10
    add eax, ebx
    inc esi
    inc ecx
    jmp .pd
.pd_done:
    pop ecx
    pop ebx
    ret

cmd_think:
    push esi
    mov esi, serial_cmd_buf
    mov edi, kw_think
    call streq_prefix
    test al, al
    jz .no
    call skip_spaces
    call brain_think
    call companion_reply_ok
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop esi
    ret
