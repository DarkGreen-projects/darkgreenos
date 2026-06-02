; DarkgreenOS - desktop GUI (framebuffer + DarkMind panels)

%include "constants.inc"

%define GUI_AI_LINES             96
%define GUI_AI_VISIBLE           66
%define GUI_AI_COLS              126
%define GUI_INPUT_MAX            72
%define GUI_AI_X                 0
%define GUI_AI_TOP               (GUI_TITLE_H + GUI_MARGIN)
%define GUI_RES_PANEL_W          300
%define GUI_RES_PANEL_X          8
%define GUI_RES_PANEL_Y          (GUI_AI_TOP + 8)
%define GUI_AI_TEXT_X            316
%define GUI_AI_TEXT_Y            (GUI_AI_TOP + 8)
%define GUI_AI_LINE_Y            (GUI_AI_TOP + 26)
%define GUI_INPUT_X              320
%define FB_COL_BLACK             0x00000000
%define FB_COL_INPUT             0x00D8FFD8

extern fb_active
extern fb_width
extern fb_height
extern fb_clear
extern fb_fill_rect
extern gfx_draw_string_at
extern gfx_draw_char
extern fb_put_pixel
extern fb_xor_pixel
extern mouse_x
extern mouse_y
extern mouse_buttons
extern mouse_wheel_delta
extern sysres_sync_mouse
extern sysres_gui_on
extern brain_ctx
extern brain_think
extern companion_name
extern timer_ticks
extern tinylm_busy
extern rmgr_format_panel
extern rmgr_decision
extern rmgr_skip_redraw
extern rmgr_refresh
extern rmgr_format_status
extern rmgr_hook_enter
extern rmgr_hook_leave
extern rmgr_skip_redraw
extern rmgr_audit_count
extern rmgr_budget_gui
extern keyboard_may_type
extern keyboard_last_scancode
extern keyboard_last_char
extern keyboard_rx_count
extern vga_print_ln
extern vga_set_color
extern vga_print

section .bss
gui_log_lines:  resb GUI_LOG_LINES * (GUI_LOG_COLS + 1)
gui_ai_lines:   resb GUI_AI_LINES * (GUI_AI_COLS + 1)
gui_ai_count:   resd 1
gui_ai_scroll:  resd 1
gui_input:      resb GUI_INPUT_MAX
gui_input_len:  resd 1
gui_input_active: resd 1
gui_prev_buttons: resd 1
gui_caret_phase: resd 1
gui_last_caret_x: resd 1
gui_log_row:    resd 1
global gui_dirty
gui_dirty:      resd 1
gui_cursor_x:   resd 1
gui_cursor_y:   resd 1
gui_cursor_on:  resd 1

section .data
gui_title:  db "DarkgreenOS v0.5  DarkMind GUI", 0
gui_res:    db "DarkMind output:", 0
gui_chat:   db "Mind chat / serial THINK:", 0
gui_hint:   db "ENTER: DarkMind | click barra chat | rotella: scroll", 0
gui_kbd_dbg: db "KBD sc=__ ch=_ n=____", 0
gui_hint_thinking: db "DarkMind orchestratore: report risorse in corso...", 0
gui_res_panel_lbl: db "Orchestratore:", 0
gui_fb_off: db "[GUI] No framebuffer - text mode", 0
gui_prompt: db "> ", 0

section .rodata
cursor_mask:
    db 10000000b
    db 11000000b
    db 10100000b
    db 10010000b
    db 10001000b
    db 10000100b
    db 10000010b
    db 10011100b
    db 10100100b
    db 11000100b
    db 01000010b
    db 00000010b

section .text
global gui_init
global gui_poll
global gui_redraw
global gui_log_line
global gui_show_resources
global gui_handle_key
global gui_panel_refresh

gui_init:
    cmp dword [fb_active], 0
    je .text_only
    mov dword [gui_log_row], 0
    mov dword [gui_ai_count], 0
    mov dword [gui_ai_scroll], 0
    mov dword [gui_input_len], 0
    mov dword [gui_input_active], 1
    mov dword [gui_prev_buttons], 0
    mov dword [gui_caret_phase], 1
    mov dword [gui_last_caret_x], GUI_INPUT_X + 24
    mov edi, gui_input
    mov ecx, GUI_INPUT_MAX
    xor al, al
    rep stosb
    mov dword [gui_dirty], 1
    mov dword [gui_cursor_on], 0
    mov dword [sysres_gui_on], 1
    call fb_clear
    call gui_redraw
    call gui_cursor_sync
    ret
