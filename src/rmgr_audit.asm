; DarkgreenOS - RMGR decision audit ring

%include "constants.inc"

extern timer_ticks
extern rmgr_current_action
extern rmgr_decision
extern rmgr_reason
extern rmgr_delta_free_kb
extern rmgr_delta_ticks
extern rmgr_profile_blob

global rmgr_audit_count
global rmgr_audit_head
global rmgr_audit_push
global rmgr_audit_format_line
global rmgr_audit_append_top3
global rmgr_audit_line

section .bss
align 4
rmgr_audit_count: resd 1
rmgr_audit_head:  resd 1
rmgr_audit_ring:  resb RMGR_AUDIT_ENTRIES * RMGR_AUDIT_ENTRY_BYTES
rmgr_audit_line:  resb 80

section .rodata
aud_act:   db " act=", 0
aud_pol:   db " pol=", 0
aud_df:    db " dF=", 0
aud_dt:    db " dT=", 0
aud_top:   db " |top:", 0
lbl_m:     db "m", 0
lbl_g:     db "g", 0
lbl_c:     db "c", 0

section .text
rmgr_audit_push:
    push eax
    push ebx
    push edi
    mov eax, [rmgr_audit_head]
    imul eax, RMGR_AUDIT_ENTRY_BYTES
    lea edi, [rmgr_audit_ring + eax]
    mov eax, [rmgr_current_action]
    mov [edi + 0], eax
    mov eax, [rmgr_decision]
    mov [edi + 4], eax
    mov eax, [rmgr_reason]
    mov [edi + 8], eax
    mov eax, [rmgr_delta_free_kb]
    mov [edi + 12], eax
    mov eax, [rmgr_delta_ticks]
    mov [edi + 16], eax
    mov eax, [timer_ticks]
    mov [edi + 20], eax
    mov eax, [rmgr_audit_head]
    inc eax
    cmp eax, RMGR_AUDIT_ENTRIES
    jb .head_ok
    xor eax, eax
.head_ok:
    mov [rmgr_audit_head], eax
    inc dword [rmgr_audit_count]
    pop edi
    pop ebx
    pop eax
    ret

; eax = 0 newest, 1 older, ...
rmgr_audit_format_line:
    push ebx
    push ecx
    push edi
    cmp eax, RMGR_AUDIT_ENTRIES
    jae .none
    cmp dword [rmgr_audit_count], 0
    je .none
    mov ebx, [rmgr_audit_head]
    dec ebx
    sub ebx, eax
    jns .idx_ok
    add ebx, RMGR_AUDIT_ENTRIES
.idx_ok:
    imul ebx, RMGR_AUDIT_ENTRY_BYTES
    mov edi, rmgr_audit_line
    mov ecx, 80
    xor al, al
    rep stosb
    mov edi, rmgr_audit_line
    mov esi, aud_act
    call aud_cat
    mov eax, [rmgr_audit_ring + ebx + 0]
    call aud_dec
    mov esi, aud_pol
    call aud_cat
    mov eax, [rmgr_audit_ring + ebx + 4]
    call aud_dec
    mov esi, aud_df
    call aud_cat
    mov eax, [rmgr_audit_ring + ebx + 12]
    call aud_dec_signed
    mov esi, aud_dt
    call aud_cat
    mov eax, [rmgr_audit_ring + ebx + 16]
    call aud_dec
    mov esi, rmgr_audit_line
    pop edi
    pop ecx
    pop ebx
    ret
.none:
    xor esi, esi
    pop edi
    pop ecx
    pop ebx
    ret

; rmgr_audit_append_top3(edi=panel buf, seek to end first by caller)
rmgr_audit_append_top3:
    push eax
    push esi
    mov esi, aud_top
    call aud_cat
    mov esi, lbl_m
    call aud_cat
    mov eax, [rmgr_profile_blob + RMGR_PROF_CNT_MEM]
    call aud_dec
    mov al, ' '
    stosb
    mov esi, lbl_g
    call aud_cat
    mov eax, [rmgr_profile_blob + RMGR_PROF_CNT_GUI]
    call aud_dec
    mov al, ' '
    stosb
    mov esi, lbl_c
    call aud_cat
    mov eax, [rmgr_profile_blob + RMGR_PROF_CNT_CHAT]
    call aud_dec
    pop esi
    pop eax
    ret

aud_cat:
    push eax
.l:
    mov al, [esi]
    test al, al
    jz .done
    mov [edi], al
    inc esi
    inc edi
    jmp .l
.done:
    pop eax
    ret

aud_dec:
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

aud_dec_signed:
    test eax, eax
    jns aud_dec
    push eax
    mov al, '-'
    mov [edi], al
    inc edi
    pop eax
    neg eax
    jmp aud_dec
