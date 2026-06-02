; DarkgreenOS - full-system visibility (memory + kernel image + modules)

%include "constants.inc"

extern kernel_start
extern kernel_end
extern text_start
extern rodata_start
extern data_start
extern bss_start
extern vga_print
extern vga_print_ln
extern vga_putchar
extern print_hex32
extern print_dec
extern mb_has_mmap
extern mb_ensure_info
extern ptr_in_identity_map
extern mb_has_mods

global osview_init
global osview_print_kernel_map
global osview_dump
global osview_find
global osview_scan_stats
global os_stat_ram_kb
global os_stat_regions
global os_stat_kernel_bytes
global os_stat_mapped_mb

section .bss
os_stat_ram_kb:         resd 1
os_stat_regions:        resd 1
os_stat_kernel_bytes:   resd 1
os_stat_mapped_mb:      resd 1
dump_addr:              resd 1
find_needle:            resd 1
find_hits:              resd 1
find_addrs:             resd MEM_SCAN_MAX_HITS

section .data
lbl_files:      db "  [osview] kernel regions in RAM:", 0
lbl_text:       db "    .text   ", 0
lbl_rodata:     db "    .rodata ", 0
lbl_data:       db "    .data   ", 0
lbl_bss:        db "    .bss    ", 0
lbl_mod:        db "    module  ", 0
lbl_sep_range:  db " .. ", 0
lbl_find:       db "  [find] hits: ", 0
lbl_dump:       db "  [dump] ", 0
lbl_none:       db "none", 0
lbl_unmapped:   db "  (not in identity map)", 0

section .text
osview_init:
    jmp osview_scan_stats

osview_can_read:
    jmp ptr_in_identity_map

extern mb_ram_total_kb

extern rmgr_hook_enter
extern rmgr_hook_leave

osview_scan_stats:
    mov eax, RMGR_ACT_OSVIEW_SCAN
    call rmgr_hook_enter
    test al, al
    jz .skip_scan
    push ebx
    push esi
    call mb_ram_total_kb
    mov [os_stat_ram_kb], eax
    mov dword [os_stat_mapped_mb], QEMU_DEFAULT_MEM_MB
    mov eax, kernel_end
    sub eax, kernel_start
    mov [os_stat_kernel_bytes], eax
    xor ecx, ecx
    call mb_has_mmap
    test al, al
    jz .one
    call mb_ensure_info
    test al, al
    jz .one
    mov esi, [ebx + MB_MMAP_ADDR]
    mov edx, [ebx + MB_MMAP_LENGTH]
.rl:
    cmp edx, 8
    jb .done
    mov eax, esi
    call ptr_in_identity_map
    test al, al
    jz .done
    mov eax, [esi]
    test eax, eax
    jz .done
    cmp eax, edx
    ja .done
    cmp eax, 256
    ja .done
    inc ecx
    add esi, eax
    sub edx, eax
    jmp .rl
.one:
    mov ecx, 1
.done:
    mov [os_stat_regions], ecx
    pop esi
    pop ebx
    call rmgr_hook_leave
    ret
.skip_scan:
    ret

osview_print_kernel_map:
    pusha
    mov esi, lbl_files
    call vga_print_ln
    mov esi, lbl_text
    mov eax, text_start
    mov ebx, rodata_start
    call print_range
    mov esi, lbl_rodata
    mov eax, rodata_start
    mov ebx, data_start
    call print_range
    mov esi, lbl_data
    mov eax, data_start
    mov ebx, bss_start
    call print_range
    mov esi, lbl_bss
    mov eax, bss_start
    mov ebx, kernel_end
    call print_range
    call mb_has_mods
    test al, al
    jz .done
    call mb_ensure_info
    test al, al
    jz .done
    mov ecx, [ebx + MB_MODS_COUNT]
    mov esi, [ebx + MB_MODS_ADDR]
    test ecx, ecx
    jz .done
.ml:
    push ecx
    push esi
    mov eax, esi
    call ptr_in_identity_map
    test al, al
    jz .skip_mod
    mov eax, [esi + 8]
    mov ebx, [esi + 12]
    add ebx, eax
    push esi
    mov esi, lbl_mod
    call print_range
    pop esi
.skip_mod:
    pop esi
    add esi, 16
    pop ecx
    loop .ml
.done:
    popa
    ret