.text_only:
    mov dword [sysres_gui_on], 0
    mov al, COLOR_DIM_GREEN
    call vga_set_color
    mov esi, gui_fb_off
    call vga_print_ln
    ret

gui_poll:
    cmp dword [fb_active], 0
    je .out
    call sysres_sync_mouse
    call gui_handle_click
    call gui_handle_wheel
    call gui_update_caret
    cmp dword [gui_dirty], 0
    je .cursor
    call gui_redraw
.cursor:
    call gui_cursor_sync
.out:
    ret

gui_redraw:
    cmp dword [rmgr_skip_redraw], 0
    je .go_redraw
    mov dword [gui_dirty], 1
    ret
.go_redraw:
    mov eax, RMGR_ACT_GUI_REDRAW
    call rmgr_hook_enter
    test al, al
    jz .defer_redraw
    pusha
    mov dword [gui_dirty], 0
    mov dword [gui_cursor_on], 0
    push FB_COL_CHAT
    push dword [fb_height]
    push dword [fb_width]
    push 0
    push 0
    call fb_fill_rect
    add esp, 20

    push FB_COL_TITLE
    push GUI_TITLE_H
    push dword [fb_width]
    push 0
    push 0
    call fb_fill_rect
    add esp, 20

    push FB_COL_BORDER
    push GUI_STATUS_H
    push dword [fb_width]
    push dword [fb_height]
    sub dword [esp], GUI_STATUS_H
    push 0
    call fb_fill_rect
    add esp, 20

    push FB_COL_TEXT
    push GUI_MARGIN + 6
    push GUI_MARGIN
    push gui_title
    call gfx_draw_string_at
    add esp, 16

    call gui_draw_panels
    call gui_draw_resource_panel
    call gui_draw_input_bar
    call gui_draw_status
    popa
    call rmgr_hook_leave
    ret
.defer_redraw:
    mov dword [gui_dirty], 1
    ret

gui_panel_refresh:
    call rmgr_refresh
    mov dword [gui_dirty], 1
    ret

gui_draw_resource_panel:
    push eax
    push ebx
    push esi
    push FB_COL_PANEL
    push 72
    push GUI_RES_PANEL_W
    push GUI_RES_PANEL_Y
    push GUI_RES_PANEL_X
    call fb_fill_rect
    add esp, 20
    push FB_COL_TEXT
    push GUI_RES_PANEL_Y
    push GUI_RES_PANEL_X + 6
    push gui_res_panel_lbl
    call gfx_draw_string_at
    add esp, 16
    call rmgr_format_panel
    push FB_COL_TEXT
    push GUI_RES_PANEL_Y + 14
    push GUI_RES_PANEL_X + 6
    push esi
    call gfx_draw_string_at
    add esp, 16
    pop esi
    pop ebx
    pop eax
    ret

gui_draw_input_bar:
    push FB_COL_BLACK
    push 22
    mov eax, [fb_width]
    sub eax, GUI_INPUT_X
    sub eax, 8
    push eax
    push 3
    mov eax, GUI_INPUT_X
    sub eax, 1
    push eax
    call fb_fill_rect
    add esp, 20

    push FB_COL_INPUT
    push 20
    mov eax, [fb_width]
    sub eax, GUI_INPUT_X
    sub eax, 10
    push eax
    push 4
    push GUI_INPUT_X
    call fb_fill_rect
    add esp, 20

    push FB_COL_TEXT
    push 10
    mov eax, GUI_INPUT_X
    add eax, 8
    push eax
    push gui_prompt
    call gfx_draw_string_at
    add esp, 16

    push FB_COL_TEXT
    push 10
    mov eax, GUI_INPUT_X
    add eax, 24
    push eax
    push gui_input
    call gfx_draw_string_at
    add esp, 16

    cmp dword [gui_input_active], 0
    je .done
    cmp dword [gui_caret_phase], 0
    je .done
    push FB_COL_BLACK
    push 12
    push 2
    push 8
    mov eax, [gui_input_len]
    shl eax, 3
    add eax, GUI_INPUT_X + 24
    push eax
    call fb_fill_rect
    add esp, 20
