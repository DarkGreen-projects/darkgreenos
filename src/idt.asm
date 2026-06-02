; DarkgreenOS - IDT, ISR stubs, PIC remap

%include "constants.inc"
%include "macros.inc"

extern irq_vector
extern pic_send_eoi
extern isr_handler
extern io_wait

section .bss
align 8
idt_start:
    resb 48 * 8
idt_end:

section .rodata
isr_handlers:
%assign i 0
%rep 48
    dd isr %+ i
%assign i i+1
%endrep

section .data
idt_descriptor:
    dw idt_end - idt_start - 1
    dd idt_start

section .text
global idt_load
global pic_remap

idt_load:
    push ebx
    push edi
    xor ecx, ecx
.fill:
    cmp ecx, 48
    jge .done_fill

    mov ebx, [isr_handlers + ecx * 4]
    mov edi, idt_start
    lea edi, [edi + ecx * 8]

    mov ax, bx
    mov [edi], ax
    mov word [edi + 2], GDT_CODE_SEG
    mov byte [edi + 4], 0
    mov byte [edi + 5], 10001110b
    shr ebx, 16
    mov [edi + 6], bx

    inc ecx
    jmp .fill

.done_fill:
    pop edi
    pop ebx
    lidt [idt_descriptor]
    ret

pic_remap:
    mov al, 0x11
    out PIC1_COMMAND, al
    call io_wait
    out PIC2_COMMAND, al
    call io_wait

    mov al, INT_IRQ0
    out PIC1_DATA, al
    call io_wait
    mov al, INT_IRQ0 + 8
    out PIC2_DATA, al
    call io_wait

    mov al, 0x04
    out PIC1_DATA, al
    call io_wait
    mov al, 0x02
    out PIC2_DATA, al
    call io_wait

    mov al, 0x01
    out PIC1_DATA, al
    call io_wait
    out PIC2_DATA, al
    call io_wait

    ; Unmask IRQ0 (PIT), IRQ1 (keyboard), IRQ2 (slave cascade); slave IRQ12 (mouse)
    mov al, 0xF8
    out PIC1_DATA, al
    mov al, 0xEF
    out PIC2_DATA, al
    ret

%macro ISR_STUB 1
global isr%1
isr%1:
    cli
    push dword 0
    push dword %1
    jmp isr_common
%endmacro

%macro ISR_STUB_ERR 1
global isr%1
isr%1:
    cli
    push dword %1
    jmp isr_common_err
%endmacro

%assign i 0
%rep 32
%if i == 8 || i == 10 || i == 11 || i == 12 || i == 13 || i == 14 || i == 17
    ISR_STUB_ERR i
%else
    ISR_STUB i
%endif
%assign i i+1
%endrep

%assign i 32
%rep 16
    ISR_STUB i
%assign i i+1
%endrep

%macro ISR_BODY 0
    pusha
    push ds
    push es
    push fs
    push gs
    mov ax, GDT_DATA_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    mov eax, [esp + 48]
    mov [irq_vector], eax
%endmacro

%macro ISR_FINISH 1
    pop gs
    pop fs
    pop es
    pop ds
    popa
    add esp, %1
    iret
%endmacro

isr_common:
    ISR_BODY
    push dword 0
    push eax
    call isr_handler
    add esp, 8
    ISR_FINISH 8

; Some #GPs (e.g. during iret) do not push a CPU error code — detect via CS slot.
isr_common_err:
    ISR_BODY
    mov ecx, [esp + 56]
    and ecx, 0xFFFC
    cmp ecx, GDT_CODE_SEG
    je .no_cpu_err
    mov ecx, [esp + 60]
    and ecx, 0xFFFC
    cmp ecx, GDT_CODE_SEG
    jne .no_cpu_err

    mov ebx, [esp + 52]
    mov ecx, [esp + 56]
    mov edx, [esp + 60]
    push edx
    push ecx
    push ebx
    push eax
    call isr_handler
    add esp, 16
    ISR_FINISH 8
    jmp .out

.no_cpu_err:
    xor ebx, ebx
    mov ecx, [esp + 52]
    mov edx, [esp + 56]
    push edx
    push ecx
    push ebx
    push eax
    call isr_handler
    add esp, 16
    ISR_FINISH 4
.out:
