; DarkgreenOS - cooperative autoregressive decode state

%include "constants.inc"
%include "llm_format.inc"

extern llm_model_real
extern llm_tensor_find
extern llm_q4_bind_tensor
extern llm_q4_row_to_vec
extern llm_q4_gemv
extern llm_rmsnorm_vec
extern llm_rope_qk_layer0
extern llm_attention_layer0
extern llm_attention_layer
extern llm_swiglu_vec
extern llm_rmsnorm_step
extern llm_rope_step
extern llm_q4_step
extern llm_attention_step
extern llm_mlp_step
extern llm_logits_step
extern llm_logits_next_token
extern llm_kv_position
extern llm_kv_limit
extern llm_prompt_tokens
extern llm_token_buffer
extern llm_tokenizer_bin_ready

global llm_decode_begin
global llm_decode_step
global llm_decode_state
global llm_decode_pos
global llm_decode_done
global llm_decode_real_ready
global llm_layer0_verified
global llm_layer0_checksum
global llm_decode_token_id
global llm_current_token

section .bss
llm_decode_state: resd 1
llm_decode_pos:   resd 1
llm_decode_done:  resd 1
llm_decode_real_ready: resd 1
llm_decode_prompt_hash: resd 1
llm_layer0_verified: resd 1
llm_layer0_checksum: resd 1
llm_decode_token_id: resd 1
llm_current_token: resd 1
llm_current_layer: resd 1
llm_layer_name: resb 64
alignb 16
llm_act:       resd DMQ_QWEN_HIDDEN
llm_norm0:     resd DMQ_QWEN_HIDDEN
llm_q:         resd DMQ_QWEN_HIDDEN
llm_k:         resd (DMQ_QWEN_KV_HEADS * DMQ_QWEN_HEAD_DIM)
llm_v:         resd (DMQ_QWEN_KV_HEADS * DMQ_QWEN_HEAD_DIM)
llm_attn:      resd DMQ_QWEN_HIDDEN
llm_attn_proj: resd DMQ_QWEN_HIDDEN
llm_resid1:    resd DMQ_QWEN_HIDDEN
llm_norm1:     resd DMQ_QWEN_HIDDEN
llm_gate:      resd DMQ_QWEN_INTERMEDIATE
llm_up:        resd DMQ_QWEN_INTERMEDIATE
llm_swiglu:    resd DMQ_QWEN_INTERMEDIATE
llm_down:      resd DMQ_QWEN_HIDDEN

section .rodata
tensor_embed:   db "model.embed_tokens.weight", 0
tensor_norm:    db "model.norm.weight", 0
tensor_lm_head: db "lm_head.weight", 0
tensor_l0_in:   db "model.layers.0.input_layernorm.weight", 0
tensor_l0_q:    db "model.layers.0.self_attn.q_proj.weight", 0
tensor_l0_k:    db "model.layers.0.self_attn.k_proj.weight", 0
tensor_l0_v:    db "model.layers.0.self_attn.v_proj.weight", 0
tensor_l0_o:    db "model.layers.0.self_attn.o_proj.weight", 0
tensor_l0_post: db "model.layers.0.post_attention_layernorm.weight", 0
tensor_l0_gate: db "model.layers.0.mlp.gate_proj.weight", 0
tensor_l0_up:   db "model.layers.0.mlp.up_proj.weight", 0
tensor_l0_down: db "model.layers.0.mlp.down_proj.weight", 0
layer_prefix:   db "model.layers.", 0
suffix_in:      db "input_layernorm.weight", 0
suffix_q:       db "self_attn.q_proj.weight", 0
suffix_k:       db "self_attn.k_proj.weight", 0
suffix_v:       db "self_attn.v_proj.weight", 0
suffix_o:       db "self_attn.o_proj.weight", 0
suffix_post:    db "post_attention_layernorm.weight", 0
suffix_gate:    db "mlp.gate_proj.weight", 0
suffix_up:      db "mlp.up_proj.weight", 0
suffix_down:    db "mlp.down_proj.weight", 0

