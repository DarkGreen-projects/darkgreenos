; DarkgreenOS - Multiboot info parser

%include "constants.inc"

extern ptr_in_identity_map
extern mb2_parse
extern vga_print
extern vga_print_ln
extern vga_putchar
extern print_hex32
extern print_dec
extern mb2_total_ram_kb
extern mb2_mmap_count

section .bss
global multiboot_info_ptr
global multiboot_magic
multiboot_info_ptr: resd 1
multiboot_magic:    resd 1

section .data
lbl_map_hdr:    db "  [mmap] physical regions:", 0
lbl_region:     db "    ", 0
lbl_type_ram:   db "RAM", 0
lbl_type_res:   db "RES", 0
lbl_sep:        db " .. ", 0
lbl_legacy:     db "  [mmap] legacy mem (no safe mmap list)", 0

section .text
global mb_init
global mb_ensure_info
global mb_has_mmap
global mb_has_mods
global mb_print_map
global mb_ram_total_kb

; ebx = multiboot_info if ptr in identity map, else 0; al = 1 if usable
mb_ensure_info:
    mov ebx, [multiboot_info_ptr]
    test ebx, ebx
    jz .no
    mov eax, ebx
    call ptr_in_identity_map
    test al, al
    jz .no
    ret
.no:
    xor ebx, ebx
    xor al, al
    ret

; eax = boot magic, ebx = info pointer
mb_init:
    mov [multiboot_magic], eax
    cmp eax, MB2_LOADER_MAGIC
    je .mb2
    cmp eax, MULTIBOOT_MAGIC
    jne .discard
    mov eax, ebx
    call ptr_in_identity_map
    test al, al
    jz .discard
    mov [multiboot_info_ptr], ebx
    ret
.mb2:
    mov eax, ebx
    call ptr_in_identity_map
    test al, al
    jz .discard
    mov [multiboot_info_ptr], ebx
    jmp mb2_parse
.discard:
    mov dword [multiboot_info_ptr], 0
    ret

mb_has_mmap:
    call mb_ensure_info
    test al, al
    jz .no
    mov eax, [ebx + MB_FLAGS]
    test eax, MB_FLAG_MMAP
    jz .no
    mov eax, [ebx + MB_MMAP_ADDR]
    call ptr_in_identity_map
    test al, al
    jz .no
    mov eax, [ebx + MB_MMAP_LENGTH]
    test eax, eax
    jz .no
    mov al, 1
    ret
.no:
    xor al, al
    ret

mb_has_mods:
    call mb_ensure_info
    test al, al
    jz .no
    mov eax, [ebx + MB_FLAGS]
    test eax, MB_FLAG_MODS
    jz .no
    mov eax, [ebx + MB_MODS_ADDR]
    call ptr_in_identity_map
    test al, al
    jz .no
    mov al, 1
    ret
.no:
    xor al, al
    ret

mb_ram_total_kb:
    cmp dword [multiboot_magic], MB2_LOADER_MAGIC
    jne .legacy
    mov eax, [mb2_total_ram_kb]
    test eax, eax
    jnz .ret
.legacy:
    call mb_ensure_info
    test al, al
    jz .zero
    mov eax, [ebx + MB_MEM_UPPER]
    add eax, [ebx + MB_MEM_LOWER]
.ret:
    ret
.zero:
    xor eax, eax
    ret

mb_print_map:
    pusha
    call mb_has_mmap
    test al, al
    jz .legacy

    mov esi, lbl_map_hdr
    call vga_print_ln

    call mb_ensure_info
    mov esi, [ebx + MB_MMAP_ADDR]
    mov edx, [ebx + MB_MMAP_LENGTH]

.add_loop:
    cmp edx, 8
    jb .done
    mov eax, esi
    call ptr_in_identity_map
    test al, al
    jz .done
    mov ecx, [esi]
    test ecx, ecx
    je .done
    cmp ecx, edx
    ja .done
    cmp ecx, 256
    ja .done

    push esi
    push edx
    push ecx

    mov eax, [esi + 4]
    mov ebx, [esi + 8]
    mov edi, [esi + 12]

    push edi
    push ebx
    push eax
    mov esi, lbl_region
    call vga_print
    pop eax
    call print_hex32
    mov esi, lbl_sep
    call vga_print
    pop eax
    pop ebx
    add eax, ebx
    call print_hex32
    mov al, ' '
    call vga_putchar
    pop edi
    cmp edi, MMAP_TYPE_RAM
    je .ram
    mov esi, lbl_type_res
    jmp .prt
.ram:
    mov esi, lbl_type_ram
.prt:
    call vga_print_ln

    pop ecx
    pop edx
    pop esi
    add esi, ecx
    sub edx, ecx
    jmp .add_loop

.legacy:
    mov esi, lbl_legacy
    call vga_print_ln
    mov esi, lbl_region
    call vga_print
    xor eax, eax
    call print_hex32
    mov esi, lbl_sep
    call vga_print
    call mb_ram_total_kb
    mov ebx, eax
    shl ebx, 10
    mov eax, ebx
    call print_hex32
    mov esi, lbl_type_ram
    call vga_print_ln

.done:
    popa
    ret
