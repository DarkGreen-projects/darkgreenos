; DarkgreenOS - minimal read-only FS (embedded files)

%include "constants.inc"

global fs_embed_init
global fs_embed_open
global fs_embed_read
global fs_embed_close

section .bss
fs_open_slot:   resd FS_MAX_OPEN
fs_open_off:    resd FS_MAX_OPEN

section .rodata
embed_name0: db "help.txt", 0
embed_data0: db "DarkgreenOS FS Phase B - RMGR orchestrator-native kernel.", 10, 0
embed_size0 equ $ - embed_data0
embed_name1: db "version.txt", 0
embed_data1: db "0.7-orchestrator", 10, 0
embed_size1 equ $ - embed_data1
fs_file_count equ 2

section .text
fs_embed_init:
    push eax
    push ecx
    push edi
    xor eax, eax
    mov edi, fs_open_slot
    mov ecx, FS_MAX_OPEN * 2
    rep stosd
    pop edi
    pop ecx
    pop eax
    ret

; fs_open(esi=name) -> eax=fd or -1
fs_embed_open:
    push ebx
    push ecx
    push edi
    mov ebx, 0
.try0:
    cmp ebx, fs_file_count
    jge .miss
    test ebx, ebx
    jnz .try1
    mov edi, embed_name0
    jmp .match
.try1:
    mov edi, embed_name1
.match:
    push esi
    push edi
.cmp:
    mov al, [esi]
    mov ah, [edi]
    cmp al, ah
    jne .nomatch
    test al, al
    jz .got
    inc esi
    inc edi
    jmp .cmp
.nomatch:
    pop edi
    pop esi
    inc ebx
    jmp .try0
.got:
    pop edi
    pop esi
    xor ecx, ecx
.slot:
    cmp ecx, FS_MAX_OPEN
    jge .miss
    cmp dword [fs_open_slot + ecx * 4], 0
    je .use
    inc ecx
    jmp .slot
.use:
    inc ebx
    mov [fs_open_slot + ecx * 4], ebx
    mov dword [fs_open_off + ecx * 4], 0
    mov eax, ecx
    jmp .out
.miss:
    mov eax, -1
.out:
    pop edi
    pop ecx
    pop ebx
    ret

; fs_read(eax=fd, ebx=buf, ecx=len) -> eax=bytes read
fs_embed_read:
    push esi
    push edi
    push edx
    cmp eax, FS_MAX_OPEN
    jae .err
    mov edx, eax
    mov eax, [fs_open_slot + edx * 4]
    test eax, eax
    jz .err
    dec eax
    jnz .file1
    mov esi, embed_data0
    mov eax, embed_size0
    jmp .do_read
.file1:
    mov esi, embed_data1
    mov eax, embed_size1
.do_read:
    mov edi, [fs_open_off + edx * 4]
    add esi, edi
    sub eax, edi
    jbe .zero
    cmp ecx, eax
    jbe .copy
    mov ecx, eax
.copy:
    mov edi, ebx
    mov eax, ecx
    rep movsb
    add [fs_open_off + edx * 4], ecx
    mov eax, ecx
    jmp .done
.zero:
    xor eax, eax
    jmp .done
.err:
    mov eax, -1
.done:
    pop edx
    pop edi
    pop esi
    ret

fs_embed_close:
    cmp eax, FS_MAX_OPEN
    jae .out
    mov dword [fs_open_slot + eax * 4], 0
    mov dword [fs_open_off + eax * 4], 0
.out:
    ret
