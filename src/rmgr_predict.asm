; DarkgreenOS - load prediction from EMA (pre-throttle)

%include "constants.inc"

extern rmgr_ema_dticks_class
extern rmgr_throttle_base
extern rmgr_throttle_div
extern rmgr_profile_score
extern rmgr_decision
extern timer_ticks

global rmgr_predict_init
global rmgr_predict_eval

section .bss
rmgr_predict_arm: resd 1

section .text
rmgr_predict_init:
    xor eax, eax
    mov [rmgr_predict_arm], eax
    ret

; rmgr_predict_eval(eax=action_class 0..4) — may raise throttle before costly work
rmgr_predict_eval:
    push ebx
    push ecx
    push edx
    cmp eax, RMGR_CLASS_MEM_SCAN
    je .scan
    cmp eax, RMGR_CLASS_GUI_PAINT
    je .gui
    cmp eax, RMGR_CLASS_USER_CHAT
    je .chat
    jmp .out
.chat:
    mov ecx, RMGR_CLASS_USER_CHAT
    mov edx, RMGR_BUDGET_CHAT
    jmp .chk
.scan:
    mov ecx, RMGR_CLASS_MEM_SCAN
    mov edx, RMGR_BUDGET_SCAN
    jmp .chk
.gui:
    mov ecx, RMGR_CLASS_GUI_PAINT
    mov edx, RMGR_BUDGET_GUI
.chk:
    push edx
    shl ecx, 2
    add ecx, rmgr_ema_dticks_class
    pop edx
    mov eax, [ecx]
    cmp eax, edx
    jb .out
    mov eax, [rmgr_throttle_base]
    test eax, eax
    jnz .inc
    mov eax, 1
.inc:
    shl eax, 1
    cmp eax, RMGR_THROTTLE_MAX
    jbe .store
    mov eax, RMGR_THROTTLE_MAX
.store:
    mov [rmgr_throttle_div], eax
    mov dword [rmgr_decision], RMGR_DEC_THROTTLE
    mov dword [rmgr_predict_arm], 1
.out:
    pop edx
    pop ecx
    pop ebx
    ret