.done:
    ret

gui_draw_panels:
    push FB_COL_INPUT
    mov eax, [fb_width]
    sub eax, GUI_AI_X
    push eax
    mov eax, [fb_height]
    sub eax, GUI_STATUS_H
    sub eax, GUI_AI_TOP
    push eax
    push GUI_AI_TOP
    push GUI_AI_X
    call fb_fill_rect
    add esp, 20
    ret

gui_draw_log:
    push ebx
    push ecx
    push esi
    mov ecx, 0
    mov ebx, GUI_TITLE_H
    add ebx, GUI_MARGIN
    add ebx, 20
.log_row:
    cmp ecx, GUI_LOG_LINES
    jge .done
    imul eax, ecx, GUI_LOG_COLS + 1
    lea esi, [gui_log_lines + eax]
    push FB_COL_CHAT
    push ebx
    push GUI_MARGIN + GUI_PANEL_W + 12
    push esi
    call gfx_draw_string_at
    add esp, 16
    add ebx, 10
    inc ecx
    jmp .log_row
.done:
    pop esi
    pop ecx
    pop ebx
    ret

gui_draw_status:
    push esi
    push FB_COL_BORDER
    push GUI_STATUS_H
    push dword [fb_width]
    push dword [fb_height]
    sub dword [esp], GUI_STATUS_H
    push 0
    call fb_fill_rect
    add esp, 20

    mov esi, gui_hint
    cmp dword [tinylm_busy], 0
    je .hint_ready
    mov esi, gui_hint_thinking
.hint_ready:
    push FB_COL_TEXT
    mov eax, [fb_height]
    sub eax, GUI_STATUS_H
    add eax, 4
    push eax
    push GUI_MARGIN
    push esi
    call gfx_draw_string_at
    add esp, 16
    push FB_COL_TEXT
    mov eax, [fb_height]
    sub eax, GUI_STATUS_H
    add eax, 16
    push eax
    push 520
    call rmgr_format_status
    push esi
    call gfx_draw_string_at
    add esp, 16
    call gui_format_kbd_dbg
    push FB_COL_TEXT
    mov eax, [fb_height]
    sub eax, GUI_STATUS_H
    add eax, 16
    push eax
    push 720
    push gui_kbd_dbg
    call gfx_draw_string_at
    add esp, 16
    pop esi
    call gui_show_resources
    ret

gui_format_kbd_dbg:
    push eax
    push ebx
    push ecx
    push edx
    push edi
    mov edi, gui_kbd_dbg
    add edi, 7
    movzx eax, byte [keyboard_last_scancode]
    mov ah, al
    shr al, 4
    call gui_hex_nibble
    mov [edi], al
    inc edi
    mov al, ah
    and al, 0x0F
    call gui_hex_nibble
    mov [edi], al
    add edi, 4
    movzx eax, byte [keyboard_last_char]
    cmp al, 32
    jb .ch_dot
    cmp al, 126
    ja .ch_dot
    mov [edi], al
    jmp .ch_cnt
.ch_dot:
    mov byte [edi], '.'
.ch_cnt:
    add edi, 4
    mov eax, [keyboard_rx_count]
    mov ecx, 4
.fmt_n:
    xor edx, edx
    mov ebx, 10
    div ebx
    add dl, '0'
    push edx
    dec ecx
    test ecx, ecx
    jnz .fmt_n
    mov ecx, 4
.fmt_pop:
    pop edx
    mov [edi], dl
    inc edi
    loop .fmt_pop
    pop edi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

gui_hex_nibble:
    cmp al, 10
    jb .hn
    add al, 'A' - 10
    ret
.hn:
    add al, '0'
    ret

gui_show_resources:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    push FB_COL_BLACK
    push GUI_AI_TEXT_Y
    push GUI_AI_TEXT_X
    push gui_res
    call gfx_draw_string_at
    add esp, 16

    mov eax, [gui_ai_count]
    sub eax, GUI_AI_VISIBLE
    jns .have_base
    xor eax, eax
