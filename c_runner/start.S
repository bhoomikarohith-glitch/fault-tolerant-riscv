    .section .text.start, "ax", @progbits
    .globl _start
    .type _start, @function
    .option norvc
    .option norelax
_start:
    la sp, __stack_top__
    la gp, __global_pointer$

    /* Clear BSS before calling C. */
    la t0, __bss_start__
    la t1, __bss_end__
1:
    bgeu t0, t1, 2f
    sw zero, 0(t0)
    addi t0, t0, 4
    j 1b
2:
    call main

    /* Publish main's full 32-bit return value to the testbench. */
    li t0, 0xffc
    sw a0, 0(t0)
3:
    j 3b
    .size _start, . - _start
