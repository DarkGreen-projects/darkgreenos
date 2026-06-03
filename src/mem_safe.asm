; DarkgreenOS - safe pointer checks (user + kernel)

%include "constants.inc"

section .text
global ptr_in_identity_map
global ptr_in_user_region
global copy_from_user
global copy_to_user

ptr_in_identity_map:
    test eax, eax
    jz .no
    mov al, 1
    ret
.no:
    xor al, al
    ret

; ptr_in_user_region(eax=addr, ecx=len) -> al=1 if [addr,addr+len) in user VA
ptr_in_user_region:
    push ebx
    push edx
    test ecx, ecx
    jz .yes
    mov ebx, eax
    add ebx, ecx
    jb .no
    cmp eax, USER_VA_BASE
    jb .no
    mov edx, USER_VA_BASE + USER_VA_SIZE
    cmp ebx, edx
    ja .no
.yes:
    mov al, 1
    jmp .out
.no:
    xor al, al
.out:
    pop edx
    pop ebx
    ret

; copy_from_user(edi=dst, esi=src, ecx=len) -> eax=bytes copied or -1
copy_from_user:
    push ebx
    mov eax, esi
    call ptr_in_user_region
    test al, al
    jz .bad
    mov eax, ecx
    rep movsb
    jmp .out
.bad:
    mov eax, -1
.out:
    pop ebx
    ret

; copy_to_user(edi=dst, esi=src, ecx=len) -> eax=bytes copied or -1
copy_to_user:
    push ebx
    push edi
    mov eax, edi
    call ptr_in_user_region
    test al, al
    jz .bad
    pop edi
    mov eax, ecx
    rep movsb
    jmp .out
.bad:
    pop edi
    mov eax, -1
.out:
    pop ebx
    ret
