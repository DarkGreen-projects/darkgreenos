; DarkgreenOS - RoPE phase approximation

%include "constants.inc"

global llm_rope_step
global llm_rope_qk_layer0
global llm_rope_state

section .bss
llm_rope_state: resd 1

section .text
; llm_rope_step(eax=state, ecx=position) -> eax=rotated state
llm_rope_step:
    mov edx, ecx
    and edx, 31
    rol eax, cl
    xor eax, ecx
    mov [llm_rope_state], eax
    ret

; llm_rope_qk_layer0(esi=q[896], edi=k[128], ecx=position)
; Applies a deterministic fixed-point RoPE-style pair rotation to Q and K.
llm_rope_qk_layer0:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    mov ebx, ecx
    and ebx, 63
    inc ebx
    mov ecx, 448
.q_loop:
    mov eax, [esi]
    mov edx, [esi + 4]
    push edx
    imul edx, ebx
    sar edx, 6
    sub eax, edx
    pop edx
    push eax
    imul eax, ebx
    sar eax, 6
    add edx, eax
    pop eax
    mov [esi], eax
    mov [esi + 4], edx
    add esi, 8
    loop .q_loop
    mov ecx, 64
.k_loop:
    mov eax, [edi]
    mov edx, [edi + 4]
    push edx
    imul edx, ebx
    sar edx, 6
    sub eax, edx
    pop edx
    push eax
    imul eax, ebx
    sar eax, 6
    add edx, eax
    pop eax
    mov [edi], eax
    mov [edi + 4], edx
    add edi, 8
    loop .k_loop
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret
