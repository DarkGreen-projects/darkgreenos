; DarkgreenOS - cooperative KV cache state

%include "constants.inc"
%include "llm_format.inc"

extern pmm_llm_arena_kb

global llm_kv_init
global llm_kv_store
global llm_kv_load
global llm_kv_position
global llm_kv_limit

section .bss
llm_kv_position: resd 1
llm_kv_limit:    resd 1
alignb 16
; Static first-pass KV cache: 24 layers * 128 ctx * 2 kv heads * 64 dim.
; Dword fixed-point K and V are separated to simplify addressing.
llm_kv_keys:      resd (DMQ_QWEN_LAYERS * 128 * DMQ_QWEN_KV_HEADS * DMQ_QWEN_HEAD_DIM)
llm_kv_values:    resd (DMQ_QWEN_LAYERS * 128 * DMQ_QWEN_KV_HEADS * DMQ_QWEN_HEAD_DIM)

section .text
llm_kv_init:
    mov dword [llm_kv_position], 0
    mov eax, [pmm_llm_arena_kb]
    cmp eax, 65536
    jae .large
    mov dword [llm_kv_limit], 64
    ret
.large:
    cmp eax, 131072
    jae .full
    mov dword [llm_kv_limit], 128
    ret
.full:
    mov dword [llm_kv_limit], 128
    ret

; llm_kv_store(eax=layer, ebx=pos, esi=k[128], edi=v[128]) -> eax=1/0
llm_kv_store:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp
    cmp eax, DMQ_QWEN_LAYERS
    jae .bad
    cmp ebx, [llm_kv_limit]
    jae .bad
    mov edx, eax
    imul edx, 128
    add edx, ebx
    imul edx, DMQ_QWEN_KV_HEADS * DMQ_QWEN_HEAD_DIM * 4
    lea ebp, [llm_kv_keys + edx]
    mov ecx, DMQ_QWEN_KV_HEADS * DMQ_QWEN_HEAD_DIM
.copy_k:
    mov eax, [esi]
    mov [ebp], eax
    add esi, 4
    add ebp, 4
    loop .copy_k
    lea ebp, [llm_kv_values + edx]
    mov ecx, DMQ_QWEN_KV_HEADS * DMQ_QWEN_HEAD_DIM
.copy_v:
    mov eax, [edi]
    mov [ebp], eax
    add edi, 4
    add ebp, 4
    loop .copy_v
    mov eax, 1
    jmp .out
.bad:
    xor eax, eax
.out:
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; llm_kv_load(eax=layer, ebx=pos) -> esi=K ptr, edi=V ptr, eax=1/0
llm_kv_load:
    cmp eax, DMQ_QWEN_LAYERS
    jae .load_bad
    cmp ebx, [llm_kv_limit]
    jae .load_bad
    mov edx, eax
    imul edx, 128
    add edx, ebx
    imul edx, DMQ_QWEN_KV_HEADS * DMQ_QWEN_HEAD_DIM * 4
    lea esi, [llm_kv_keys + edx]
    lea edi, [llm_kv_values + edx]
    mov eax, 1
    ret
.load_bad:
    xor eax, eax
    ret
