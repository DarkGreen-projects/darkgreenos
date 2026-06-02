ENTRY(_start)



SECTIONS

{

    . = 1M;



    kernel_start = .;



    /* Multiboot header first in loadable image (GRUB scans ELF PT_LOAD) */

    .text : {

        KEEP(*(.multiboot))

        *(.text*)

    }



    text_start = .;



    .rodata : {

        *(.rodata*)

    }

    rodata_start = .;



    .data : {

        *(.data*)

    }

    data_start = .;



    .bss : {

        *(COMMON)

        *(.bss*)

    }

    bss_start = .;



    . = ALIGN(4096);

    . += 4096;

    stack_bottom = .;

    . += 64K;

    stack_top = .;



    kernel_end = .;

}

