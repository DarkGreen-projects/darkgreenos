; DarkgreenOS - DarkMind-Q tensor directory helpers

%include "constants.inc"
%include "llm_format.inc"

extern llm_model_ptr
extern llm_model_size

global llm_tensor_dir
global llm_tensor_count
global llm_tensor_entry_bytes
global llm_tensor_init
global llm_tensor_find
global llm_tensor_payload
global llm_tensor_validate

section .bss
llm_tensor_dir:         resd 1
llm_tensor_count:       resd 1
llm_tensor_entry_bytes: resd 1

section .text
llm_tensor_init:
    mov eax, [llm_model_ptr]
    test eax, eax
    jz .no
    mov ecx, [eax + DMQ_TENSOR_COUNT_OFF]
    mov [llm_tensor_count], ecx
    mov ebx, [eax + DMQ_TENSOR_DIR_OFF]
    add ebx, eax
    mov [llm_tensor_dir], ebx
    mov dword [llm_tensor_entry_bytes], DMQ_TENSOR_BYTES
    cmp dword [eax + DMQ_VERSION_OFF], DMQ2_VERSION
    jne .out
    mov edx, [eax + DMQ2_TENSOR_BYTES_OFF]
    test edx, edx
    jz .out
    mov [llm_tensor_entry_bytes], edx
.out:
    mov eax, ebx
    ret
.no:
    xor eax, eax
    ret

; llm_tensor_find(esi=zero-terminated tensor name) -> eax=entry pointer or 0
llm_tensor_find:
    push ebx
    push ecx
    push edx
    push edi
    mov edi, [llm_tensor_dir]
    test edi, edi
    jz .not_found
    mov ebx, [llm_tensor_count]
    mov edx, [llm_tensor_entry_bytes]
.next_entry:
    test ebx, ebx
    jz .not_found
    push esi
    push edi
    mov ecx, DMQ_TENSOR_NAME_BYTES
    cmp edx, DMQ2_TENSOR_BYTES
    jne .cmp_loop
    mov ecx, DMQ2_TENSOR_NAME_BYTES
.cmp_loop:
    mov al, [esi]
    cmp al, [edi]
    jne .cmp_no
    test al, al
    jz .cmp_yes
    inc esi
    inc edi
    loop .cmp_loop
    jmp .cmp_no
.cmp_yes:
    pop edi
    pop esi
    mov eax, edi
    jmp .done
.cmp_no:
    pop edi
    pop esi
    add edi, edx
    dec ebx
    jmp .next_entry
.not_found:
    xor eax, eax
.done:
    pop edi
    pop edx
    pop ecx
    pop ebx
    ret

; llm_tensor_validate(eax=tensor entry) -> eax=1 if payload is inside model blob.
llm_tensor_validate:
    push ebx
    push ecx
    push edx
    test eax, eax
    jz .bad
    mov ebx, [llm_model_ptr]
    test ebx, ebx
    jz .bad
    mov ecx, [eax + DMQ2_TENSOR_OFFSET_OFF]
    mov edx, [eax + DMQ2_TENSOR_SIZE_OFF]
    test edx, edx
    jz .bad
    add edx, ecx
    jc .bad
    cmp edx, [llm_model_size]
    ja .bad
    cmp ecx, [ebx + DMQ_HEADER_BYTES_OFF]
    jb .bad
    mov eax, [ebx + DMQ_TENSOR_DIR_OFF]
    add eax, [ebx + DMQ_TENSOR_DIR_SIZE_OFF]
    cmp ecx, eax
    jb .bad
    mov eax, 1
    jmp .done
.bad:
    xor eax, eax
.done:
    pop edx
    pop ecx
    pop ebx
    ret

; llm_tensor_payload(eax=tensor entry) -> eax=absolute payload pointer or 0.
llm_tensor_payload:
    push ebx
    push ecx
    mov ecx, eax
    call llm_tensor_validate
    test eax, eax
    jz .none
    mov eax, [ecx + DMQ2_TENSOR_OFFSET_OFF]
    mov ebx, [llm_model_ptr]
    add eax, ebx
    jmp .out
.none:
    xor eax, eax
.out:
    pop ecx
    pop ebx
    ret
