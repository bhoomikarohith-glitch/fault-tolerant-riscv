OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY {
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 0x800
    DATA (rw) : ORIGIN = 0x00000800, LENGTH = 0x400
}
PHDRS {
    code PT_LOAD FLAGS(5);
    data PT_LOAD FLAGS(6);
}
SECTIONS {
    .text : {
        KEEP(*(.text.start))
        *(.text .text.*)
        . = ALIGN(4);
    } > ROM :code

    .data : {
        *(.rodata .rodata.* .srodata .srodata.*)
        *(.data .data.* .sdata .sdata.*)
        . = ALIGN(4);
    } > DATA :data

    .bss (NOLOAD) : {
        __bss_start__ = .;
        *(.bss .bss.* .sbss .sbss.*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end__ = .;
    } > DATA :data

    __global_pointer$ = 0x800;
    __stack_bottom__ = 0xc00;
    __stack_top__ = 0xff0;
    __result_address__ = 0xffc;
    /DISCARD/ : { *(.comment .eh_frame .eh_frame.* .note .note.*) }
}
ASSERT(SIZEOF(.text) <= 0x800, "Program exceeds 2 KB code allocation")
ASSERT(__bss_end__ <= 0xc00, "Static data exceeds 1 KB allocation")
