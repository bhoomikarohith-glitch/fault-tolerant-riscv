/* ===========================================================================
 * link.ld  -  Linker script for riscv-tests on our core            (row 19)
 * ---------------------------------------------------------------------------
 * A linker script tells the linker WHERE in memory each part of the program
 * goes. Our memories both start at address 0, so:
 *   code (.text) starts at 0, where the PC starts after reset
 *   data (.data, .rodata ...) follows straight after the code
 * The whole image is then loaded into both memories by the testbench.
 * =========================================================================== */

OUTPUT_ARCH("riscv")
ENTRY(_start)                 /* first instruction = label _start */

SECTIONS
{
  . = 0x0;                    /* "." = current address; start at 0 */
  .text : { *(.text.init) *(.text) *(.text.*) }        /* code first */
  . = ALIGN(16);              /* round up to a 16-byte boundary */
  .data : { *(.data) *(.data.*) *(.sdata) *(.sdata.*) *(.rodata) *(.rodata.*) }
  .bss  : { *(.bss) *(.bss.*) *(.sbss) *(.sbss.*) }    /* zero-filled data */
  _end = .;                   /* label marking the end of the program */
}