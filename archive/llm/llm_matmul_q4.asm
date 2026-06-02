; DarkgreenOS - Q4 GEMV baseline kernel

%include "constants.inc"
%include "llm_format.inc"

global llm_q4_step
global llm_q4_bind_tensor
global llm_f16_to_q8
global llm_q4_row_to_vec
global llm_q4_gemv
global llm_q4_state
global llm_q4_tensor_ptr

extern llm_model_ptr
extern llm_tensor_validate

section .bss
llm_q4_state: resd 1
llm_q4_tensor_ptr: resd 1

section .text
; llm_f16_to_q8(ax=f16 positive scale) -> eax ~= scale * 256, clamped >= 1.
; This is intentionally small: Q4_0 scales are positive F16 values, and the
; kernel only needs a stable fixed-point scale for diagnostics/first forward.
llm_f16_to_q8:
    push ebx
    push ecx
    push edx
    movzx ebx, ax
    mov ecx, ebx
    shr ecx, 10
    and ecx, 0x1F
    mov edx, ebx
    and edx, 0x03FF
    cmp ecx, 0
    je .small
    cmp ecx, 31
    je .large
    mov eax, 1024
    add eax, edx
    sub ecx, 17
    js .shift_right
.shift_left:
    cmp ecx, 6
    jbe .left_ok
    mov ecx, 6
.left_ok:
    shl eax, cl
    jmp .clamp
.shift_right:
    neg ecx
    cmp ecx, 15
    jbe .right_ok
    mov ecx, 15
.right_ok:
    shr eax, cl
    jmp .clamp
.small:
    mov eax, 1
    jmp .done
.large:
    mov eax, 32767
    jmp .done
.clamp:
    test eax, eax
    jnz .done
    mov eax, 1
.done:
    pop edx
    pop ecx
    pop ebx
    ret

; llm_q4_bind_tensor(eax=tensor entry) -> eax=payload pointer or 0
llm_q4_bind_tensor:
    test eax, eax
    jz .none
    cmp dword [eax + DMQ2_TENSOR_DTYPE_OFF], DMQ_DTYPE_Q4_0
    jne .none
    mov ebx, [eax + DMQ2_TENSOR_OFFSET_OFF]
    add ebx, [llm_model_ptr]
    mov [llm_q4_tensor_ptr], ebx
    mov eax, ebx
    ret
.none:
    mov dword [llm_q4_tensor_ptr], 0
    xor eax, eax
    ret

; llm_q4_step(eax=state, ebx=activation) -> eax=accumulator
llm_q4_step:
    push ecx
    push edx
    mov edx, [llm_q4_tensor_ptr]
    test edx, edx
    jz .fallback
    movzx ecx, word [edx]
    add eax, ecx
    movzx ecx, byte [edx + 2]
    xor eax, ecx
    movzx ecx, byte [edx + 3]
    shl ecx, 4
    add eax, ecx
    rol eax, 3
    jmp .done
.fallback:
    mov ecx, ebx
    and ecx, 0x0F
    imul ecx, 17
    add eax, ecx
    mov ecx, ebx
    shr ecx, 4
    and ecx, 0x0F
    imul ecx, 31
    sub eax, ecx
    rol eax, 5
.done:
    mov [llm_q4_state], eax
    pop edx
    pop ecx
    ret

; llm_q4_row_to_vec(eax=tensor entry, ebx=row, edi=out dwords) -> eax=1/0
; Dequantizes one row from a Q4_0 matrix into q8-ish dword activations.
llm_q4_row_to_vec:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp
    sub esp, 4
    mov [esp], eax
    test eax, eax
    jz .fail
    call llm_tensor_validate
    test eax, eax
    jz .fail
    mov eax, [esp]
    cmp dword [eax + DMQ2_TENSOR_DTYPE_OFF], DMQ_DTYPE_Q4_0
    jne .fail
    mov ecx, [eax + DMQ2_TENSOR_DIM1_OFF]
    test ecx, ecx
    jz .fail
    mov esi, [eax + DMQ2_TENSOR_OFFSET_OFF]
    add esi, [llm_model_ptr]
    mov edx, ecx
    add edx, 31
    shr edx, 5
    imul edx, 18
    imul ebx, edx
    add esi, ebx
