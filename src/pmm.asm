; DarkgreenOS - minimal physical memory admission for LLM arenas

%include "constants.inc"

extern kernel_start
extern kernel_end
extern mb2_total_ram_kb
extern mb2_model_size

global pmm_init
global pmm_free_kb
global pmm_llm_arena_kb
global pmm_llm_allowed
global pmm_model_kb

section .bss
pmm_free_kb:       resd 1
pmm_llm_arena_kb:  resd 1
pmm_llm_allowed:   resd 1
pmm_model_kb:      resd 1

section .text
pmm_init:
    push ebx
    push edx
    mov dword [pmm_llm_allowed], 0
    mov dword [pmm_llm_arena_kb], 0
    mov eax, [mb2_model_size]
    test eax, eax
    jz .no_model
    add eax, 1023
    shr eax, 10
    mov [pmm_model_kb], eax
    jmp .have_model_kb
.no_model:
    mov dword [pmm_model_kb], 0
.have_model_kb:
    mov eax, [mb2_total_ram_kb]
    test eax, eax
    jz .done

    ; Reserve low memory, kernel, framebuffer/scratch margin; optional GRUB model.
    mov ebx, kernel_end
    sub ebx, kernel_start
    add ebx, 1023
    shr ebx, 10
    add ebx, 65536
    add ebx, [pmm_model_kb]
    cmp eax, ebx
    jbe .done
    sub eax, ebx
    mov [pmm_free_kb], eax

    cmp dword [pmm_model_kb], 0
    je .done
    cmp eax, LLM_MIN_ARENA_KB
    jb .done
    mov edx, eax
    shr edx, 1
    cmp edx, LLM_TARGET_ARENA_KB
    jbe .arena_ok
    mov edx, LLM_TARGET_ARENA_KB
.arena_ok:
    mov [pmm_llm_arena_kb], edx
    mov dword [pmm_llm_allowed], 1
.done:
    pop edx
    pop ebx
    ret
