; DarkgreenOS - byte-vocab logits projection

%include "constants.inc"
%include "llm_format.inc"

global llm_logits_step
global llm_logits_next_token
global llm_logits_top_ids
global llm_logits_top_scores
global llm_next_token

extern llm_byte_token_map
extern llm_sample_topk
extern llm_tensor_find
extern llm_q4_row_to_vec
extern llm_tokenizer_vocab_size
extern llm_detok_table_ptr

section .bss
llm_next_token: resd 1
llm_logits_top_ids: resd 16
llm_logits_top_scores: resd 16
llm_logits_weight: resd 1
llm_logits_hidden: resd 1
llm_logits_vocab_limit: resd 1
llm_logits_row: resd DMQ_QWEN_HIDDEN

section .rodata
token_table:
    db " etaoinshrlducmfwypvbgkqjxz.,!?0123456789"
token_table_end:
tensor_lm_head: db "lm_head.weight", 0
tensor_embed:   db "model.embed_tokens.weight", 0

section .text
; llm_logits_step(eax=state) -> al=next byte token
llm_logits_step:
    push ebx
    push ecx
    push edx
    mov ebx, eax
    xor edx, edx
    mov ecx, token_table_end - token_table
    div ecx
    movzx eax, byte [token_table + edx]
    mov [llm_next_token], eax
    pop edx
    pop ecx
    pop ebx
    ret

; llm_logits_next_token(esi=hidden[896], ebx=seed) -> eax=Qwen token id.
; Streams the full tokenizer/model vocabulary and keeps only top-k candidates.
llm_logits_next_token:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    mov [llm_logits_hidden], esi
    mov edi, llm_logits_top_scores
    mov ecx, 16
    mov eax, 0x80000000
.clear_scores:
    mov [edi], eax
    add edi, 4
    loop .clear_scores
    mov edi, llm_logits_top_ids
    mov ecx, 16
    xor eax, eax
.clear_ids:
    mov [edi], eax
    add edi, 4
    loop .clear_ids
    mov esi, tensor_lm_head
    call llm_tensor_find
    test eax, eax
    jnz .have_weight
    mov esi, tensor_embed
    call llm_tensor_find
    test eax, eax
    jz .sample
.have_weight:
    mov [llm_logits_weight], eax
    mov edx, [eax + DMQ2_TENSOR_DIM0_OFF]
    mov ecx, [llm_tokenizer_vocab_size]
    test ecx, ecx
    jnz .have_tokenizer_vocab
    mov ecx, edx
.have_tokenizer_vocab:
    cmp ecx, edx
    jbe .limit_ok
    mov ecx, edx
.limit_ok:
    mov [llm_logits_vocab_limit], ecx
    xor edx, edx
.candidate_loop:
    cmp edx, [llm_logits_vocab_limit]
    jae .sample
    push edx
    mov ebx, [llm_detok_table_ptr]
    test ebx, ebx
    jz .detok_ok
    cmp dword [ebx + edx * 8 + 4], 0
    je .candidate_skip
.detok_ok:
    mov eax, [llm_logits_weight]
    mov ebx, edx
    mov edi, llm_logits_row
    call llm_q4_row_to_vec
    test eax, eax
    jz .candidate_skip
    mov esi, [llm_logits_hidden]
    mov edi, llm_logits_row
    mov ecx, DMQ_QWEN_HIDDEN
    xor eax, eax
.score_loop:
    mov ebx, [esi]
    sar ebx, 8
    imul ebx, [edi]
    sar ebx, 8
    add eax, ebx
    add esi, 4
    add edi, 4
    dec ecx
    jnz .score_loop
    pop edx
    call insert_topk
    inc edx
    jmp .candidate_loop
.candidate_skip:
    pop edx
    inc edx
    jmp .candidate_loop
.sample:
    call llm_sample_topk
    mov [llm_next_token], eax
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; insert_topk(eax=score, edx=token id)
insert_topk:
    push ebx
    push ecx
    push edi
    xor ecx, ecx
.find_slot:
    cmp ecx, 16
    jae .done
    cmp eax, [llm_logits_top_scores + ecx * 4]
    jg .insert
    inc ecx
    jmp .find_slot
.insert:
    mov ebx, 15
.shift:
    cmp ebx, ecx
    jle .store
    mov edi, [llm_logits_top_scores + ebx * 4 - 4]
    mov [llm_logits_top_scores + ebx * 4], edi
    mov edi, [llm_logits_top_ids + ebx * 4 - 4]
    mov [llm_logits_top_ids + ebx * 4], edi
    dec ebx
    jmp .shift
.store:
    mov [llm_logits_top_scores + ecx * 4], eax
    mov edi, edx
    mov [llm_logits_top_ids + ecx * 4], edi
.done:
    pop edi
    pop ecx
    pop ebx
    ret
