# array_sum.S
# Stores ten numbers in memory, adds them up with a loop, and writes the
# total to the result address. Runs unchanged in Ripes.
#
#   expected result: 64 (0x40), in a0 and at address 0xFFC

        .text
        .globl _start
_start:
        li    s0, 0x800           # array base address

        # --- build the array: 5, -3, 12, 7, 0, 25, -8, 14, 3, 9
        li    t0, 5
        sw    t0, 0(s0)
        li    t0, -3
        sw    t0, 4(s0)
        li    t0, 12
        sw    t0, 8(s0)
        li    t0, 7
        sw    t0, 12(s0)
        sw    zero, 16(s0)
        li    t0, 25
        sw    t0, 20(s0)
        li    t0, -8
        sw    t0, 24(s0)
        li    t0, 14
        sw    t0, 28(s0)
        li    t0, 3
        sw    t0, 32(s0)
        li    t0, 9
        sw    t0, 36(s0)

        # --- sum it
        li    a0, 0               # running total
        li    t1, 10              # elements left
        mv    t2, s0              # pointer
loop:
        lw    t3, 0(t2)
        add   a0, a0, t3
        addi  t2, t2, 4
        addi  t1, t1, -1
        bnez  t1, loop

        # --- report
        li    t0, 0xFFC
        sw    a0, 0(t0)
done:   j     done