; DarkgreenOS - DarkMind-Q module loader

%include "constants.inc"
%include "llm_format.inc"

extern mb2_model_start
extern mb2_model_end
extern mb2_model_size
extern pmm_llm_allowed
extern pmm_llm_arena_kb

global llm_init
global llm_model_ready
global llm_model_real
global llm_model_ptr
global llm_model_size
global llm_status_ptr

section .bss
llm_model_ready: resd 1
llm_model_real:  resd 1
llm_model_ptr:   resd 1
llm_model_size:  resd 1
llm_status_ptr:  resd 1

section .rodata
llm_status_ok:     db "[LLM] DarkMind-Q2 Qwen module validated: real Q4 decode path enabled.", 0
llm_status_stub:   db "[LLM] DarkMind-Q header valid, but this is a tiny test blob, not real Qwen weights.", 0
llm_status_nomod:  db "[LLM] no DarkMind-Q GRUB module found.", 0
llm_status_bad:    db "[LLM] DarkMind-Q module rejected: bad header, tensor directory, or range.", 0
llm_status_lowmem: db "[LLM] memory budget too small: using safe degraded mode.", 0

section .text
llm_init:
    mov dword [llm_model_ready], 0
    mov dword [llm_model_real], 0
    mov dword [llm_model_ptr], 0
    mov dword [llm_model_size], 0
    mov dword [llm_status_ptr], llm_status_nomod

    mov eax, [mb2_model_start]
    test eax, eax
    jz .out
    mov ebx, [mb2_model_end]
    cmp ebx, eax
    jbe .bad
    mov ecx, [mb2_model_size]
    cmp ecx, DMQ_HEADER_BYTES
    jb .bad
    cmp dword [eax + DMQ_MAGIC_OFF], DARKMIND_Q_MAGIC
    je .dmq1
    cmp dword [eax + DMQ_MAGIC_OFF], DARKMIND_Q2_MAGIC
    je .dmq2
    jmp .bad
.dmq1:
    cmp dword [eax + DMQ_VERSION_OFF], DMQ_VERSION
    jne .bad
    cmp dword [eax + DMQ_HEADER_BYTES_OFF], DMQ_HEADER_BYTES
    jne .bad
    cmp dword [eax + DMQ_MODEL_CLASS_OFF], DMQ_MODEL_CLASS_1B
    jne .bad
    cmp dword [eax + DMQ_QUANT_BITS_OFF], DMQ_QUANT_Q4
    jne .bad
    cmp dword [eax + DMQ_VOCAB_SIZE_OFF], DMQ_BYTE_VOCAB_SIZE
    jne .bad
    call llm_validate_ranges
    test eax, eax
    jz .bad
    mov eax, [mb2_model_start]
    mov ecx, [mb2_model_size]
    jmp .accept_stub
.dmq2:
    cmp dword [eax + DMQ_VERSION_OFF], DMQ2_VERSION
    jne .bad
    cmp dword [eax + DMQ_HEADER_BYTES_OFF], DMQ_HEADER_BYTES
    jne .bad
    cmp dword [eax + DMQ_MODEL_CLASS_OFF], DMQ_MODEL_CLASS_QWEN25_05B
    jne .bad
    cmp dword [eax + DMQ_QUANT_BITS_OFF], DMQ_QUANT_Q4
    jne .bad
    cmp dword [eax + DMQ_LAYER_COUNT_OFF], DMQ_QWEN_LAYERS
    jne .bad
    cmp dword [eax + DMQ_HIDDEN_SIZE_OFF], DMQ_QWEN_HIDDEN
    jne .bad
    cmp dword [eax + DMQ_HEAD_COUNT_OFF], DMQ_QWEN_HEADS
    jne .bad
    cmp dword [eax + DMQ_KV_HEAD_COUNT_OFF], DMQ_QWEN_KV_HEADS
    jne .bad
    cmp dword [eax + DMQ_HEAD_DIM_OFF], DMQ_QWEN_HEAD_DIM
    jne .bad
    cmp dword [eax + DMQ2_INTERMEDIATE_OFF], DMQ_QWEN_INTERMEDIATE
    jne .bad
    cmp dword [eax + DMQ2_ARCH_ID_OFF], DMQ_ARCH_QWEN2
    jne .bad
    cmp dword [eax + DMQ2_TOKENIZER_KIND_OFF], DMQ_TOKENIZER_QWEN_BPE
    jne .bad
    cmp dword [eax + DMQ2_TENSOR_BYTES_OFF], DMQ2_TENSOR_BYTES
    jne .bad
    cmp dword [eax + DMQ_VOCAB_SIZE_OFF], DMQ_QWEN_MIN_VOCAB
    jb .bad
    cmp dword [eax + DMQ_TENSOR_COUNT_OFF], DMQ_QWEN_MIN_TENSORS
    jb .bad
    call llm_validate_ranges
    test eax, eax
    jz .bad
    mov eax, [mb2_model_start]
    mov ecx, [mb2_model_size]
    cmp ecx, DMQ_REAL_MIN_BYTES
    jb .accept_stub
    jmp .accept_real

.accept_stub:
    cmp dword [pmm_llm_allowed], 0
    je .lowmem
    mov [llm_model_ptr], eax
    mov [llm_model_size], ecx
    mov dword [llm_model_ready], 1
    jmp .stub
.accept_real:
    cmp dword [pmm_llm_allowed], 0
    je .lowmem
    mov [llm_model_ptr], eax
    mov [llm_model_size], ecx
    mov dword [llm_model_ready], 1
    mov dword [llm_model_real], 1
    mov dword [llm_status_ptr], llm_status_ok
    ret
.stub:
    mov dword [llm_status_ptr], llm_status_stub
    ret
.lowmem:
    mov [llm_model_ptr], eax
    mov [llm_model_size], ecx
    mov dword [llm_status_ptr], llm_status_lowmem
    ret
.bad:
    mov dword [llm_status_ptr], llm_status_bad
.out:
    ret

llm_validate_ranges:
    push ebx
    push ecx
    push edx
    push esi
    mov eax, [mb2_model_start]
    mov ecx, [mb2_model_size]
    mov edx, [eax + DMQ_TOKENIZER_OFF]
    cmp edx, DMQ_HEADER_BYTES
    jb .no
    cmp edx, ecx
    jae .no
    mov esi, edx
    add esi, [eax + DMQ_TOKENIZER_SIZE_OFF]
    jc .no
    cmp esi, ecx
    ja .no
    mov edx, [eax + DMQ_TENSOR_DIR_OFF]
    cmp edx, DMQ_HEADER_BYTES
    jb .no
    cmp edx, ecx
    jae .no
    add edx, [eax + DMQ_TENSOR_DIR_SIZE_OFF]
    jc .no
    cmp edx, ecx
    ja .no
    mov eax, 1
    jmp .done
.no:
    xor eax, eax
.done:
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret
