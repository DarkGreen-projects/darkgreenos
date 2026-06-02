; DarkgreenOS - Multiboot 2 info parser (framebuffer + basic memory)

%include "constants.inc"

extern ptr_in_identity_map
extern multiboot_info_ptr
extern fb_init_from_mb2
extern sysres_set_mem_kb

section .bss
global mb2_model_start
global mb2_model_end
global mb2_model_size
global mb2_model_cmdline
global mb2_memory_start
global mb2_memory_end
global mb2_memory_size
global mb2_memory_cmdline
global mb2_mmap_addr
global mb2_mmap_length
global mb2_mmap_entry_size
global mb2_mmap_entry_version
global mb2_mmap_count
global mb2_total_ram_kb
mb2_model_start:         resd 1
mb2_model_end:           resd 1
mb2_model_size:          resd 1
mb2_model_cmdline:       resd 1
mb2_memory_start:        resd 1
mb2_memory_end:          resd 1
mb2_memory_size:         resd 1
mb2_memory_cmdline:      resd 1
mb2_mmap_addr:           resd 1
mb2_mmap_length:         resd 1
mb2_mmap_entry_size:     resd 1
mb2_mmap_entry_version:  resd 1
mb2_mmap_count:          resd 1
mb2_total_ram_kb:        resd 1
mb2_module_match:        resd 1

section .text
global mb2_parse

mb2_parse:
    push ebx
    push esi
    push edi
    mov dword [mb2_model_start], 0
    mov dword [mb2_model_end], 0
    mov dword [mb2_model_size], 0
    mov dword [mb2_model_cmdline], 0
    mov dword [mb2_memory_start], 0
    mov dword [mb2_memory_end], 0
    mov dword [mb2_memory_size], 0
    mov dword [mb2_memory_cmdline], 0
    mov dword [mb2_mmap_addr], 0
    mov dword [mb2_mmap_length], 0
    mov dword [mb2_mmap_entry_size], 0
    mov dword [mb2_mmap_entry_version], 0
    mov dword [mb2_mmap_count], 0
    mov dword [mb2_total_ram_kb], 0
    mov esi, [multiboot_info_ptr]
    test esi, esi
    jz .done
    add esi, 8
.tag_loop:
    cmp dword [esi], MB2_TAG_END
    je .done
    mov eax, [esi]
    cmp eax, MB2_TAG_FB_INFO
    je .tag_fb
    cmp eax, MB2_TAG_BASIC_MEM
    je .tag_mem
    cmp eax, MB2_TAG_MODULE
    je .tag_module
    cmp eax, MB2_TAG_MMAP
    je .tag_mmap
.next:
    mov eax, [esi + 4]
    add eax, 7
    and eax, ~7
    add esi, eax
    jmp .tag_loop
.tag_fb:
    ; Multiboot2 framebuffer tag:
    ; +8 addr_low, +12 addr_high, +16 pitch, +20 width, +24 height, +28 bpp.
    mov eax, [esi + 8]
    mov ebx, [esi + 20]
    mov ecx, [esi + 24]
    mov edx, [esi + 16]
    movzx edi, byte [esi + 28]
    push edi
    push edx
    push ecx
    push ebx
    push eax
    call fb_init_from_mb2
    add esp, 20
    jmp .next
.tag_mem:
    mov eax, [esi + 8]
    add eax, [esi + 12]
    mov [mb2_total_ram_kb], eax
    push eax
    call sysres_set_mem_kb
    add esp, 4
    jmp .next
.tag_module:
    mov eax, [esi + 8]
    mov ebx, [esi + 12]
    cmp ebx, eax
    jbe .next
    mov edx, esi
    lea ecx, [edx + 16]
    push eax
    push ebx
    push edx
    push ecx
    mov esi, ecx
    mov edi, mod_model
    call mb2_prefix
    movzx eax, al
    mov [mb2_module_match], eax
    pop ecx
    pop edx
    pop ebx
    pop eax
    mov esi, edx
    cmp dword [mb2_module_match], 0
    jnz .store_model
    push eax
    push ebx
    push edx
    push ecx
    mov esi, ecx
    mov edi, mod_memory
    call mb2_prefix
    movzx eax, al
    mov [mb2_module_match], eax
    pop ecx
    pop edx
    pop ebx
    pop eax
    mov esi, edx
    cmp dword [mb2_module_match], 0
    jnz .store_memory
    jmp .next
.store_model:
    cmp dword [mb2_model_start], 0
    jne .next
    mov [mb2_model_start], eax
    mov [mb2_model_end], ebx
    sub ebx, eax
    mov [mb2_model_size], ebx
    mov [mb2_model_cmdline], ecx
    jmp .next
.store_memory:
    cmp dword [mb2_memory_start], 0
    jne .next
    mov [mb2_memory_start], eax
    mov [mb2_memory_end], ebx
    sub ebx, eax
    mov [mb2_memory_size], ebx
    mov [mb2_memory_cmdline], ecx
    jmp .next
.tag_mmap:
    lea eax, [esi + 16]
    mov [mb2_mmap_addr], eax
    mov eax, [esi + 4]
    sub eax, 16
    mov [mb2_mmap_length], eax
    mov eax, [esi + 8]
    mov [mb2_mmap_entry_size], eax
    mov eax, [esi + 12]
    mov [mb2_mmap_entry_version], eax
    call mb2_count_mmap
    jmp .next
.done:
    pop edi
    pop esi
    pop ebx
    ret

mb2_count_mmap:
    push ebx
    push ecx
    push edx
    push esi
    xor ecx, ecx
    xor edx, edx
    mov esi, [mb2_mmap_addr]
    mov ebx, [mb2_mmap_length]
.loop:
    cmp ebx, [mb2_mmap_entry_size]
    jb .done
    cmp ecx, MB2_MMAP_MAX_ENTRIES
    jae .done
    cmp dword [esi + 16], MMAP_TYPE_RAM
    jne .next
    mov eax, [esi + 8]
    shr eax, 10
    add edx, eax
.next:
    inc ecx
    mov eax, [mb2_mmap_entry_size]
    add esi, eax
    sub ebx, eax
    jmp .loop
.done:
    mov [mb2_mmap_count], ecx
    test edx, edx
    jz .out
    mov [mb2_total_ram_kb], edx
    push edx
    call sysres_set_mem_kb
    add esp, 4
.out:
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

mb2_prefix:
    push ebx
.loop:
    mov al, [edi]
    test al, al
    jz .yes
    mov bl, [esi]
    cmp bl, al
    jne .no
    inc esi
    inc edi
    jmp .loop
.yes:
    mov al, 1
    jmp .done
.no:
    xor al, al
.done:
    pop ebx
    ret

section .rodata
mod_model:  db "darkmind.model", 0
mod_memory: db "darkmind.memory", 0
