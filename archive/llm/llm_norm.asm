; DarkgreenOS - fixed-point RMSNorm approximation

%include "constants.inc"
%include "llm_format.inc"

global llm_rmsnorm_step
global llm_rmsnorm_vec
global llm_norm_state

extern llm_model_ptr
extern llm_f16_to_q8

section .bss
llm_norm_state: resd 1

section .text
; llm_rmsnorm_step(eax=state, ebx=token_hash) -> eax=normalized state
llm_rmsnorm_step:
    add eax, ebx
    ror eax, 3
    xor eax, 0x13579BDF
    mov [llm_norm_state], eax
    ret

; llm_rmsnorm_vec(eax=F16 weight tensor entry, esi=in, edi=out, ecx=len)
; Fixed-point RMSNorm approximation over dword activations.
llm_rmsnorm_vec:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp
    sub esp, 20
    test eax, eax
    jz .out
    mov [esp], eax
    mov [esp + 4], esi
    mov [esp + 8], edi
    mov [esp + 12], ecx
    mov dword [esp + 16], 0
.sum_loop:
    test ecx, ecx
    jz .sum_done
    mov eax, [esi]
    sar eax, 8
    imul eax, eax
    add [esp + 16], eax
    add esi, 4
    dec ecx
    jmp .sum_loop
.sum_done:
    mov eax, [esp + 16]
    xor edx, edx
    mov ecx, [esp + 12]
    test ecx, ecx
    jz .out
    div ecx
    add eax, 1
    mov ebp, eax
    mov eax, 65536
    xor edx, edx
    div ebp
    mov ebp, eax
    mov eax, [esp]
    mov ebx, [eax + DMQ2_TENSOR_OFFSET_OFF]
    add ebx, [llm_model_ptr]
    mov esi, [esp + 4]
    mov edi, [esp + 8]
    mov ecx, [esp + 12]
.norm_loop:
    test ecx, ecx
    jz .out
    mov ax, [ebx]
    call llm_f16_to_q8
    mov edx, [esi]
    imul edx, eax
    sar edx, 8
    imul edx, ebp
    sar edx, 8
    mov [edi], edx
    add ebx, 2
    add esi, 4
    add edi, 4
    dec ecx
    jmp .norm_loop
.out:
    add esp, 20
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret
