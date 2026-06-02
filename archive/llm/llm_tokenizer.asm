; DarkgreenOS - byte-level tokenizer baseline

%include "constants.inc"
%include "llm_format.inc"

%define LLM_TOKEN_MAX 512
%define DMTOK2_MAGIC0 0x4F544D44
%define DMTOK2_MAGIC1 0x0000324B
%define DMTOK2_ENTRY_DATA_OFF 8
%define QWEN_EOS_TOKEN_ID 151645
%define DMTB_MAGIC0 0x42544D44
%define DMTB_MAGIC1 0x00000031
%define DMTB_VERSION_OFF 8
%define DMTB_VOCAB_OFF 12
%define DMTB_EOS_OFF 16
%define DMTB_HASH_SLOTS_OFF 20
%define DMTB_MAX_TOKEN_BYTES_OFF 24
%define DMTB_BYTE_MAP_OFF 28
%define DMTB_DETOK_OFF 36
%define DMTB_HASH_OFF 44
%define DMTB_STRINGS_OFF 52
%define DMTB_HASH_ENTRY_BYTES 16
%define DMTB_KERNEL_MAX_TOKEN_BYTES 16
%define DMTB_KERNEL_MAX_PROBES 64

extern llm_model_ptr

global llm_tokenizer_init
global llm_tokenize_prompt
global llm_detokenize_byte
global llm_detokenize_token
global llm_prompt_tokens
global llm_token_buffer
global llm_tokenizer_ptr
global llm_tokenizer_size
global llm_tokenizer_kind
global llm_tokenizer_ready
global llm_tokenizer_files
global llm_tokenizer_json_ptr
global llm_tokenizer_json_size
global llm_tokenizer_json_ready
global llm_tokenizer_bin_ready
global llm_tokenizer_bin_ptr
global llm_tokenizer_vocab_size
global llm_detok_table_ptr
global llm_detok_chunk_ptr
global llm_detok_chunk_len
global llm_qwen_eos_token
global llm_byte_token_map

section .bss
llm_prompt_tokens: resd 1
llm_token_buffer:  resd LLM_TOKEN_MAX
llm_tokenizer_ptr:  resd 1
llm_tokenizer_size: resd 1
llm_tokenizer_kind: resd 1
llm_tokenizer_ready: resd 1
llm_tokenizer_files: resd 1
llm_byte_token_map: resd 1
llm_tokenizer_json_ptr: resd 1
llm_tokenizer_json_size: resd 1
llm_tokenizer_json_ready: resd 1
llm_tokenizer_bin_ptr: resd 1
llm_tokenizer_bin_ready: resd 1
llm_tokenizer_vocab_size: resd 1
llm_detok_table_ptr: resd 1
llm_detok_strings_ptr: resd 1
llm_hash_table_ptr: resd 1
llm_hash_slots: resd 1
llm_max_token_bytes: resd 1
llm_detok_chunk_ptr: resd 1
llm_detok_chunk_len: resd 1
llm_qwen_eos_token: resd 1

section .text
llm_tokenizer_init:
    mov dword [llm_tokenizer_ptr], 0
    mov dword [llm_tokenizer_size], 0
    mov dword [llm_tokenizer_kind], 0
    mov dword [llm_tokenizer_ready], 0
    mov dword [llm_tokenizer_files], 0
    mov dword [llm_byte_token_map], 0
    mov dword [llm_tokenizer_json_ptr], 0
    mov dword [llm_tokenizer_json_size], 0
    mov dword [llm_tokenizer_json_ready], 0
    mov dword [llm_tokenizer_bin_ptr], 0
    mov dword [llm_tokenizer_bin_ready], 0
    mov dword [llm_tokenizer_vocab_size], 0
    mov dword [llm_detok_table_ptr], 0
    mov dword [llm_detok_strings_ptr], 0
    mov dword [llm_hash_table_ptr], 0
    mov dword [llm_hash_slots], 0
    mov dword [llm_max_token_bytes], 0
    mov dword [llm_detok_chunk_ptr], 0
    mov dword [llm_detok_chunk_len], 0
    mov dword [llm_qwen_eos_token], QWEN_EOS_TOKEN_ID
    mov eax, [llm_model_ptr]
    test eax, eax
    jz .out
    mov ebx, [eax + DMQ_TOKENIZER_OFF]
    add ebx, eax
    mov [llm_tokenizer_ptr], ebx
    mov ebx, [eax + DMQ_TOKENIZER_SIZE_OFF]
    mov [llm_tokenizer_size], ebx
    mov dword [llm_tokenizer_kind], 1
    cmp dword [eax + DMQ_VERSION_OFF], DMQ2_VERSION
    jne .out
    mov ebx, [eax + DMQ2_TOKENIZER_KIND_OFF]
    mov [llm_tokenizer_kind], ebx
    mov ebx, [llm_tokenizer_ptr]
    cmp dword [ebx], DMTOK2_MAGIC0
    jne .out
    cmp dword [ebx + 4], DMTOK2_MAGIC1
    jne .out
    mov ecx, [ebx + 8]
    mov [llm_tokenizer_files], ecx
    mov dword [llm_tokenizer_ready], 1
    call llm_find_binary_tokenizer
    call llm_find_byte_token_map
    call llm_find_tokenizer_json
    call llm_probe_qwen_json
.out:
    ret

; llm_tokenize_prompt(esi=prompt) -> eax=token count
llm_tokenize_prompt:
    cmp dword [llm_tokenizer_kind], DMQ_TOKENIZER_QWEN_BPE
    je .qwen_utf8
    push ebx
    push edi
    push esi
    mov edi, llm_token_buffer
    xor eax, eax
.loop:
    cmp eax, LLM_TOKEN_MAX
    jae .done
    mov bl, [esi]
    cmp bl, 0
    je .done
    movzx ebx, bl
    mov [edi], ebx
    add edi, 4
    inc esi
    inc eax
    jmp .loop
.done:
    mov [llm_prompt_tokens], eax
    pop esi
    pop edi
    pop ebx
    ret
.qwen_utf8:
    push ebx
    push ecx
    push edx
    push edi
    push esi
    cmp dword [llm_tokenizer_ready], 0
    je .fallback_empty
    mov edi, llm_token_buffer
    xor eax, eax
.qwen_loop:
    cmp eax, LLM_TOKEN_MAX
    jae .qwen_done
    cmp byte [esi], 0
    jz .qwen_done
    cmp dword [llm_tokenizer_bin_ready], 0
    je .qwen_byte
    call llm_lookup_longest_token
    test edx, edx
    jz .qwen_byte
    mov [edi], ebx
    add edi, 4
    add esi, edx
    inc eax
    jmp .qwen_loop
.qwen_byte:
    movzx ebx, byte [esi]
    mov ecx, [llm_byte_token_map]
    test ecx, ecx
    jz .store_id
    mov ebx, [ecx + ebx * 4]
.store_id:
    mov [edi], ebx
    add edi, 4
    inc esi
    inc eax
    jmp .qwen_loop
.qwen_done:
    mov [llm_prompt_tokens], eax
    pop esi
    pop edi
    pop edx
    pop ecx
    pop ebx
    ret
.fallback_empty:
    mov dword [llm_prompt_tokens], 0
    xor eax, eax
    pop esi
    pop edi
    pop edx
    pop ecx
    pop ebx
    ret

; llm_lookup_longest_token(esi=text) -> ebx=token id, edx=matched byte length or 0.
llm_lookup_longest_token:
    push eax
    push ecx
    push esi
    push edi
    push ebp
    xor edx, edx
    mov ecx, [llm_max_token_bytes]
    cmp ecx, DMTB_KERNEL_MAX_TOKEN_BYTES
    jbe .max_ok
    mov ecx, DMTB_KERNEL_MAX_TOKEN_BYTES
.max_ok:
    test ecx, ecx
    jz .out
.limit_loop:
    cmp ecx, 1
    jb .out
    push ecx
    mov edi, esi
.nul_check:
    cmp byte [edi], 0
    je .too_long
    inc edi
    loop .nul_check
    pop ecx
    push ecx
    call llm_hash_prefix
    pop ecx
    push ecx
    call llm_lookup_hash_exact
    pop ecx
    test edx, edx
    jnz .out
    dec ecx
    jmp .limit_loop
.too_long:
    pop ecx
    dec ecx
    jmp .limit_loop
.out:
    pop ebp
    pop edi
    pop esi
    pop ecx
    pop eax
    ret

; llm_hash_prefix(esi=text, ecx=len) -> eax=fnv1a32.
llm_hash_prefix:
    push ebx
    push ecx
    push esi
    mov eax, 2166136261
.hash_loop:
    test ecx, ecx
    jz .done
    movzx ebx, byte [esi]
    xor eax, ebx
    imul eax, 16777619
    inc esi
    dec ecx
    jmp .hash_loop
.done:
    pop esi
    pop ecx
    pop ebx
    ret

; llm_lookup_hash_exact(eax=hash, esi=text, ecx=len) -> ebx=token id, edx=len or 0.
llm_lookup_hash_exact:
    push eax
    push ecx
    push esi
    push edi
    push ebp
    xor edx, edx
    mov edi, [llm_hash_table_ptr]
    test edi, edi
    jz .out
    mov ebp, [llm_hash_slots]
    test ebp, ebp
    jz .out
    mov ebx, ebp
    dec ebx
    and ebx, eax
    mov ebp, DMTB_KERNEL_MAX_PROBES
.probe_loop:
    test ebp, ebp
    jz .out
    dec ebp
    imul ebx, DMTB_HASH_ENTRY_BYTES
    add ebx, edi
    cmp dword [ebx + 4], 0
    je .out
    cmp [ebx], eax
    jne .next
    cmp [ebx + 4], ecx
    jne .next
    push eax
    push ebx
    push ecx
    push esi
    mov edi, [llm_detok_strings_ptr]
    add edi, [ebx + 12]
.cmp_loop:
    test ecx, ecx
    jz .matched
    mov al, [esi]
    cmp al, [edi]
    jne .not_matched
    inc esi
    inc edi
    dec ecx
    jmp .cmp_loop
.matched:
    pop esi
    pop ecx
    pop ebx
    pop eax
    mov edx, [ebx + 4]
    mov ebx, [ebx + 8]
    jmp .out
.not_matched:
    pop esi
    pop ecx
    pop ebx
    pop eax
    mov edi, [llm_hash_table_ptr]
.next:
    sub ebx, edi
    shr ebx, 4
    inc ebx
    cmp ebx, [llm_hash_slots]
    jb .probe_loop
    xor ebx, ebx
    jmp .probe_loop
.out:
    pop ebp
    pop edi
    pop esi
    pop ecx
    pop eax
    ret

; llm_detokenize_byte(al=token) -> al=printable ASCII fallback
llm_detokenize_byte:
    cmp al, 32
    jae .high_ok
    mov al, ' '
    ret
.high_ok:
    cmp al, 126
    jbe .out
    mov al, '?'
.out:
    ret

; llm_detokenize_token(eax=token id) -> al=printable byte fallback.
; The full JSON reverse-vocab path is tracked by llm_tokenizer_json_ready; this
; keeps the GUI byte-oriented until the runtime line buffer accepts strings.
llm_detokenize_token:
    mov dword [llm_detok_chunk_ptr], 0
    mov dword [llm_detok_chunk_len], 0
    cmp eax, [llm_qwen_eos_token]
    je .eos
    cmp dword [llm_tokenizer_bin_ready], 0
    je .legacy
    cmp eax, [llm_tokenizer_vocab_size]
    jae .legacy
    push ebx
    push edx
    mov ebx, [llm_detok_table_ptr]
    mov edx, [ebx + eax * 8]
    mov ebx, [ebx + eax * 8 + 4]
    test ebx, ebx
    jz .bin_unknown
    add edx, [llm_detok_strings_ptr]
    mov [llm_detok_chunk_ptr], edx
    mov [llm_detok_chunk_len], ebx
    mov al, [edx]
    pop edx
    pop ebx
    ret
.bin_unknown:
    pop edx
    pop ebx
.legacy:
    cmp eax, 256
    jb llm_detokenize_byte
    push ebx
    push ecx
    mov ebx, [llm_byte_token_map]
    test ebx, ebx
    jz .unknown
    xor ecx, ecx
.reverse_loop:
    cmp ecx, 256
    jae .unknown
    cmp [ebx + ecx * 4], eax
    je .found_byte
    inc ecx
    jmp .reverse_loop
.found_byte:
    mov eax, ecx
    pop ecx
    pop ebx
    jmp llm_detokenize_byte
.unknown:
    pop ecx
    pop ebx
    mov al, '?'
    ret
.eos:
    xor al, al
    ret

llm_find_binary_tokenizer:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    mov esi, [llm_tokenizer_ptr]
    mov ecx, [esi + 8]
    add esi, 12
.entry_loop:
    test ecx, ecx
    jz .done
    mov eax, [esi]
    mov edx, eax
    mov ebx, [esi + 4]
    lea edi, [esi + DMTOK2_ENTRY_DATA_OFF]
    push esi
    push ecx
    mov esi, edi
    mov edi, binary_tokenizer_name
    call name_eq
    pop ecx
    pop esi
    test al, al
    jnz .found
    add esi, DMTOK2_ENTRY_DATA_OFF
    add esi, edx
    add esi, ebx
    add esi, 15
    and esi, ~15
    dec ecx
    jmp .entry_loop
.found:
    add esi, DMTOK2_ENTRY_DATA_OFF
    add esi, edx
    cmp dword [esi], DMTB_MAGIC0
    jne .done
    cmp dword [esi + 4], DMTB_MAGIC1
    jne .done
    mov [llm_tokenizer_bin_ptr], esi
    mov eax, [esi + DMTB_VOCAB_OFF]
    mov [llm_tokenizer_vocab_size], eax
    mov eax, [esi + DMTB_EOS_OFF]
    mov [llm_qwen_eos_token], eax
    mov eax, [esi + DMTB_BYTE_MAP_OFF]
    add eax, esi
    mov [llm_byte_token_map], eax
    mov eax, [esi + DMTB_DETOK_OFF]
    add eax, esi
    mov [llm_detok_table_ptr], eax
    mov eax, [esi + DMTB_HASH_OFF]
    add eax, esi
    mov [llm_hash_table_ptr], eax
    mov eax, [esi + DMTB_HASH_SLOTS_OFF]
    mov [llm_hash_slots], eax
    mov eax, [esi + DMTB_MAX_TOKEN_BYTES_OFF]
    mov [llm_max_token_bytes], eax
    mov eax, [esi + DMTB_STRINGS_OFF]
    add eax, esi
    mov [llm_detok_strings_ptr], eax
    mov dword [llm_tokenizer_bin_ready], 1
    mov dword [llm_tokenizer_json_ready], 1
.done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

llm_find_byte_token_map:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    mov esi, [llm_tokenizer_ptr]
    mov ecx, [esi + 8]
    add esi, 12
.entry_loop:
    test ecx, ecx
    jz .done
    mov eax, [esi]
    mov edx, eax
    mov ebx, [esi + 4]
    lea edi, [esi + DMTOK2_ENTRY_DATA_OFF]
    push esi
    push ecx
    mov esi, edi
    mov edi, byte_map_name
    call name_eq
    pop ecx
    pop esi
    test al, al
    jnz .found
    add esi, DMTOK2_ENTRY_DATA_OFF
    add esi, edx
    add esi, ebx
    add esi, 15
    and esi, ~15
    dec ecx
    jmp .entry_loop
.found:
    add esi, DMTOK2_ENTRY_DATA_OFF
    add esi, edx
    mov [llm_byte_token_map], esi
.done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

llm_find_tokenizer_json:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    mov esi, [llm_tokenizer_ptr]
    mov ecx, [esi + 8]
    add esi, 12
.entry_loop:
    test ecx, ecx
    jz .done
    mov eax, [esi]
    mov edx, eax
    mov ebx, [esi + 4]
    lea edi, [esi + DMTOK2_ENTRY_DATA_OFF]
    push esi
    push ecx
    mov esi, edi
    mov edi, tokenizer_json_name
    call name_eq
    pop ecx
    pop esi
    test al, al
    jnz .found
    add esi, DMTOK2_ENTRY_DATA_OFF
    add esi, edx
    add esi, ebx
    add esi, 15
    and esi, ~15
    dec ecx
    jmp .entry_loop
.found:
    add esi, DMTOK2_ENTRY_DATA_OFF
    add esi, edx
    mov [llm_tokenizer_json_ptr], esi
    mov [llm_tokenizer_json_size], ebx
.done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

llm_probe_qwen_json:
    push eax
    push ecx
    push esi
    mov esi, [llm_tokenizer_json_ptr]
    mov ecx, [llm_tokenizer_json_size]
    test esi, esi
    jz .out
    test ecx, ecx
    jz .out
    mov eax, qwen_model_key
    call json_contains
    test al, al
    jz .out
    mov esi, [llm_tokenizer_json_ptr]
    mov ecx, [llm_tokenizer_json_size]
    mov eax, qwen_vocab_key
    call json_contains
    test al, al
    jz .out
    mov esi, [llm_tokenizer_json_ptr]
    mov ecx, [llm_tokenizer_json_size]
    mov eax, qwen_merges_key
    call json_contains
    test al, al
    jz .out
    mov dword [llm_tokenizer_json_ready], 1
.out:
    pop esi
    pop ecx
    pop eax
    ret

; json_contains(esi=blob, ecx=size, eax=needle zero string) -> al=1/0
json_contains:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    mov edi, eax
.outer:
    test ecx, ecx
    jz .no
    push esi
    push edi
    push ecx
.inner:
    mov bl, [edi]
    test bl, bl
    jz .yes
    test ecx, ecx
    jz .inner_no
    cmp [esi], bl
    jne .inner_no
    inc esi
    inc edi
    dec ecx
    jmp .inner
.inner_no:
    pop ecx
    pop edi
    pop esi
    inc esi
    dec ecx
    jmp .outer
.yes:
    add esp, 12
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

name_eq:
    push ebx
.loop:
    mov bl, [edi]
    test bl, bl
    jz .end_name
    cmp al, 0
    je .no
    cmp [esi], bl
    jne .no
    inc esi
    inc edi
    dec eax
    jmp .loop
.end_name:
    cmp eax, 0
    jne .no
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop ebx
    ret

section .rodata
byte_map_name: db "darkmind_byte_tokens.bin", 0
binary_tokenizer_name: db "darkmind_tokenizer.bin", 0
tokenizer_json_name: db "tokenizer.json", 0
qwen_model_key: db '"model"', 0
qwen_vocab_key: db '"vocab"', 0
qwen_merges_key: db '"merges"', 0
