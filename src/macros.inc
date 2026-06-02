; DarkgreenOS - useful macros

%ifndef DARKGREEN_MACROS_INC
%define DARKGREEN_MACROS_INC

%macro outb 2
    mov al, %2
    out %1, al
%endmacro

%macro inb 2
    in al, %1
    mov %2, al
%endmacro

%endif
