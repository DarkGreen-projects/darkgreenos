; DarkgreenOS - attention score/value approximation

%include "constants.inc"
%include "llm_format.inc"

global llm_attention_step
global llm_attention_layer0
global llm_attention_layer
global llm_attention_state
global llm_kv_key_l0
global llm_kv_value_l0

extern llm_kv_store
extern llm_kv_load
extern llm_kv_position

section .bss
llm_attention_state: resd 1
llm_kv_key_l0:      resd 128
llm_kv_value_l0:    resd 128
llm_attn_q_base:    resd 1
llm_attn_out_base:  resd 1

section .text
; llm_attention_step(eax=state, ebx=token_hash, ecx=position) -> eax
llm_attention_step:
    push edx
    mov edx, eax
    xor edx, ebx
    add edx, ecx
    ror edx, 7
    add eax, edx
    xor eax, 0x2468ACE0
    mov [llm_attention_state], eax
    pop edx
    ret

; llm_attention_layer0(esi=q[896], edi=k[128], ebx=v[128], edx=out[896])
; Minimal GQA attention for the current token: cache K/V for layer 0 and
; expand 2 KV heads across 14 query heads.
llm_attention_layer0:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp
    mov [llm_attn_q_base], esi
    mov [llm_attn_out_base], edx
    push edx
    mov ecx, 128
    mov ebp, llm_kv_key_l0
.copy_k:
    mov eax, [edi]
    mov [ebp], eax
    add edi, 4
    add ebp, 4
    loop .copy_k
    mov ecx, 128
    mov ebp, llm_kv_value_l0
.copy_v:
    mov eax, [ebx]
    mov [ebp], eax
    add ebx, 4
    add ebp, 4
    loop .copy_v
    pop edx
    xor ebp, ebp
.head_loop:
    cmp ebp, 14
    jae .done
    mov eax, ebp
    cmp eax, 7
    jb .kv0
    mov eax, 1
    jmp .kv_ready
.kv0:
    xor eax, eax
.kv_ready:
    imul eax, 64 * 4
    lea edi, [llm_kv_key_l0 + eax]
    lea ebx, [llm_kv_value_l0 + eax]
    mov eax, ebp
    imul eax, 64 * 4
    mov esi, [llm_attn_q_base]
    add esi, eax
    xor edx, edx
    mov ecx, 64
.score_loop:
    mov eax, [esi]
    sar eax, 8
    imul eax, [edi]
    sar eax, 8
    add edx, eax
    add esi, 4
    add edi, 4
    loop .score_loop
    sar edx, 6
    cmp edx, 1
    jge .score_pos
    mov edx, 1
.score_pos:
    mov edi, [llm_attn_out_base]
    mov eax, ebp
    imul eax, 64 * 4
    add edi, eax
    mov ecx, 64
.value_loop:
    mov eax, [ebx]
    imul eax, edx
    sar eax, 8
    mov [edi], eax
    add ebx, 4
    add edi, 4
    loop .value_loop
    inc ebp
    jmp .head_loop
.done:
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; llm_attention_layer(eax=layer, esi=q[896], edi=k[128], ebx=v[128], edx=out[896])
; Causal first-pass GQA over the static KV cache. Uses a bounded average of
; cached values weighted by positive QK scores to keep i386 math stable.
llm_attention_layer:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp
    mov [llm_attn_q_base], esi
    mov [llm_attn_out_base], edx
    mov ecx, DMQ_QWEN_HIDDEN
    mov edi, edx
    xor eax, eax
.zero_out:
    mov [edi], eax
    add edi, 4
    loop .zero_out
    pop ebp
    push ebp
    mov eax, [esp + 24]
    mov ebx, [llm_kv_position]
    mov esi, [llm_attn_q_base]
    mov edi, [esp + 20]
    call llm_kv_store
    xor ebp, ebp
.pos_loop:
    cmp ebp, [llm_kv_position]
    ja .done_layer
    mov eax, [esp + 24]
    mov ebx, ebp
    call llm_kv_load
    test eax, eax
    jz .next_pos
    xor ebx, ebx
.head_loop:
    cmp ebx, DMQ_QWEN_HEADS
    jae .next_pos
    push esi
    push edi
    mov eax, ebx
    cmp eax, 7
    jb .kv0
    mov eax, 1
    jmp .kv_ready
.kv0:
    xor eax, eax
.kv_ready:
    imul eax, DMQ_QWEN_HEAD_DIM * 4
    add esi, eax
    add edi, eax
    mov eax, ebx
    imul eax, DMQ_QWEN_HEAD_DIM * 4
    mov edx, [llm_attn_q_base]
    add edx, eax
    xor ecx, ecx
    push ebx
    mov ebx, DMQ_QWEN_HEAD_DIM
.score_loop:
    mov eax, [edx]
    sar eax, 8
    imul eax, [esi]
    sar eax, 8
    add ecx, eax
    add edx, 4
    add esi, 4
    dec ebx
    jnz .score_loop
    pop ebx
    sar ecx, 6
    cmp ecx, 1
    jge .score_ok
    mov ecx, 1
.score_ok:
    pop edi
    pop esi
    push esi
    push edi
    mov eax, ebx
    cmp eax, 7
    jb .vkv0
    mov eax, 1
    jmp .vkv_ready
.vkv0:
    xor eax, eax
.vkv_ready:
    imul eax, DMQ_QWEN_HEAD_DIM * 4
    add edi, eax
    mov eax, ebx
    imul eax, DMQ_QWEN_HEAD_DIM * 4
    mov edx, [llm_attn_out_base]
    add edx, eax
    push ebx
    mov ebx, DMQ_QWEN_HEAD_DIM
.value_loop:
    mov eax, [edi]
    imul eax, ecx
    sar eax, 9
    add [edx], eax
    add edi, 4
    add edx, 4
    dec ebx
    jnz .value_loop
    pop ebx
    pop edi
    pop esi
    inc ebx
    jmp .head_loop
.next_pos:
    inc ebp
    jmp .pos_loop
.done_layer:
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret
