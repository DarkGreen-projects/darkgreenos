; DarkgreenOS - scalar Q4 GEMV probe kernel

%include "constants.inc"

global llm_q4_gemv_probe
global llm_probe_score

section .bss
llm_probe_score: resd 1

section .text
; llm_q4_gemv_probe(esi=prompt, ecx=tokens) -> eax=small deterministic score
llm_q4_gemv_probe:
    push ebx
    push ecx
    push edx
    xor eax, eax
    xor edx, edx
.loop:
    test ecx, ecx
    jz .done
    mov bl, [esi]
    test bl, bl
    jz .done
    movzx ebx, bl
    and ebx, 0x0F
    add eax, ebx
    inc esi
    dec ecx
    inc edx
    cmp edx, LLM_STEP_BUDGET_OPS
    jb .loop
.done:
    mov [llm_probe_score], eax
    pop edx
    pop ecx
    pop ebx
    ret
