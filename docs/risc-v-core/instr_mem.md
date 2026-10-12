# Instruction Memory Specification

**Project:** Fault-Tolerant RV32I RISC-V Processor  
**Module:** Instruction Memory  
**RTL File:** `rtl/memory/instr_mem.sv`  
**Specification File:** `docs/specs/instr_mem.md`  
**Status:** Design Specification

## 1. Purpose

The Instruction Memory stores the program executed by the processor. Given the byte address in the PC, it returns the 32-bit instruction stored at that address.

Its contents are loaded from a hexadecimal file at the start of simulation, and into the FPGA's memory when the bitstream is loaded.

The memory is read-only during execution. In the single-cycle processor, the read is combinational.

## 2. Functional Requirements

The module shall:

1. Store `DEPTH` words, each `WIDTH` bits wide.
2. Initialize its contents from the file named by `INIT_FILE`.
3. Return the word selected by the address input, combinationally.
4. Ignore address bits `[1:0]` (word-aligned access).
5. Return zero for addresses beyond the end of the memory.
6. Return zero for words not given a value by the initialization file.

The module shall not provide a write port, a clock input or a reset input.

## 3. Interface Specification

| Signal | Direction | Width | Description |
|---|---|---|---|
| `a` | Input | 32 bits | Byte address of the instruction (the PC) |
| `rd` | Output | `WIDTH` bits | Instruction word read from memory |

### Parameters

| Parameter | Default | Description |
|---|---|---|
| `DEPTH` | `1024` | Number of words (1024 words = 4 KB) |
| `WIDTH` | `32` | Bits per word |
| `INIT_FILE` | `"program.mem"` | Hex file loaded into the memory |

**Design decision:** The reference instruction memory holds 64 words. This implementation holds 1024 words, so that `riscv-tests` programs and C benchmarks fit.

## 4. Addressing

The memory is word-addressed internally. The word index is taken from address bits `[31:2]`.

| Address `a` | Word index | Result |
|---|---|---|
| `0x0000_0000` | 0 | Word 0 |
| `0x0000_0004` | 1 | Word 1 |
| `0x0000_0008` | 2 | Word 2 |
| `0x0000_0006` | 1 | Word 1 (bits `[1:0]` ignored) |
| `0x0000_0FFC` | 1023 | Last word |
| `0x0000_1000` | 1024 | Out of range: zero |

### Out-of-Range Behavior

An address whose word index is `DEPTH` or greater shall return zero. The memory shall not wrap around to the start.

**Design decision:** An all-zero word is defined as an illegal instruction in RISC-V. A runaway PC is therefore easy to spot in simulation, instead of silently re-executing the program from the start.

## 5. Read Timing

The read shall be combinational (asynchronous): `rd` updates whenever `a` changes, with no clock edge required.

This lets the single-cycle processor fetch and execute an instruction in the same cycle. On the FPGA, Vivado implements a combinational-read memory in LUTs (distributed memory).

The pipelined processor may later switch to a clocked read, so that the memory maps onto FPGA block RAM. That change will be recorded in a revision of this specification.

## 6. Initialization File Format

- Plain text, one 32-bit word per line.
- Eight hexadecimal digits per line, with no `0x` prefix.
- The first line is word 0 (address `0x0000_0000`).
- Words beyond the end of the file are zero.

The file is produced from an assembled program with `riscv64-unknown-elf-objcopy` using Verilog output with a data width of 4 bytes.

If the generated file contains `@` address lines, they must be checked to be word addresses. The simplest flow is a file with no `@` lines that starts at word 0.

The initialization block is the only `initial` block permitted in the RTL, under the project coding rules.

## 7. Fault-Tolerance Requirements

`WIDTH` shall be a parameter and shall not be hard-coded anywhere in the module.

When ECC is added, `WIDTH` becomes 39 (32 data bits plus 7 check bits), and the ECC decoder sits between `rd` and the datapath. This module shall need no other change.

## 8. Integration Requirements

Input:

- `a` from the PC register output.

Output:

- `rd` (the instruction) to the immediate generator, register file address fields, main decoder and ALU decoder.

## 9. Verification Requirements

The unit testbench shall verify the following.

### Basic Reads

- Using a hand-written file of distinctive words (for example `DEADBEEF`, `CAFEF00D`), the words at addresses `0x0`, `0x4`, `0x8` and the last valid address are read correctly.
- The output updates without a clock edge when the address changes.

### Alignment

- Addresses with nonzero bits `[1:0]` return the same word as the aligned address.

### Boundaries

- Addresses at and beyond `DEPTH × 4` return zero.
- Words not present in the initialization file return zero.

### Toolchain Flow

- A short assembly program is assembled, converted to a `.mem` file, and loaded; every word read matches the `objdump -d` disassembly.
- The textbook's reference test program loads and reads back correctly.

### Parameters

- An `INIT_FILE` parameter override loads the named file.

## 10. Completion Criteria

The module is considered complete when:

- [ ] The memory initializes from `INIT_FILE`.
- [ ] Reads are combinational and word-aligned.
- [ ] Out-of-range addresses return zero.
- [ ] `DEPTH`, `WIDTH` and `INIT_FILE` are parameters.
- [ ] A toolchain-generated program loads and reads back correctly.
- [ ] The implementation passes its unit testbench.
- [ ] The module integrates correctly with the PC register and the decode path.

## 11. File Locations

RTL:

`rtl/memory/instr_mem.sv`

Unit testbench:

`tb/unit/instr_mem_tb.sv`

Specification:

`docs/specs/instr_mem.md`