section .text
; llm_decode_begin(esi=prompt)
llm_decode_begin:
    push ebx
    push esi
    xor eax, eax
.hash:
    mov bl, [esi]
    test bl, bl
    jz .done_hash
    movzx ebx, bl
    imul eax, 16777619
    xor eax, ebx
    inc esi
    jmp .hash
.done_hash:
    test eax, eax
    jnz .seed_ok
    mov eax, 0xD4614B1D
.seed_ok:
    mov [llm_decode_state], eax
    mov [llm_decode_prompt_hash], eax
    mov dword [llm_decode_pos], 0
    mov dword [llm_decode_done], 0
    mov dword [llm_decode_real_ready], 0
    mov dword [llm_layer0_verified], 0
    mov dword [llm_layer0_checksum], 0
    mov dword [llm_decode_token_id], 0
    mov dword [llm_current_token], 0
    mov dword [llm_current_layer], 0
    cmp dword [llm_model_real], 0
    je .not_real
    call llm_prefill_prompt_state
    mov esi, tensor_embed
    call require_tensor
    test eax, eax
    jz .not_real
    mov esi, tensor_norm
    call require_tensor
    test eax, eax
    jz .not_real
    mov esi, tensor_l0_in
    call require_tensor
    test eax, eax
    jz .not_real
    mov esi, tensor_l0_q
    call require_tensor
    test eax, eax
    jz .not_real
    mov esi, tensor_l0_k
    call require_tensor
    test eax, eax
    jz .not_real
    mov esi, tensor_l0_v
    call require_tensor
    test eax, eax
    jz .not_real
    mov esi, tensor_l0_o
    call require_tensor
    test eax, eax
    jz .not_real
    mov esi, tensor_l0_post
    call require_tensor
    test eax, eax
    jz .not_real
    mov esi, tensor_l0_gate
    call require_tensor
    test eax, eax
    jz .not_real
    mov esi, tensor_l0_up
    call require_tensor
    test eax, eax
    jz .not_real
    mov esi, tensor_l0_down
    call require_tensor
    test eax, eax
    jz .not_real
    call llm_decode_layer0_probe
    test eax, eax
    jz .not_real
    cmp dword [llm_tokenizer_bin_ready], 0
    je .not_real
    mov dword [llm_decode_real_ready], 1
.not_real:
    pop esi
    pop ebx
    ret

llm_prefill_prompt_state:
    push eax
    push ebx
    push ecx
    mov ecx, [llm_prompt_tokens]
    test ecx, ecx
    jz .out
    cmp ecx, [llm_kv_limit]
    jbe .limit_ok
    mov ecx, [llm_kv_limit]
.limit_ok:
    mov dword [llm_decode_pos], 0
    mov [llm_kv_position], ecx
    dec dword [llm_kv_position]
    dec ecx
    mov eax, [llm_token_buffer + ecx * 4]
    mov [llm_current_token], eax
    mov [llm_decode_token_id], eax
    xor [llm_decode_state], eax
.out:
    pop ecx
    pop ebx
    pop eax
    ret

require_tensor:
    call llm_tensor_find
    test eax, eax
    jz .out
    cmp dword [eax + DMQ2_TENSOR_DTYPE_OFF], DMQ_DTYPE_Q4_0
    je .ok
    cmp dword [eax + DMQ2_TENSOR_DTYPE_OFF], DMQ_DTYPE_F16
    je .ok
    xor eax, eax
    ret
.ok:
    mov eax, 1
.out:
    ret

llm_decode_layer0_probe:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    cmp dword [llm_prompt_tokens], 0
    je .fail
    mov esi, tensor_embed
    call llm_tensor_find
    test eax, eax
    jz .fail
    mov ebx, [llm_current_token]
    test ebx, ebx
    jnz .have_token
    mov ebx, [llm_token_buffer]
.have_token:
    cmp ebx, [eax + DMQ2_TENSOR_DIM0_OFF]
    jae .fail
    mov edi, llm_act
    call llm_q4_row_to_vec
    test eax, eax
    jz .fail

    mov esi, tensor_l0_in
    call llm_tensor_find
    mov esi, llm_act
    mov edi, llm_norm0
    mov ecx, DMQ_QWEN_HIDDEN
    call llm_rmsnorm_vec

    mov esi, tensor_l0_q
    call llm_tensor_find
    mov esi, llm_norm0
    mov edi, llm_q
    call llm_q4_gemv
    test eax, eax
    jz .fail
    mov esi, tensor_l0_k
    call llm_tensor_find
    mov esi, llm_norm0
    mov edi, llm_k
    call llm_q4_gemv
    test eax, eax
    jz .fail
    mov esi, tensor_l0_v
    call llm_tensor_find
    mov esi, llm_norm0
    mov edi, llm_v
    call llm_q4_gemv
    test eax, eax
    jz .fail

    mov esi, llm_q
    mov edi, llm_k
    mov ecx, [llm_decode_pos]
    call llm_rope_qk_layer0
    mov esi, llm_q
    mov edi, llm_k
    mov ebx, llm_v
    mov edx, llm_attn
    call llm_attention_layer0

    mov esi, tensor_l0_o
    call llm_tensor_find
    mov esi, llm_attn
    mov edi, llm_attn_proj
    call llm_q4_gemv
    test eax, eax
    jz .fail
    mov esi, llm_act
    mov edi, llm_attn_proj
    mov edx, llm_resid1
    mov ecx, DMQ_QWEN_HIDDEN
    call add_vec

    mov esi, tensor_l0_post
    call llm_tensor_find
    mov esi, llm_resid1
    mov edi, llm_norm1
    mov ecx, DMQ_QWEN_HIDDEN
    call llm_rmsnorm_vec

    mov esi, tensor_l0_gate
    call llm_tensor_find
    mov esi, llm_norm1
    mov edi, llm_gate
    call llm_q4_gemv
    test eax, eax
    jz .fail
    mov esi, tensor_l0_up
    call llm_tensor_find
    mov esi, llm_norm1
    mov edi, llm_up
    call llm_q4_gemv
    test eax, eax
    jz .fail
    mov esi, llm_gate
    mov edi, llm_up
    mov edx, llm_swiglu
    mov ecx, DMQ_QWEN_INTERMEDIATE
    call llm_swiglu_vec
    mov esi, tensor_l0_down
    call llm_tensor_find
    mov esi, llm_swiglu
    mov edi, llm_down
    call llm_q4_gemv
    test eax, eax
    jz .fail
    mov esi, llm_resid1
    mov edi, llm_down
    mov edx, llm_act
    mov ecx, DMQ_QWEN_HIDDEN
    call add_vec
    mov esi, llm_act
    mov ecx, DMQ_QWEN_HIDDEN
    call checksum_vec
    mov [llm_layer0_checksum], eax
    mov dword [llm_layer0_verified], 1
    mov eax, 1
    jmp .out_probe
.fail:
    xor eax, eax
.out_probe:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; load_current_embedding() -> eax=1/0, updates llm_act from llm_current_token.
load_current_embedding:
    push ebx
    push esi
    push edi
    mov esi, tensor_embed
    call llm_tensor_find
    test eax, eax
    jz .fail
    mov ebx, [llm_current_token]
    cmp ebx, [eax + DMQ2_TENSOR_DIM0_OFF]
    jae .fail
    mov edi, llm_act
    call llm_q4_row_to_vec
    test eax, eax
    jz .fail
    mov eax, 1
    jmp .out
.fail:
    xor eax, eax
.out:
    pop edi
    pop esi
    pop ebx
    ret

; apply_final_norm() -> eax=1/0, normalizes llm_act before lm_head logits.
apply_final_norm:
    push ecx
    push esi
    push edi
    mov esi, tensor_norm
    call llm_tensor_find
    test eax, eax
    jz .fail
    mov esi, llm_act
    mov edi, llm_norm0
    mov ecx, DMQ_QWEN_HIDDEN
    call llm_rmsnorm_vec
    mov esi, llm_norm0
    mov edi, llm_act
    mov ecx, DMQ_QWEN_HIDDEN