; print_range(esi=label, eax=start, ebx=end)
print_range:
    push ebx
    push eax
    push esi
    call vga_print
    mov eax, [esp + 4]
    call print_hex32
    mov esi, lbl_sep_range
    call vga_print
    mov eax, [esp + 8]
    call print_hex32
    add esp, 12
    call vga_print_ln
    ret

osview_dump:
    pusha
    mov esi, lbl_dump
    call vga_print
    call parse_hex_addr
    jc .bad
    mov [dump_addr], eax
    mov eax, [dump_addr]
    call osview_can_read
    test al, al
    jz .unmap
    mov ebx, [os_stat_ram_kb]
    shl ebx, 10
    test ebx, ebx
    jz .unmap
    cmp eax, ebx
    jae .unmap
    mov ecx, OSVIEW_DUMP_LINES
    imul ecx, OSVIEW_DUMP_LINE_BYTES
    add eax, ecx
    cmp eax, ebx
    ja .unmap
    mov ecx, OSVIEW_DUMP_LINES
    mov esi, [dump_addr]
.dline:
    push ecx
    push esi
    mov eax, esi
    call print_hex32
    mov al, ':'
    call vga_putchar
    mov ecx, OSVIEW_DUMP_LINE_BYTES
    call dump_hex_line
    pop esi
    add esi, OSVIEW_DUMP_LINE_BYTES
    pop ecx
    loop .dline
    jmp .done
.unmap:
    mov esi, lbl_unmapped
    call vga_print_ln
    jmp .done
.bad:
    mov esi, lbl_none
    call vga_print_ln
.done:
    popa
    ret

dump_hex_line:
    push esi
    push ecx
.dh:
    lodsb
    mov ah, al
    mov al, ah
    shr al, 4
    call print_nibble
    mov al, ah
    and al, 0x0F
    call print_nibble
    mov al, ' '
    call vga_putchar
    loop .dh
    call vga_print_ln
    pop ecx
    pop esi
    ret

print_nibble:
    cmp al, 10
    jb .d
    add al, 'a' - 10
    jmp .o
.d:
    add al, '0'
.o:
    call vga_putchar
    ret

osview_find:
    pusha
    mov [find_needle], esi
    mov dword [find_hits], 0
    mov eax, kernel_start
    mov ebx, kernel_end
    call find_in_range
    mov esi, lbl_find
    call vga_print
    mov eax, [find_hits]
    call print_dec
    call vga_print_ln
    xor ecx, ecx
    mov edx, [find_hits]
    test edx, edx
    jz .done
.fshow:
    mov eax, [find_addrs + ecx * 4]
    call print_hex32
    call vga_print_ln
    inc ecx
    cmp ecx, edx
    jl .fshow
.done:
    popa
    ret

find_in_range:
    push ebx
    push edi
    push esi
.fr:
    cmp eax, ebx
    jae .out
    push eax
    push ebx
    mov edi, [find_needle]
    mov esi, eax
    call substr_at
    test al, al
    jnz .hit
    pop ebx
    pop eax
    inc eax
    jmp .fr
.hit:
    pop ebx
    pop eax
    mov ecx, [find_hits]
    cmp ecx, MEM_SCAN_MAX_HITS
    jae .out
    mov [find_addrs + ecx * 4], eax
    inc dword [find_hits]
    add eax, 1
    jmp .fr
.out:
    pop esi
    pop edi
    pop ebx
    ret

substr_at:
    push esi
    push edi
.sa:
    mov al, [edi]
    test al, al
    jz .yes
    mov bl, [esi]
    cmp al, bl
    jne .no
    inc esi
    inc edi
    jmp .sa
.yes:
    mov al, 1
    jmp .sx
.no:
    xor al, al
.sx:
    pop edi
    pop esi
    ret

parse_hex_addr:
    xor eax, eax
.ph:
    lodsb
    test al, al
    jz .ok
    cmp al, ' '
    je .ph
    cmp al, 9
    je .ph
    push eax
    call hexchar_val
    pop ebx
    jc .bad
    shl eax, 4
    or eax, ebx
    jmp .ph
.ok:
    clc
    ret
.bad:
    stc
    ret

hexchar_val:
    mov bl, al
    cmp bl, '0'
    jb .b
    cmp bl, '9'
    jbe .d
    or bl, 0x20
    cmp bl, 'a'
    jb .b
    cmp bl, 'f'
    ja .b
    movzx eax, bl
    sub eax, 'a' - 10
    clc
    ret
.d:
    movzx eax, bl
    sub eax, '0'
    clc
    ret
.b:
    stc
    ret
