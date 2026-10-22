// =============================================================================
// riscv_test.h  -  Custom environment for the official riscv-tests  (row 19)
// -----------------------------------------------------------------------------
// WHAT riscv-tests IS
//   The official RISC-V test suite (github.com/riscv-software-src/riscv-tests).
//   Each test, e.g. isa/rv32ui/add.S, runs dozens of cases of one instruction,
//   written by the people who define the ISA.
//
// WHY WE NEED THIS FILE
//   Each test starts with RVTEST_CODE_BEGIN and finishes with RVTEST_PASS or
//   RVTEST_FAIL. The standard definitions of those macros set up CSRs and
//   finish with ecall, which our core does not have. This header redefines
//   them for our core, so the unmodified official tests can run on it.
//
// HOW RESULTS ARE REPORTED (same as our own programs)
//   pass -> store 1 to SIG_ADDR
//   fail -> store (TESTNUM << 1) | 1 to SIG_ADDR
//           TESTNUM is the number of the failing case inside the test file,
//           so  failing case = (signature - 1) / 2
//   The testbench watches SIG_ADDR and prints PASS or FAIL.
//
// The program (code + test data) is linked at address 0 (see link.ld) and
// loaded into BOTH memories, so the tests' data section is visible to loads.
// =============================================================================

#ifndef RISCV_TEST_H        // include guard: only process this file once
#define RISCV_TEST_H

#ifndef SIG_ADDR
#define SIG_ADDR 0xFFC      // signature address: last word of data memory
#endif

// The tests keep the current case number in TESTNUM; we use register gp (x3),
// the same register the standard environment uses.
#define TESTNUM gp

// RVTEST_RV64U / RV32U select the base ISA. Our core needs no setup, so the
// "init" macro they define is empty.
#define RVTEST_RV32U .macro init; .endm
#define RVTEST_RV64U RVTEST_RV32U

// Start of every test program. _start is the entry point at address 0.
#define RVTEST_CODE_BEGIN       \
        .section .text.init;    \
        .align 2;               \
        .globl _start;          \
_start:                         \
        li TESTNUM, 0;          \
        init;

// End of the code: just park the CPU in a loop.
#define RVTEST_CODE_END         \
1:      j 1b;

// All cases passed: store 1 to the signature address, then loop forever.
#define RVTEST_PASS             \
        li t0, SIG_ADDR;        \
        li t1, 1;               \
        sw t1, 0(t0);           \
1:      j 1b;

// A case failed: store (TESTNUM << 1) | 1, which is odd and never equal to
// the pass value 1 (cases start at 2), then loop forever.
#define RVTEST_FAIL             \
        slli t1, TESTNUM, 1;    \
        ori  t1, t1, 1;         \
        li   t0, SIG_ADDR;      \
        sw   t1, 0(t0);         \
1:      j 1b;

// Data section markers used by the tests that need memory (loads/stores).
#define EXTRA_DATA

#define RVTEST_DATA_BEGIN       \
        EXTRA_DATA              \
        .align 4;               \
        .globl begin_signature; \
begin_signature:

#define RVTEST_DATA_END         \
        .align 4;               \
        .globl end_signature;   \
end_signature:

#endif