.block_loop:
    test ecx, ecx
    jz .ok
    mov ax, [esi]
    call llm_f16_to_q8
    mov ebp, eax
    add esi, 2
    mov edx, 16
.pair_loop:
    test ecx, ecx
    jz .ok
    mov bl, [esi]
    movzx eax, bl
    and eax, 0x0F
    cmp eax, 8
    jb .lo_signed
    sub eax, 16
.lo_signed:
    imul eax, ebp
    mov [edi], eax
    add edi, 4
    dec ecx
    test ecx, ecx
    jz .ok_advance
    movzx eax, bl
    shr eax, 4
    cmp eax, 8
    jb .hi_signed
    sub eax, 16
.hi_signed:
    imul eax, ebp
    mov [edi], eax
    add edi, 4
    dec ecx
.ok_advance:
    inc esi
    dec edx
    jnz .pair_loop
    jmp .block_loop
.ok:
    mov eax, 1
    jmp .out
.fail:
    xor eax, eax
.out:
    add esp, 4
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; llm_q4_gemv(eax=tensor entry, esi=input dwords, edi=output dwords) -> eax=rows or 0
; Matrix shape is [rows, cols]. Output values are scaled down after i32 dot.
llm_q4_gemv:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp
    sub esp, 16
    mov [esp], eax
    test eax, eax
    jz .gemv_fail
    call llm_tensor_validate
    test eax, eax
    jz .gemv_fail
    mov eax, [esp]
    cmp dword [eax + DMQ2_TENSOR_DTYPE_OFF], DMQ_DTYPE_Q4_0
    jne .gemv_fail
    mov [esp + 4], esi
    mov [esp + 8], edi
    mov ebp, [eax + DMQ2_TENSOR_DIM0_OFF]
    mov [esp + 12], ebp
    xor ebx, ebx
.row_loop:
    cmp ebx, [esp + 12]
    jae .gemv_ok
    mov eax, [esp]
    mov esi, [esp + 4]
    xor ebp, ebp
    mov ecx, [eax + DMQ2_TENSOR_DIM1_OFF]
    mov edx, ecx
    add edx, 31
    shr edx, 5
    imul edx, 18
    imul edx, ebx
    add edx, [eax + DMQ2_TENSOR_OFFSET_OFF]
    add edx, [llm_model_ptr]
.gemv_block:
    test ecx, ecx
    jz .store_row
    mov ax, [edx]
    call llm_f16_to_q8
    push ebx
    mov ebx, eax
    add edx, 2
    push dword 16
.gemv_pair:
    test ecx, ecx
    jz .end_pair_block
    mov al, [edx]
    movzx eax, al
    and eax, 0x0F
    cmp eax, 8
    jb .gemv_lo_signed
    sub eax, 16
.gemv_lo_signed:
    imul eax, ebx
    imul eax, [esi]
    add ebp, eax
    add esi, 4
    dec ecx
    test ecx, ecx
    jz .end_pair_advance
    mov al, [edx]
    movzx eax, al
    shr eax, 4
    cmp eax, 8
    jb .gemv_hi_signed
    sub eax, 16
.gemv_hi_signed:
    imul eax, ebx
    imul eax, [esi]
    add ebp, eax
    add esi, 4
    dec ecx
.end_pair_advance:
    inc edx
    dec dword [esp]
    jnz .gemv_pair
.end_pair_block:
    add esp, 4
    pop ebx
    jmp .gemv_block
.store_row:
    mov edi, [esp + 8]
    mov eax, ebp
    sar eax, 8
    mov [edi + ebx * 4], eax
    inc ebx
    jmp .row_loop
.gemv_ok:
    mov eax, [esp + 12]
    jmp .gemv_out
.gemv_fail:
    xor eax, eax
.gemv_out:
    add esp, 16
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret
