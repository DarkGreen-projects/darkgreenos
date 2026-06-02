; DarkgreenOS - safe pointer checks (identity map only)

%include "constants.inc"

section .text
global ptr_in_identity_map

; ptr_in_identity_map(eax=addr) -> al=1 if VA is covered by identity map
ptr_in_identity_map:
    test eax, eax
    jz .no
    mov al, 1
    ret
.no:
    xor al, al
    ret
