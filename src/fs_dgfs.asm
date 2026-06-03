; DarkgreenOS - DGFS read-write FS (GRUB module) with fs_min fallback

%include "constants.inc"

extern mb2_dgfs_start
extern mb2_dgfs_size
extern fs_embed_init
extern fs_embed_open
extern fs_embed_read
extern fs_embed_close
extern rmgr_hook_enter
extern rmgr_hook_leave
extern rmgr_free_min_kb_eff
extern pmm_free_kb
extern rmgr_profile_blob
extern rmgr_profile_reload_from_fs

global fs_init
global fs_open
global fs_read
global fs_close
global fs_write
global fs_sync
global fs_load_profile
global fs_save_profile
global fs_audit_tail_push
global fs_audit_tail_snapshot
global dgfs_active
global dgfs_profile_pending

section .bss
align 4
dgfs_active:    resd 1
dgfs_dirty:     resd 1
dgfs_defer:     resd 1
dgfs_profile_pending: resd 1
dgfs_audit_idx: resd 1
dgfs_audit_ent: resd 1
fs_open_slot:   resd FS_MAX_OPEN
fs_open_off:    resd FS_MAX_OPEN
fs_open_dgfs:   resd FS_MAX_OPEN

section .rodata
prof_name: db "rmgr.profile", 0
tail_name: db "audit.tail", 0

section .text
fs_init:
    call fs_embed_init
    xor eax, eax
    mov [dgfs_active], eax
    mov [dgfs_dirty], eax
    mov [dgfs_defer], eax
    mov [dgfs_audit_idx], eax
    mov dword [dgfs_audit_ent], -1
    mov eax, [mb2_dgfs_start]
    test eax, eax
    jz .out
    cmp dword [mb2_dgfs_size], DGFS_HEADER_BYTES
    jb .out
    cmp dword [eax], DGFS_MAGIC
    jne .out
    mov dword [dgfs_active], 1
    mov dword [dgfs_profile_pending], 1
    push esi
    mov esi, tail_name
    call dgfs_find
    cmp eax, -1
    je .out_pop
    push eax
    call dgfs_entry_ptr
    mov eax, [esi + 32]
    add eax, [mb2_dgfs_start]
    mov ebx, [eax + DGFS_AUDIT_TAIL_HEAD]
    cmp ebx, DGFS_AUDIT_TAIL_ROOM
    jb .idx_ok
    xor ebx, ebx
.idx_ok:
    mov [dgfs_audit_idx], ebx
    pop eax
    mov [dgfs_audit_ent], eax
.out_pop:
    pop esi
.out:
    ret

; fs_deferred_profile_load — once after boot when DGFS became active
global fs_deferred_profile_load
fs_deferred_profile_load:
    cmp dword [dgfs_profile_pending], 0
    je .done
    mov dword [dgfs_profile_pending], 0
    call rmgr_profile_reload_from_fs
.done:
    ret

; dgfs_find(esi=name) -> eax=index or -1
dgfs_find:
    push ebx
    push ecx
    push edi
    mov ebx, [mb2_dgfs_start]
    xor eax, eax
.loop:
    cmp eax, FS_MAX_FILES
    jge .miss
    imul ecx, eax, DGFS_ENTRY_BYTES
    lea edi, [ebx + DGFS_HEADER_BYTES + ecx]
    cmp byte [edi], 0
    je .miss
    push eax
    push esi
    push edi
.nm:
    mov al, [esi]
    mov ah, [edi]
    cmp al, ah
    jne .next
    test al, al
    jz .hit
    inc esi
    inc edi
    jmp .nm
.next:
    pop edi
    pop esi
    pop eax
    inc eax
    jmp .loop
.hit:
    pop edi
    pop esi
    pop eax
    jmp .out
.miss:
    mov eax, -1
.out:
    pop edi
    pop ecx
    pop ebx
    ret

; dgfs_entry_ptr(eax=index) -> esi=entry
dgfs_entry_ptr:
    push ebx
    mov ebx, [mb2_dgfs_start]
    imul eax, DGFS_ENTRY_BYTES
    lea esi, [ebx + DGFS_HEADER_BYTES + eax]
    pop ebx
    ret

fs_open:
    cmp dword [dgfs_active], 0
    je .embed
    push esi
    call dgfs_find
    pop esi
    cmp eax, -1
    je .embed
    push ebx
    mov ebx, eax
    xor ecx, ecx
.slot:
    cmp ecx, FS_MAX_OPEN
    jge .full
    cmp dword [fs_open_slot + ecx * 4], 0
    je .use
    inc ecx
    jmp .slot
.use:
    mov eax, ebx
    inc eax
    mov [fs_open_slot + ecx * 4], eax
    mov dword [fs_open_dgfs + ecx * 4], 1
    mov dword [fs_open_off + ecx * 4], 0
    mov eax, ecx
    pop ebx
    ret
.full:
    pop ebx
    mov eax, -1
    ret
.embed:
    jmp fs_embed_open

fs_read:
    push ebx
    push ecx
    push edx
    mov edx, eax
    cmp edx, FS_MAX_OPEN
    jae .err
    cmp dword [fs_open_dgfs + edx * 4], 0
    je .embed
    mov eax, RMGR_ACT_FS_READ
    call rmgr_hook_enter
    test al, al
    jz .deny
    mov eax, [fs_open_slot + edx * 4]
    dec eax
    push eax
    call dgfs_entry_ptr
    mov eax, [esi + 36]
    sub eax, [fs_open_off + edx * 4]
    jbe .zero
    mov ecx, [esp + 16]
    cmp ecx, eax
    jbe .n
    mov ecx, eax
.n:
    pop eax
    push eax
    call dgfs_entry_ptr
    mov eax, [esi + 32]
    add eax, [mb2_dgfs_start]
    add eax, [fs_open_off + edx * 4]
    mov esi, eax
    mov edi, [esp + 12]
    mov eax, ecx
    rep movsb
    add [fs_open_off + edx * 4], ecx
    mov eax, ecx
    jmp .done
.zero:
    add esp, 4
    xor eax, eax
.done:
    call rmgr_hook_leave
    pop edx
    pop ecx
    pop ebx
    ret
.deny:
    pop edx
    pop ecx
    pop ebx
    mov eax, -1
    ret
.embed:
    pop edx
    pop ecx
    pop ebx
    jmp fs_embed_read
.err:
    pop edx
    pop ecx
    pop ebx
    mov eax, -1
    ret

fs_close:
    cmp eax, FS_MAX_OPEN
    jae .out
    mov dword [fs_open_slot + eax * 4], 0
    mov dword [fs_open_off + eax * 4], 0
    mov dword [fs_open_dgfs + eax * 4], 0
.out:
    ret

; fs_write(fd=eax, buf=ebx, len=ecx) -> bytes written or -1
fs_write:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    mov edx, eax
    cmp dword [dgfs_active], 0
    je .fail
    cmp edx, FS_MAX_OPEN
    jae .fail
    cmp dword [fs_open_dgfs + edx * 4], 0
    je .fail
    mov eax, RMGR_ACT_FS_WRITE
    call rmgr_hook_enter
    test al, al
    jz .deny
    mov eax, [pmm_free_kb]
    cmp eax, [rmgr_free_min_kb_eff]
    jae .wr
    mov dword [dgfs_defer], 1
    jmp .deny
.wr:
    mov eax, [fs_open_slot + edx * 4]
    dec eax
    push eax
    call dgfs_entry_ptr
    test byte [esi + 40], DGFS_FLAG_READONLY
    jnz .deny_pop
    mov eax, [esi + 36]
    mov edi, [fs_open_off + edx * 4]
    sub eax, edi
    jbe .zero
    cmp ecx, eax
    jbe .n
    mov ecx, eax
.n:
    pop eax
    push eax
    call dgfs_entry_ptr
    mov eax, [esi + 32]
    add eax, [mb2_dgfs_start]
    add eax, [fs_open_off + edx * 4]
    mov edi, eax
    mov esi, ebx
    mov eax, ecx
    rep movsb
    add [fs_open_off + edx * 4], ecx
    pop eax
    push eax
    call dgfs_entry_ptr
    or dword [esi + 40], DGFS_FLAG_DIRTY
    pop eax
    mov dword [dgfs_dirty], 1
    mov eax, ecx
    jmp .done
.zero:
    add esp, 4
    xor eax, eax
    jmp .done
.deny_pop:
    pop eax
.deny:
    mov eax, -1
.done:
    call rmgr_hook_leave
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret
.fail:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    mov eax, -1
    ret

; fs_sync() -> 0 ok, 1 deferred, -1 inactive
fs_sync:
    cmp dword [dgfs_active], 0
    je .inactive
    cmp dword [dgfs_defer], 0
    je .flush
    mov eax, [pmm_free_kb]
    cmp eax, [rmgr_free_min_kb_eff]
    jb .defer
    mov dword [dgfs_defer], 0
.flush:
    cmp dword [dgfs_dirty], 0
    je .ok
    mov ebx, [mb2_dgfs_start]
    mov eax, [ebx + DGFS_HDR_FLAGS]
    or eax, 1
    mov [ebx + DGFS_HDR_FLAGS], eax
    mov dword [dgfs_dirty], 0
.ok:
    xor eax, eax
    ret
.defer:
    mov eax, 1
    ret
.inactive:
    mov eax, -1
    ret

