# rv32i_smoke.S
# Self-checking test of every RV32I instruction the single-cycle core
# supports. Each group sets a test number in t6 and compares results with
# CHECK. On the first mismatch the program stores the test number to the
# signature address; if everything passes it stores 1.
#
#   signature address : 0x0FFC
#   pass value        : 1
#   fail value        : number of the failing test (2 to 11)
#
# Assembly basics used below:
#   .equ NAME, value     defines a named constant (like #define)
#   .macro / .endm       defines a reusable snippet; \reg inserts an argument
#   li rd, value         "load immediate": pseudo-instruction, becomes
#                        lui + addi for big values
#   1: / 1f / 1b         numbered local labels; 1f = next "1:" forward,
#                        1b = previous "1:" backward
#   t0-t6, a0            register nicknames for x5-x7/x28-x31 and x10

        .equ SIG_ADDR, 0x0FFC
        .equ DATA_BUF, 0x0800

# Compare a register with a constant; jump to fail on mismatch (uses t5).
        .macro CHECK reg, expected
        li    t5, \expected
        bne   \reg, t5, fail
        .endm

        .macro TEST n
        li    t6, \n
        .endm

        .text
        .globl _start
_start:

# ---------------------------------------------------------------- 2: add/sub
        TEST 2
        li    t0, 5
        li    t1, 12
        add   t2, t0, t1
        CHECK t2, 17
        sub   t2, t0, t1
        CHECK t2, -7
        addi  t2, t1, -9            # bit 30 set: must still decode as ADD
        CHECK t2, 3
        li    t0, 0x7FFFFFFF
        addi  t2, t0, 1             # wraps, no overflow trap
        CHECK t2, 0x80000000

# ---------------------------------------------------------------- 3: logic
        TEST 3
        li    t0, 0xF0F0F0F0
        li    t1, 0x0FF00FF0
        and   t2, t0, t1
        CHECK t2, 0x00F000F0
        or    t2, t0, t1
        CHECK t2, 0xFFF0FFF0
        xor   t2, t0, t1
        CHECK t2, 0xFF00FF00
        andi  t2, t0, 0x7FF
        CHECK t2, 0x000000F0
        ori   t2, t1, -1
        CHECK t2, 0xFFFFFFFF
        xori  t2, t0, -1
        CHECK t2, 0x0F0F0F0F

# ---------------------------------------------------------------- 4: shifts
        TEST 4
        li    t0, 0x80000001
        slli  t2, t0, 4
        CHECK t2, 0x00000010
        srli  t2, t0, 4
        CHECK t2, 0x08000000
        srai  t2, t0, 4
        CHECK t2, 0xF8000000
        li    t1, 36                # only the low 5 bits (4) are used
        sll   t2, t0, t1
        CHECK t2, 0x00000010
        srl   t2, t0, t1
        CHECK t2, 0x08000000
        sra   t2, t0, t1
        CHECK t2, 0xF8000000

# ---------------------------------------------------------------- 5: compares
        TEST 5
        li    t0, -1
        li    t1, 1
        slt   t2, t0, t1            # -1 < 1 signed
        CHECK t2, 1
        sltu  t2, t0, t1            # 0xFFFFFFFF < 1 unsigned is false
        CHECK t2, 0
        slti  t2, t0, 0
        CHECK t2, 1
        sltiu t2, t1, -1            # 1 < 0xFFFFFFFF
        CHECK t2, 1
        sltiu t2, t0, 1
        CHECK t2, 0

# ---------------------------------------------------------------- 6: lui/auipc
        TEST 6
        lui   t2, 0x12345
        CHECK t2, 0x12345000
        auipc t0, 0                 # t0 = address of this instruction
        auipc t1, 1                 # t1 = t0 + 4 + 0x1000
        sub   t2, t1, t0
        CHECK t2, 0x1004

# ---------------------------------------------------------------- 7: loads/stores
        TEST 7
        li    a0, DATA_BUF
        li    t0, 0x80F07F01
        sw    t0, 0(a0)
        lw    t2, 0(a0)
        CHECK t2, 0x80F07F01
        lb    t2, 0(a0)
        CHECK t2, 0x00000001
        lb    t2, 1(a0)
        CHECK t2, 0x0000007F
        lb    t2, 2(a0)             # 0xF0 sign-extends
        CHECK t2, 0xFFFFFFF0
        lbu   t2, 2(a0)
        CHECK t2, 0x000000F0
        lh    t2, 0(a0)
        CHECK t2, 0x00007F01
        lh    t2, 2(a0)             # 0x80F0 sign-extends
        CHECK t2, 0xFFFF80F0
        lhu   t2, 2(a0)
        CHECK t2, 0x000080F0
        li    t1, 0xAA
        sb    t1, 1(a0)             # only byte 1 changes
        lw    t2, 0(a0)
        CHECK t2, 0x80F0AA01
        li    t1, 0x1234
        sh    t1, 2(a0)             # only the upper half changes
        lw    t2, 0(a0)
        CHECK t2, 0x1234AA01
        sw    t1, 4(a0)             # neighbouring word is independent
        lw    t2, 0(a0)
        CHECK t2, 0x1234AA01

# ---------------------------------------------------------------- 8: branches not taken
        TEST 8
        li    t0, -1
        li    t1, 1
        beq   t0, t1, fail
        bne   t0, t0, fail
        blt   t1, t0, fail          # 1 < -1 is false
        bge   t0, t1, fail          # -1 >= 1 is false
        bltu  t0, t1, fail          # 0xFFFFFFFF < 1 is false
        bgeu  t1, t0, fail          # 1 >= 0xFFFFFFFF is false

# ---------------------------------------------------------------- 9: branches taken
        TEST 9
        beq   t0, t0, 1f
        j     fail
1:      bne   t0, t1, 1f
        j     fail
1:      blt   t0, t1, 1f
        j     fail
1:      bge   t1, t0, 1f
        j     fail
1:      bge   t1, t1, 1f            # equal operands
        j     fail
1:      bltu  t1, t0, 1f
        j     fail
1:      bgeu  t0, t1, 1f
        j     fail
1:      li    t2, 3                 # backward branch: count down to 0
2:      addi  t2, t2, -1
        bnez  t2, 2b
        CHECK t2, 0

# ---------------------------------------------------------------- 10: jal/jalr
        TEST 10
        auipc t0, 0                 # t0 = A
        jal   t1, 1f                # at A+4, link = A+8
        j     fail                  # A+8, skipped
1:      addi  t2, t0, 8
        bne   t1, t2, fail

        auipc t0, 0                 # t0 = B
        addi  t0, t0, 17            # B+17 (odd)
        jalr  t1, t0, 0             # at B+8: jump to (B+17) & ~1 = B+16
        j     fail                  # B+12, skipped
        addi  t2, t0, -5            # B+16: expected link = B+12
        bne   t1, t2, fail

# ---------------------------------------------------------------- 11: x0
        TEST 11
        addi  x0, x0, 5             # writes to x0 are discarded
        CHECK x0, 0

# ---------------------------------------------------------------- result
pass:
        li    t0, SIG_ADDR
        li    t1, 1
        sw    t1, 0(t0)
1:      j     1b

fail:
        li    t0, SIG_ADDR
        sw    t6, 0(t0)
1:      j     1b