.copy_loop:
    mov eax, [esi]
    mov [edi], eax
    add esi, 4
    add edi, 4
    dec ecx
    jnz .copy_loop
    mov eax, 1
    jmp .out
.fail:
    xor eax, eax
.out:
    pop edi
    pop esi
    pop ecx
    ret

; find_layer_tensor(eax=layer, esi=suffix after "model.layers.N.") -> eax=entry/0
find_layer_tensor:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    mov ebx, eax
    mov edx, esi
    mov edi, llm_layer_name
    mov esi, layer_prefix
.copy_prefix:
    lodsb
    test al, al
    jz .layer_digits
    stosb
    jmp .copy_prefix
.layer_digits:
    cmp ebx, 10
    jb .one_digit
    mov al, '1'
    cmp ebx, 20
    jb .tens_done
    mov al, '2'
.tens_done:
    stosb
    mov eax, ebx
    xor ecx, ecx
    mov cl, 10
    div cl
    mov al, ah
    add al, '0'
    stosb
    jmp .dot
.one_digit:
    mov eax, ebx
    add al, '0'
    stosb
.dot:
    mov al, '.'
    stosb
    mov esi, edx
.copy_suffix:
    lodsb
    stosb
    test al, al
    jnz .copy_suffix
    mov esi, llm_layer_name
    call llm_tensor_find
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; llm_decode_layer_forward(eax=layer) -> eax=1/0, updates llm_act
llm_decode_layer_forward:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    mov [llm_current_layer], eax
    mov esi, suffix_in
    call find_layer_tensor
    test eax, eax
    jz .fail
    mov esi, llm_act
    mov edi, llm_norm0
    mov ecx, DMQ_QWEN_HIDDEN
    call llm_rmsnorm_vec
    mov eax, [llm_current_layer]
    mov esi, suffix_q
    call find_layer_tensor
    test eax, eax
    jz .fail
    mov esi, llm_norm0
    mov edi, llm_q
    call llm_q4_gemv
    test eax, eax
    jz .fail
    mov eax, [llm_current_layer]
    mov esi, suffix_k
    call find_layer_tensor
    test eax, eax
    jz .fail
    mov esi, llm_norm0
    mov edi, llm_k
    call llm_q4_gemv
    test eax, eax
    jz .fail
    mov eax, [llm_current_layer]
    mov esi, suffix_v
    call find_layer_tensor
    test eax, eax
    jz .fail
    mov esi, llm_norm0
    mov edi, llm_v
    call llm_q4_gemv
    test eax, eax
    jz .fail
    mov esi, llm_q
    mov edi, llm_k
    mov ecx, [llm_decode_pos]
    call llm_rope_qk_layer0
    mov eax, [llm_current_layer]
    mov esi, llm_q
    mov edi, llm_k
    mov ebx, llm_v
    mov edx, llm_attn
    call llm_attention_layer
    mov eax, [llm_current_layer]
    mov esi, suffix_o
    call find_layer_tensor
    test eax, eax
    jz .fail
    mov esi, llm_attn
    mov edi, llm_attn_proj
    call llm_q4_gemv
    test eax, eax
    jz .fail
    mov esi, llm_act
    mov edi, llm_attn_proj
    mov edx, llm_resid1
    mov ecx, DMQ_QWEN_HIDDEN
    call add_vec
    mov eax, [llm_current_layer]
    mov esi, suffix_post
    call find_layer_tensor
    test eax, eax
    jz .fail
    mov esi, llm_resid1
    mov edi, llm_norm1
    mov ecx, DMQ_QWEN_HIDDEN
    call llm_rmsnorm_vec
    mov eax, [llm_current_layer]
    mov esi, suffix_gate
    call find_layer_tensor
    test eax, eax
    jz .fail
    mov esi, llm_norm1
    mov edi, llm_gate
    call llm_q4_gemv
    test eax, eax
    jz .fail
    mov eax, [llm_current_layer]
    mov esi, suffix_up
    call find_layer_tensor
    test eax, eax
    jz .fail
    mov esi, llm_norm1
    mov edi, llm_up
    call llm_q4_gemv
    test eax, eax
    jz .fail
    mov esi, llm_gate
    mov edi, llm_up
    mov edx, llm_swiglu
    mov ecx, DMQ_QWEN_INTERMEDIATE
    call llm_swiglu_vec
    mov eax, [llm_current_layer]
    mov esi, suffix_down
    call find_layer_tensor
    test eax, eax
    jz .fail
    mov esi, llm_swiglu
    mov edi, llm_down
    call llm_q4_gemv
    test eax, eax
    jz .fail
    mov esi, llm_resid1
    mov edi, llm_down
    mov edx, llm_act
    mov ecx, DMQ_QWEN_HIDDEN
    call add_vec
    mov eax, 1
    jmp .out