.have_base:
    sub eax, [gui_ai_scroll]
    jns .base_ok
    xor eax, eax
.base_ok:
    mov edi, eax
    xor ecx, ecx
    mov ebx, GUI_AI_LINE_Y
.line:
    cmp ecx, GUI_AI_VISIBLE
    jge .done
    mov eax, edi
    add eax, ecx
    cmp eax, [gui_ai_count]
    jge .done
    imul eax, GUI_AI_COLS + 1
    lea esi, [gui_ai_lines + eax]
    push ecx
    push FB_COL_BLACK
    push ebx
    push GUI_AI_TEXT_X
    push esi
    call gfx_draw_string_at
    add esp, 16
    pop ecx
    add ebx, 10
    inc ecx
    jmp .line
.done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

gui_log_line:
    cmp dword [fb_active], 0
    je .vga
    call gui_log_wrapped
    ret
.vga:
    call vga_print_ln
    ret

gui_log_wrapped:
    push eax
    push ebx
    push ecx
    push edi
    push esi
    mov ebx, esi
.next_segment:
    mov eax, [gui_ai_count]
    cmp eax, GUI_AI_LINES
    jl .slot
    mov esi, gui_ai_lines + (GUI_AI_COLS + 1)
    mov edi, gui_ai_lines
    mov ecx, (GUI_AI_LINES - 1) * (GUI_AI_COLS + 1)
    rep movsb
    mov eax, GUI_AI_LINES - 1
    jmp .dest
.slot:
    inc dword [gui_ai_count]
.dest:
    imul eax, GUI_AI_COLS + 1
    lea edi, [gui_ai_lines + eax]
    push edi
    mov ecx, GUI_AI_COLS + 1
    xor al, al
    rep stosb
    pop edi
    mov esi, ebx
    mov ecx, GUI_AI_COLS
.copy:
    lodsb
    test al, al
    jz .filled
    mov [edi], al
    inc edi
    loop .copy
    mov ebx, esi
    mov byte [edi], 0
    jmp .next_segment
.filled:
    mov byte [edi], 0
    mov dword [gui_ai_scroll], 0
    cmp dword [rmgr_skip_redraw], 0
    jne .no_dirty
    mov dword [gui_dirty], 1
.no_dirty:
    pop esi
    pop edi
    pop ecx
    pop ebx
    pop eax
    ret

; al = character from keyboard_poll (caller must preserve across gui_poll)
gui_handle_key:
    movzx ebx, al
    cmp dword [fb_active], 0
    je .out
    mov dword [gui_input_active], 1
    cmp al, 8
    je .backspace
    cmp al, 10
    je .enter
    cmp al, 13
    je .enter
    cmp al, 9
    je .tab
    cmp al, 32
    jb .out
    cmp al, 126
    ja .out
    mov ecx, [gui_input_len]
    cmp ecx, GUI_INPUT_MAX - 1
    jae .out
    mov [gui_input + ecx], al
    inc ecx
    mov [gui_input_len], ecx
    mov byte [gui_input + ecx], 0
    call gui_draw_input_bar
    call gui_cursor_sync
    call gui_format_kbd_dbg
    mov dword [gui_dirty], 1
    jmp .out
.backspace:
    mov ecx, [gui_input_len]
    test ecx, ecx
    jz .out
    dec ecx
    mov [gui_input_len], ecx
    mov byte [gui_input + ecx], 0
    call gui_draw_input_bar
    call gui_cursor_sync
    call gui_format_kbd_dbg
    mov dword [gui_dirty], 1
    jmp .out
.tab:
    mov al, ' '
    mov ecx, [gui_input_len]
    cmp ecx, GUI_INPUT_MAX - 1
    jae .out
    mov [gui_input + ecx], al
    inc ecx
    mov [gui_input_len], ecx
    mov byte [gui_input + ecx], 0
    call gui_draw_input_bar
    call gui_cursor_sync
    call gui_format_kbd_dbg
    mov dword [gui_dirty], 1
    jmp .out
