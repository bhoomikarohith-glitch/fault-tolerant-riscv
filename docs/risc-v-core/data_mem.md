# Data Memory Specification

**Project:** Fault-Tolerant RV32I RISC-V Processor  
**Module:** Data Memory  
**RTL File:** `rtl/memory/data_mem.sv`  
**Specification File:** `docs/specs/data_mem.md`  
**Status:** Design Specification

## 1. Purpose

The Data Memory holds the program's data. It serves every RV32I load (LB, LH, LW, LBU, LHU) and store (SB, SH, SW), including byte and halfword accesses with sign or zero extension.

Reads are combinational; writes take effect on the rising clock edge.

## 2. Functional Requirements

The module shall:

1. Store `DEPTH` 32-bit words, optionally initialized from `INIT_FILE`.
2. Return load data combinationally, selected and extended according to `funct3`.
3. Write stores on the rising clock edge when `we` is 1, changing only the bytes the store covers.
4. Use little-endian byte order.
5. Return zero for out-of-range reads and ignore out-of-range writes.

## 3. Interface Specification

| Signal | Direction | Width | Description |
|---|---|---|---|
| `clk` | Input | 1 bit | Clock; stores happen on the rising edge |
| `we` | Input | 1 bit | Write enable (`memwrite`) |
| `funct3` | Input | 3 bits | Access size and sign, `instr[14:12]` |
| `a` | Input | 32 bits | Byte address (the ALU result) |
| `wd` | Input | 32 bits | Store data (`rs2`) |
| `rd` | Output | 32 bits | Load data, already extended to 32 bits |

### Parameters

| Parameter | Default | Description |
|---|---|---|
| `DEPTH` | `1024` | Number of 32-bit words (4 KB) |
| `INIT_FILE` | `""` | Optional hex file with initial contents |

## 4. Loads

The memory reads the whole word at `a[31:2]`, then selects and extends the requested part:

| `funct3` | Instruction | Bytes taken | Extension |
|---|---|---|---|
| `000` | LB | byte `a[1:0]` | sign |
| `001` | LH | halfword `a[1]` | sign |
| `010` | LW | whole word | none |
| `100` | LBU | byte `a[1:0]` | zero |
| `101` | LHU | halfword `a[1]` | zero |

Example: the word at `0x800` is `0x80F07F01`. LB from `0x802` returns `0xFFFFFFF0`; LBU from `0x802` returns `0x000000F0`.

## 5. Stores

Stores use a 4-bit byte-enable mask so that only the addressed bytes change:

| `funct3[1:0]` | Instruction | Byte enables | Store data lanes |
|---|---|---|---|
| `00` | SB | `0001 << a[1:0]` | `wd[7:0]` copied to all four bytes |
| `01` | SH | `0011` or `1100` (by `a[1]`) | `wd[15:0]` copied to both halves |
| `10` | SW | `1111` | `wd` |

Copying the store data into every lane means whichever byte is enabled already holds the correct value. This is the same structure used by FPGA and ASIC memories with byte-write enables.

## 6. Addressing and Limits

- Little-endian: byte 0 of a word is its least significant byte.
- Misaligned accesses (for example LW from address 2) are not supported. A halfword selects its lane with `a[1]`; a word ignores `a[1:0]`.
- Addresses at or beyond `DEPTH × 4` read as zero and ignore writes.

**Design decision:** The reference data memory supports only word accesses with 64 words. This implementation adds byte and halfword accesses (required by RV32I) and holds 1024 words.

## 7. Fault-Tolerance Requirements

When ECC is added, each stored word will carry 7 check bits. A byte or halfword store must then become a read-modify-write of the whole word, so the check bits can be recomputed. This will be handled in the ECC integration stage.

## 8. Integration Requirements

Inputs:

- `a` from the ALU result.
- `wd` from register file read port 2.
- `we` from the main decoder (`memwrite`).
- `funct3` from the instruction.

Output:

- `rd` to the result multiplexer.

## 9. Verification Requirements

- Test group 7 of `software/tests/rv32i_smoke.S`: every load type, sign and zero extension, byte and halfword stores, and independence of neighbouring words.
- `riscv-tests`: `lb`, `lbu`, `lh`, `lhu`, `lw`, `sb`, `sh`, `sw`, `ld_st` and `st_ld`.

## 10. Completion Criteria

The module is considered complete when:

- [ ] All five load types return correctly extended data.
- [ ] All three store types change only the addressed bytes.
- [ ] Out-of-range accesses behave as specified.
- [ ] All load and store tests pass (`make test`).

## 11. File Locations

RTL:

`rtl/memory/data_mem.sv`

Specification:

`docs/specs/data_mem.md`
