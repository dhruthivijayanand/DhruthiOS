OUTPUT_FORMAT(elf64-x86-64)
ENTRY(kmain)

PHDRS
{
    requests PT_LOAD FLAGS(6);
    text PT_LOAD FLAGS(5);
    rodata PT_LOAD FLAGS(4);
    data PT_LOAD FLAGS(6);
}

SECTIONS
{
    /* Virtual address in the Limine kernel range, not a physical RAM address. */
    . = 0xffffffff80000000;
    .limine_requests : {
        KEEP(*(.limine_start))
        KEEP(*(.limine_requests))
        KEEP(*(.limine_end))
    } :requests
    . = ALIGN(0x1000);
    .text : { *(.text .text.*) } :text
    . = ALIGN(0x1000);
    .rodata : { *(.rodata .rodata.*) } :rodata
    . = ALIGN(0x1000);
    .data : { *(.data .data.*) } :data
    .bss : { *(.bss .bss.*) *(COMMON) } :data
    /DISCARD/ : { *(.eh_frame*) *(.note*) }
}
