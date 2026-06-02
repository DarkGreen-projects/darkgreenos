; DarkgreenOS - paging: full 4 GiB identity map (PSE, 4 MiB pages)
;
; Maps virtual [0, 4 GiB) -> physical [0, 4 GiB). Guest RAM size is QEMU -m (default 2048).
; High BIOS/GRUB data (e.g. ~0x83xxxxxx) needs VA above 2 GiB even with 2 GiB RAM.

%include "constants.inc"

section .bss
align 4096
global page_directory
page_directory:
    resd 1024

section .text
global paging_init

paging_init:
    push ebx
    push ecx
    push edi

    mov eax, cr4
    or eax, CR4_PSE
    mov cr4, eax

    mov edi, page_directory
    mov ecx, IDENTITY_MAP_MB / 4
    xor ebx, ebx
.map_loop:
    mov eax, ebx
    or eax, PDE_KERNEL_RW_4MB
    mov [edi], eax
    add ebx, 0x400000
    add edi, 4
    dec ecx
    jnz .map_loop

    mov eax, page_directory
    mov cr3, eax

    mov eax, cr0
    or eax, CR0_PG
    mov cr0, eax

    pop edi
    pop ecx
    pop ebx
    ret
