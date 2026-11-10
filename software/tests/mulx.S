# mulx.S - tests the custom MULX instruction
# MULX rd, rs1, rs2  (custom-0 opcode 0001011, R-type layout)
#   rd = low 32 bits of rs1 * rs2   (computed by the Booth multiplier)
# expected: 1 at 0xFFC.  On failure: 0x100 + case number at 0xFFC.

        # the assembler has no 'mulx', so emit the raw R-type encoding
        .macro mulx rd, rs1, rs2
        .insn r 0x0B, 0, 0, \rd, \rs1, \rs2
        .endm

        # T n, a, b, p : check that a * b gives p (low 32 bits)
        .macro T n, a, b, p
        li    a1, \n
        li    t0, \a
        li    t1, \b
        li    t2, \p
        mulx  t3, t0, t1
        bne   t3, t2, fail
        .endm

        .text
        .globl _start
_start:
        T  1,          6,          7,         42
        T  2,         -6,          7,        -42   # negative x positive
        T  3,         -6,         -7,         42   # negative x negative
        T  4,          0,      12345,          0
        T  5,          1,         -1,         -1
        T  6, 0x7fffffff,          2, 0xfffffffe   # overflow wraps
        T  7, 0x80000000,         -1, 0x80000000   # most-negative x -1
        T  8, 0x80000000, 0x80000000,          0
        T  9, 0x12345678, 0x09abcdef, 0xe242d208
        T 10,      65535,      65537,         -1   # (2^16-1)(2^16+1) = 2^32-1
        T 11, 0x7fffffff, 0x7fffffff,          1
        T 12, 0xdeadbeef, 0xcafebabe, 0x88cf5b62

        li    a1, 13                 # writes to x0 are ignored
        mulx  zero, t0, t1
        bne   zero, x0, fail

        li    a1, 14                 # rd = rs1 = rs2 (square in place)
        li    t4, -9
        mulx  t4, t4, t4
        li    t2, 81
        bne   t4, t2, fail

pass:   li    a0, 1
        j     done
fail:   addi  a0, a1, 0x100
done:   li    t0, 0xFFC
        sw    a0, 0(t0)
1:      j     1b