fs_load_profile:
    cmp dword [dgfs_active], 0
    je .no
    push esi
    mov esi, prof_name
    call dgfs_find
    cmp eax, -1
    je .no_pop
    push eax
    call dgfs_entry_ptr
    mov eax, [esi + 32]
    add eax, [mb2_dgfs_start]
    mov edi, rmgr_profile_blob
    mov ecx, RMGR_PROFILE_BYTES
    push esi
    mov esi, eax
    rep movsb
    pop esi
    pop eax
    pop esi
    mov al, 1
    jmp .out
.no_pop:
    pop esi
.no:
    xor al, al
.out:
    ret

fs_save_profile:
    cmp dword [dgfs_active], 0
    je .no
    push esi
    mov esi, prof_name
    call dgfs_find
    cmp eax, -1
    je .no_pop
    push eax
    call dgfs_entry_ptr
    mov eax, [esi + 32]
    add eax, [mb2_dgfs_start]
    mov edi, eax
    mov esi, rmgr_profile_blob
    mov ecx, RMGR_PROFILE_BYTES
    rep movsb
    pop eax
    pop esi
    mov dword [dgfs_dirty], 1
    mov al, 1
    jmp .out
.no_pop:
    pop esi
.no:
    xor al, al
.out:
    ret

; fs_audit_tail_push(edi=24-byte RMGR audit entry)
fs_audit_tail_push:
    push ebx
    push ecx
    push edx
    push esi
    cmp dword [dgfs_active], 0
    je .out
    cmp dword [dgfs_audit_ent], -1
    je .out
    mov ebx, [dgfs_audit_idx]
    mov eax, [dgfs_audit_ent]
    push eax
    call dgfs_entry_ptr
    mov eax, [esi + 32]
    add eax, [mb2_dgfs_start]
    mov esi, edi
    mov edi, eax
    add edi, DGFS_AUDIT_TAIL_DATA
    add edi, ebx
    mov ecx, RMGR_AUDIT_ENTRY_BYTES
.cp:
    mov al, [esi]
    mov [edi], al
    inc esi
    inc edi
    inc ebx
    cmp ebx, DGFS_AUDIT_TAIL_ROOM
    jb .nw
    sub ebx, DGFS_AUDIT_TAIL_ROOM
.nw:
    dec ecx
    jnz .cp
    mov [dgfs_audit_idx], ebx
    pop eax
    push eax
    call dgfs_entry_ptr
    mov eax, [esi + 32]
    add eax, [mb2_dgfs_start]
    mov [eax + DGFS_AUDIT_TAIL_HEAD], ebx
    or dword [esi + 40], DGFS_FLAG_DIRTY
    pop eax
    mov dword [dgfs_dirty], 1
.out:
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; fs_audit_tail_snapshot(edi=buf) appends " tail=aN pP fF tT" from last record
fs_audit_tail_snapshot:
    push ebx
    push ecx
    push edx
    push esi
    cmp dword [dgfs_active], 0
    je .out
    mov ebx, [dgfs_audit_idx]
    test ebx, ebx
    jz .out
    mov eax, [dgfs_audit_ent]
    push eax
    call dgfs_entry_ptr
    mov eax, [esi + 32]
    add eax, [mb2_dgfs_start]
    mov esi, eax
    sub ebx, RMGR_AUDIT_ENTRY_BYTES
    jns .pos
    add ebx, DGFS_AUDIT_TAIL_ROOM
.pos:
    add esi, DGFS_AUDIT_TAIL_DATA
    add esi, ebx
    mov al, ' '
    stosb
    mov al, 't'
    stosb
    mov al, 'a'
    stosb
    mov al, 'i'
    stosb
    mov al, 'l'
    stosb
    mov al, '='
    stosb
    mov al, 'a'
    stosb
    mov eax, [esi + 0]
    call tail_dec
    mov al, ' '
    stosb
    mov al, 'p'
    stosb
    mov eax, [esi + 4]
    call tail_dec
    mov al, ' '
    stosb
    mov al, 'f'
    stosb
    mov eax, [esi + 12]
    call tail_dec_signed
    mov al, ' '
    stosb
    mov al, 't'
    stosb
    mov eax, [esi + 16]
    call tail_dec
    pop eax
.out:
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

tail_dec:
    push ebx
    push ecx
    push edx
    mov ebx, 10
    xor ecx, ecx
.d:
    xor edx, edx
    div ebx
    push edx
    inc ecx
    test eax, eax
    jnz .d
.e:
    pop eax
    add al, '0'
    stosb
    loop .e
    pop edx
    pop ecx
    pop ebx
    ret

tail_dec_signed:
    test eax, eax
    jns tail_dec
    push eax
    mov al, '-'
    stosb
    pop eax
    neg eax
    jmp tail_dec