.enter:
    cmp dword [gui_input_len], 0
    je .out
    mov esi, gui_input
    call brain_think
    mov dword [gui_input_len], 0
    mov byte [gui_input], 0
    call gui_draw_input_bar
    call gui_cursor_sync
.out:
    ret

gui_handle_click:
    mov eax, [mouse_buttons]
    mov ebx, eax
    and ebx, 1
    mov ecx, [gui_prev_buttons]
    mov [gui_prev_buttons], eax
    test ebx, ebx
    jz .out
    test ecx, 1
    jnz .out
    mov eax, [mouse_x]
    cmp eax, GUI_INPUT_X
    jb .out
    mov edx, [fb_width]
    sub edx, 10
    cmp eax, edx
    jae .out
    mov eax, [mouse_y]
    cmp eax, 4
    jb .out
    cmp eax, 24
    jae .out
    mov dword [gui_input_active], 1
    call gui_draw_input_bar
    call gui_cursor_sync
.out:
    ret

gui_update_caret:
    cmp dword [gui_input_active], 0
    je .inactive
    mov eax, [timer_ticks]
    shr eax, 4
    and eax, 1
    cmp eax, [gui_caret_phase]
    je .out
    mov [gui_caret_phase], eax
    call gui_draw_caret_cell
    ret
.inactive:
    cmp dword [gui_caret_phase], 0
    je .out
    mov dword [gui_caret_phase], 0
    call gui_draw_caret_cell
.out:
    ret

gui_draw_caret_cell:
    push eax
    push FB_COL_INPUT
    push 10
    push 8
    push 10
    mov eax, [gui_input_len]
    shl eax, 3
    add eax, GUI_INPUT_X + 24
    mov [gui_last_caret_x], eax
    push eax
    call fb_fill_rect
    add esp, 20
    cmp dword [gui_input_active], 0
    je .done
    cmp dword [gui_caret_phase], 0
    je .done
    push FB_COL_BLACK
    push 12
    push 2
    push 8
    push dword [gui_last_caret_x]
    call fb_fill_rect
    add esp, 20
.done:
    pop eax
    ret

gui_handle_wheel:
    mov eax, [mouse_wheel_delta]
    test eax, eax
    jz .out
    mov dword [mouse_wheel_delta], 0
    test eax, eax
    js .wheel_down
.wheel_up:
    mov ebx, [gui_ai_count]
    sub ebx, GUI_AI_VISIBLE
    jle .dirty
    cmp [gui_ai_scroll], ebx
    jge .dirty
    inc dword [gui_ai_scroll]
    jmp .dirty
.wheel_down:
    cmp dword [gui_ai_scroll], 0
    jle .dirty
    dec dword [gui_ai_scroll]
.dirty:
    mov dword [gui_dirty], 1
.out:
    ret

gui_cursor_sync:
    cmp dword [gui_cursor_on], 0
    je .draw_new
    mov eax, [mouse_x]
    cmp eax, [gui_cursor_x]
    jne .move
    mov eax, [mouse_y]
    cmp eax, [gui_cursor_y]
    je .out
.move:
    mov ecx, [gui_cursor_x]
    mov edx, [gui_cursor_y]
    call gui_xor_cursor_at
.draw_new:
    mov ecx, [mouse_x]
    mov edx, [mouse_y]
    call gui_xor_cursor_at
    mov eax, [mouse_x]
    mov [gui_cursor_x], eax
    mov eax, [mouse_y]
    mov [gui_cursor_y], eax
    mov dword [gui_cursor_on], 1
.out:
    ret

gui_xor_cursor_at:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    mov edi, ecx
    mov esi, edx
    xor ebx, ebx
.row:
    cmp ebx, 12
    jge .done
    movzx edx, byte [cursor_mask + ebx]
    xor ecx, ecx
.col:
    cmp ecx, 8
    jge .next_row
    mov eax, 0x80
    shr eax, cl
    test edx, eax
    jz .skip_pixel
    push FB_COL_CURSOR
    mov eax, esi
    add eax, ebx
    push eax
    mov eax, edi
    add eax, ecx
    push eax
    call fb_xor_pixel
    add esp, 12
 .skip_pixel:
    inc ecx
    jmp .col
.next_row:
    inc ebx
    jmp .row
.done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret
