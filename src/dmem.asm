; DarkgreenOS - DarkMind Mini persistent memory runtime

%include "constants.inc"
%include "dmem_format.inc"

extern mb2_memory_start
extern mb2_memory_end
extern mb2_memory_size
extern brain_ctx
extern rmgr_profile_blob

global dmem_init
global dmem_query
global dmem_append_interaction
global dmem_profile_load
global dmem_profile_write
global dmem_profile_export
global dmem_ready
global dmem_ptr
global dmem_size
global dmem_result

section .bss
dmem_ready:  resd 1
dmem_ptr:    resd 1
dmem_size:   resd 1
dmem_result: resb DMEM_QUERY_BYTES
dmem_append: resb DMEM_APPEND_BYTES

section .rodata
mem_none:    db "memoria persistente non caricata", 0
mem_prefix:  db "memoria rilevante: ", 0
mem_after_q: db " domanda=", 0
mem_after_a: db " risposta=", 0
export_hex_digits: db "0123456789ABCDEF", 0

section .text
dmem_init:
    mov dword [dmem_ready], 0
    mov dword [dmem_ptr], 0
    mov dword [dmem_size], 0
    mov eax, [mb2_memory_start]
    test eax, eax
    jz .out
    mov ebx, [mb2_memory_end]
    cmp ebx, eax
    jbe .out
    mov ecx, [mb2_memory_size]
    cmp ecx, DMEM_HEADER_BYTES
    jb .out
    cmp dword [eax + DMEM_MAGIC_OFF], DARKMIND_MEM_MAGIC
    jne .out
    cmp dword [eax + DMEM_VERSION_OFF], DMEM_VERSION
    jne .out
    cmp dword [eax + DMEM_HEADER_BYTES_OFF], DMEM_HEADER_BYTES
    jne .out
    cmp dword [eax + DMEM_CAPACITY_OFF], ecx
    ja .out
    mov [dmem_ptr], eax
    mov [dmem_size], ecx
    mov dword [dmem_ready], 1
.out:
    ret

; dmem_query(esi=prompt) -> eax=dmem_result
dmem_query:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    mov edi, dmem_result
    mov ecx, DMEM_QUERY_BYTES
    xor al, al
    rep stosb
    mov edi, dmem_result
    cmp dword [dmem_ready], 0
    jne .scan
    mov esi, mem_none
    call append_str
    jmp .done
.scan:
    push esi
    mov esi, mem_prefix
    call append_str
    pop esi
    mov ebx, [dmem_ptr]
    mov edx, [ebx + DMEM_RECORD_COUNT_OFF]
    add ebx, DMEM_HEADER_BYTES
.record_loop:
    test edx, edx
    jz .done
    mov ecx, [ebx + DMEM_RECORD_TEXT_LEN_OFF]
    test ecx, ecx
    jz .done
    cmp ecx, 1024
    ja .done
    lea esi, [ebx + DMEM_RECORD_BYTES]
    call append_record
    add ebx, DMEM_RECORD_BYTES
    add ebx, ecx
    add ebx, 15
    and ebx, ~15
    dec edx
    cmp byte [dmem_result + DMEM_QUERY_BYTES - 2], 0
    jne .done
    jmp .record_loop
.done:
    mov eax, dmem_result
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; dmem_append_interaction(esi=prompt, edi=answer)
dmem_append_interaction:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    cmp dword [dmem_ready], 0
    je .out
    push edi
    mov edi, dmem_append
    mov ecx, DMEM_APPEND_BYTES
    xor al, al
    rep stosb
    mov edi, dmem_append
    push esi
    mov esi, mem_after_q
    call append_str_raw_cap
    pop esi
    call append_str_raw_cap
    mov esi, mem_after_a
    call append_str_raw_cap
    pop esi
    call append_str_raw_cap
    mov esi, dmem_append
    call append_record_to_image
.out:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; dmem_profile_load() -> al=1 if DMTP found
dmem_profile_load:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    cmp dword [dmem_ready], 0
    je .fail
    mov ebx, [dmem_ptr]
    mov edx, [ebx + DMEM_RECORD_COUNT_OFF]
    mov esi, ebx
    add esi, DMEM_HEADER_BYTES
    xor bl, bl
.scan:
    test edx, edx
    jz .fail
    cmp dword [esi + DMEM_RECORD_TYPE_OFF], DMEM_TYPE_MACHINE
    jne .next
    mov eax, [esi + DMEM_RECORD_TEXT_LEN_OFF]
    cmp eax, RMGR_PROFILE_BYTES
    jb .next
    lea edi, [esi + DMEM_RECORD_BYTES]
    cmp dword [edi], DMTP_MAGIC
    jne .next
    push esi
    push edi
    mov esi, edi
    mov edi, rmgr_profile_blob
    mov ecx, RMGR_PROFILE_BYTES
    rep movsb
    pop edi
    pop esi
    mov bl, 1
.next:
    mov eax, [esi + DMEM_RECORD_TEXT_LEN_OFF]
    add esi, DMEM_RECORD_BYTES
    add esi, eax
    add esi, 15
    and esi, ~15
    dec edx
    jnz .scan
    mov al, bl
    jmp .out
.fail:
    xor al, al
.out:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; dmem_profile_write(esi=rmgr_profile_blob)
dmem_profile_write:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    cmp dword [dmem_ready], 0
    je .out
    mov dword [esi], DMTP_MAGIC
    mov ebx, [dmem_ptr]
    mov edx, [ebx + DMEM_RECORD_COUNT_OFF]
    mov ecx, ebx
    add ecx, DMEM_HEADER_BYTES
.walk:
    test edx, edx
    jz .append
    cmp dword [ecx + DMEM_RECORD_TYPE_OFF], DMEM_TYPE_MACHINE
    jne .wnext
    mov eax, [ecx + DMEM_RECORD_TEXT_LEN_OFF]
    cmp eax, RMGR_PROFILE_BYTES
    jb .wnext
    lea edi, [ecx + DMEM_RECORD_BYTES]
    cmp dword [edi], DMTP_MAGIC
    jne .wnext
    mov esi, rmgr_profile_blob
.copy:
    mov eax, [esi]
    mov [edi], eax
    add esi, 4
    add edi, 4
    cmp esi, rmgr_profile_blob + RMGR_PROFILE_BYTES
    jb .copy
    jmp .out
.wnext:
    mov eax, [ecx + DMEM_RECORD_TEXT_LEN_OFF]
    add ecx, DMEM_RECORD_BYTES
    add ecx, eax
    add ecx, 15
    and ecx, ~15
    dec edx
    jmp .walk
.append:
    mov edi, ebx
    add edi, [ebx + DMEM_WRITE_OFF]
    cmp edi, DMEM_HEADER_BYTES
    jb .out
    add edi, ebx
    mov edx, ebx
    add edx, [ebx + DMEM_CAPACITY_OFF]
    mov ecx, RMGR_PROFILE_BYTES
    mov eax, edi
    add eax, DMEM_RECORD_BYTES
    add eax, ecx
    add eax, 15
    and eax, ~15
    cmp eax, edx
    ja .out
    mov dword [edi + DMEM_RECORD_TYPE_OFF], DMEM_TYPE_MACHINE
    mov dword [edi + DMEM_RECORD_FLAGS_OFF], 0
    mov dword [edi + DMEM_RECORD_TEXT_LEN_OFF], RMGR_PROFILE_BYTES
    add edi, DMEM_RECORD_BYTES
    mov esi, rmgr_profile_blob
    mov ecx, RMGR_PROFILE_BYTES
    rep movsb
    mov eax, edi
    sub eax, ebx
    mov [ebx + DMEM_WRITE_OFF], eax
    inc dword [ebx + DMEM_RECORD_COUNT_OFF]
.out:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; dmem_profile_export — serial hex dump via companion (edi=buf)
dmem_profile_export:
    mov esi, rmgr_profile_blob
    mov edi, dmem_result
    mov ecx, RMGR_PROFILE_BYTES
    xor eax, eax
    rep stosb
    mov edi, dmem_result
    mov ecx, RMGR_PROFILE_BYTES / 4
.export_loop:
    mov eax, [esi]
    call export_hex32
    add esi, 4
    mov al, ' '
    mov [edi], al
    inc edi
    loop .export_loop
    mov byte [edi], 0
    mov eax, dmem_result
    ret

export_hex32:
    push ebx
    push ecx
    mov ecx, 8
    mov ebx, export_hex_digits
.eh:
    mov edx, eax
    shr edx, 28
    and edx, 0x0F
    mov dl, [ebx + edx]
    mov [edi], dl
    inc edi
    shl eax, 4
    dec ecx
    jnz .eh
    pop ecx
    pop ebx
    ret

append_record_to_image:
    push eax
    push ebx
    push ecx
    push edx
    push edi
    mov ebx, [dmem_ptr]
    mov edi, [ebx + DMEM_WRITE_OFF]
    cmp edi, DMEM_HEADER_BYTES
    jb .done
    add edi, ebx
    mov edx, ebx
    add edx, [ebx + DMEM_CAPACITY_OFF]
    mov ecx, DMEM_APPEND_BYTES
    call strnlen
    inc eax
    cmp eax, 8
    jb .done
    mov ecx, eax
    mov eax, edi
    add eax, DMEM_RECORD_BYTES
    add eax, ecx
    add eax, 15
    and eax, ~15
    cmp eax, edx
    ja .compact
.write:
    mov dword [edi + DMEM_RECORD_TYPE_OFF], DMEM_TYPE_CONVERSATION
    mov dword [edi + DMEM_RECORD_FLAGS_OFF], 0
    mov [edi + DMEM_RECORD_TEXT_LEN_OFF], ecx
    mov dword [edi + 12], 0
    add edi, DMEM_RECORD_BYTES
.copy:
    lodsb
    stosb
    dec ecx
    jnz .copy
    sub eax, ebx
    mov [ebx + DMEM_WRITE_OFF], eax
    inc dword [ebx + DMEM_RECORD_COUNT_OFF]
    jmp .done
.compact:
    mov dword [ebx + DMEM_RECORD_COUNT_OFF], 0
    mov dword [ebx + DMEM_WRITE_OFF], DMEM_HEADER_BYTES
    lea edi, [ebx + DMEM_HEADER_BYTES]
    mov eax, edi
    add eax, DMEM_RECORD_BYTES
    add eax, ecx
    add eax, 15
    and eax, ~15
    cmp eax, edx
    jbe .write
.done:
    pop edi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

append_record:
    push eax
.loop:
    cmp edi, dmem_result + DMEM_QUERY_BYTES - 4
    jae .done
    lodsb
    test al, al
    jz .sep
    stosb
    jmp .loop
.sep:
    mov al, ' '
    stosb
.done:
    mov byte [edi], 0
    pop eax
    ret

append_str:
    push eax
.loop:
    cmp edi, dmem_result + DMEM_QUERY_BYTES - 4
    jae .done
    lodsb
    test al, al
    jz .done
    stosb
    jmp .loop
.done:
    mov byte [edi], 0
    pop eax
    ret

append_str_raw:
    push eax
    push ebx
    lea ebx, [dmem_append + DMEM_APPEND_BYTES - 1]
.loop:
    lodsb
    test al, al
    jz .done
    cmp edi, ebx
    jae .done
    stosb
    jmp .loop
.done:
    mov byte [edi], 0
    pop ebx
    pop eax
    ret

append_str_raw_cap:
    jmp append_str_raw

strnlen:
    push ecx
    push esi
    xor eax, eax
.loop:
    test ecx, ecx
    jz .done
    cmp byte [esi + eax], 0
    je .done
    inc eax
    dec ecx
    jmp .loop
.done:
    pop esi
    pop ecx
    ret