.fail:
    xor eax, eax
.out:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

add_vec:
    push eax
    push esi
    push edi
    push edx
.add_loop:
    test ecx, ecx
    jz .add_done
    mov eax, [esi]
    add eax, [edi]
    mov [edx], eax
    add esi, 4
    add edi, 4
    add edx, 4
    dec ecx
    jmp .add_loop
.add_done:
    pop edx
    pop edi
    pop esi
    pop eax
    ret

checksum_vec:
    push ebx
    push ecx
    push esi
    xor eax, eax
.sum_loop:
    test ecx, ecx
    jz .sum_done
    mov ebx, [esi]
    rol eax, 5
    xor eax, ebx
    add esi, 4
    dec ecx
    jmp .sum_loop
.sum_done:
    pop esi
    pop ecx
    pop ebx
    ret

; llm_decode_step() -> al=next token, llm_decode_done=1 at limit
llm_decode_step:
    push ebx
    push ecx
    mov ecx, [llm_decode_pos]
    cmp ecx, [llm_kv_limit]
    jae decode_finish
    cmp dword [llm_model_real], 0
    je .legacy
    cmp dword [llm_decode_real_ready], 0
    je decode_finish
    call llm_decode_forward_24
    test eax, eax
    jz decode_finish
    mov esi, llm_act
    mov ebx, [llm_decode_state]
    call llm_logits_next_token
    mov [llm_decode_token_id], eax
    mov [llm_current_token], eax
    xor [llm_decode_state], eax
    inc dword [llm_decode_pos]
    inc dword [llm_kv_position]
    cmp dword [llm_decode_pos], 64
    jae decode_finish_after_token
    pop ecx
    pop ebx
    ret
.legacy:
    mov eax, [llm_decode_state]
    mov ebx, [llm_decode_prompt_hash]
    call llm_rmsnorm_step
    call llm_rope_step
    mov ebx, [llm_decode_prompt_hash]
    call llm_q4_step
    mov ebx, [llm_decode_prompt_hash]
    call llm_attention_step
    call llm_mlp_step
    mov [llm_decode_state], eax
    call llm_logits_step
    inc dword [llm_decode_pos]
    cmp dword [llm_decode_pos], 96
    jae decode_finish_after_token
    pop ecx
    pop ebx
    ret

llm_decode_forward_24:
    push ebx
    call load_current_embedding
    test eax, eax
    jz .fail
    xor ebx, ebx
.layer_loop:
    cmp ebx, DMQ_QWEN_LAYERS
    jae .done_layers
    mov eax, ebx
    call llm_decode_layer_forward
    test eax, eax
    jz .fail
    mov esi, llm_act
    mov ecx, DMQ_QWEN_HIDDEN
    call checksum_vec
    xor [llm_decode_state], eax
    inc ebx
    jmp .layer_loop
.done_layers:
    call apply_final_norm
    test eax, eax
    jz .fail
    mov eax, 1
    jmp .out
.fail:
    xor eax, eax
.out:
    pop ebx
    ret
decode_finish_after_token:
    mov dword [llm_decode_done], 1
    pop ecx
    pop ebx
    ret
decode_finish:
    mov dword [llm_decode_done], 1
    mov al, 0
    pop ecx
    pop ebx
    ret
