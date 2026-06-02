; DarkgreenOS - SwiGLU-like MLP approximation

%include "constants.inc"

global llm_mlp_step
global llm_swiglu_vec
global llm_mlp_state

section .bss
llm_mlp_state: resd 1

section .text
; llm_mlp_step(eax=state) -> eax
llm_mlp_step:
    push ebx
    mov ebx, eax
    shr ebx, 3
    xor ebx, eax
    imul ebx, 1103515245
    add eax, ebx
    add eax, 12345
    mov [llm_mlp_state], eax
    pop ebx
    ret

; llm_swiglu_vec(esi=gate, edi=up, edx=out, ecx=len)
; Fixed-point SiLU approximation: silu(x) ~= x if positive, x/4 if negative.
llm_swiglu_vec:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp
    mov ebp, edx
.loop:
    test ecx, ecx
    jz .done
    mov eax, [esi]
    test eax, eax
    jge .gate_ok
    sar eax, 2
.gate_ok:
    mov ebx, [edi]
    sar ebx, 8
    imul eax, ebx
    sar eax, 8
    mov [ebp], eax
    add esi, 4
    add edi, 4
    add ebp, 4
    dec ecx
    jmp .loop
.done:
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret
