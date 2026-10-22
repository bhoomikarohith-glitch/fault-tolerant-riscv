# Main Decoder Specification

**Project:** Fault-Tolerant RV32I RISC-V Processor  
**Module:** Main Decoder  
**RTL File:** `rtl/core/main_decoder.sv`  
**Specification File:** `docs/specs/main_decoder.md`  
**Status:** Design Specification

## 1. Purpose

The Main Decoder is the first half of the processor's control unit. It reads the 7-bit opcode of the current instruction and generates the control signals that steer the datapath: which immediate to build, which ALU operand to use, whether to write a register or memory, what value to write back, and whether the instruction changes the flow of control.

The exact ALU operation is chosen by the ALU Decoder from the `aluop` signal produced here.

The module is purely combinational.

## 2. Functional Requirements

The module shall:

1. Accept the 7-bit opcode, `instr[6:0]`.
2. Generate every control signal listed in Section 3 for all nine RV32I opcode classes.
3. Assign every output on every path, so no latch is inferred.
4. Treat any other opcode (FENCE, ECALL, EBREAK, CSR, illegal) as a no-op: no register write, no memory write, and the PC advances by 4.

The module shall not decode `funct3` or `funct7`. Those fields are used by the ALU Decoder, the Branch Comparator and the Data Memory.

## 3. Interface Specification

| Signal | Direction | Width | Description |
|---|---|---|---|
| `op` | Input | 7 bits | Opcode, `instr[6:0]` |
| `regwrite` | Output | 1 bit | 1 = write the result to register `rd` |
| `immsrc` | Output | 3 bits | Immediate format for the Immediate Generator |
| `alusrc` | Output | 1 bit | ALU operand B: 0 = `rs2`, 1 = immediate |
| `memwrite` | Output | 1 bit | 1 = store to data memory |
| `resultsrc` | Output | 3 bits | Value written to `rd` (see Section 5) |
| `branch` | Output | 1 bit | Instruction is a conditional branch |
| `jump` | Output | 1 bit | Instruction is JAL |
| `jalr` | Output | 1 bit | Instruction is JALR |
| `aluop` | Output | 2 bits | Operation class for the ALU Decoder |

All encodings are defined once in `rtl/common/rv_pkg.sv`.

## 4. Control Signal Table

| Class | Opcode | `regwrite` | `immsrc` | `alusrc` | `memwrite` | `resultsrc` | `branch` | `jump` | `jalr` | `aluop` |
|---|---|---|---|---|---|---|---|---|---|---|
| Load | `0000011` | 1 | I | 1 | 0 | MEM | 0 | 0 | 0 | `00` |
| Store | `0100011` | 0 | S | 1 | 1 | ALU | 0 | 0 | 0 | `00` |
| R-type | `0110011` | 1 | I | 0 | 0 | ALU | 0 | 0 | 0 | `10` |
| I-type ALU | `0010011` | 1 | I | 1 | 0 | ALU | 0 | 0 | 0 | `10` |
| Branch | `1100011` | 0 | B | 0 | 0 | ALU | 1 | 0 | 0 | `01` |
| JAL | `1101111` | 1 | J | 0 | 0 | PC4 | 0 | 1 | 0 | `00` |
| JALR | `1100111` | 1 | I | 1 | 0 | PC4 | 0 | 0 | 1 | `00` |
| LUI | `0110111` | 1 | U | 0 | 0 | IMM | 0 | 0 | 0 | `00` |
| AUIPC | `0010111` | 1 | U | 0 | 0 | PCTGT | 0 | 0 | 0 | `00` |
| Other | any | 0 | I | 0 | 0 | ALU | 0 | 0 | 0 | `00` |

Values shown for signals an instruction does not use are the module's defaults; they have no effect.

## 5. Result Source Encoding

| `resultsrc` | Name | Value written to `rd` | Used by |
|---|---|---|---|
| `3'b000` | ALU | ALU result | R-type, I-type ALU |
| `3'b001` | MEM | Data memory read data | Loads |
| `3'b010` | PC4 | PC + 4 | JAL, JALR |
| `3'b011` | IMM | U-type immediate | LUI |
| `3'b100` | PCTGT | PC + immediate | AUIPC |

**Design decision:** The reference design uses a 2-bit result select with three sources. This implementation adds the immediate (for LUI) and PC + immediate (for AUIPC), so the full RV32I set is supported without routing those values through the ALU.

## 6. Coding Style

The decoder first assigns every output a safe default (a no-op), then a `case` on the opcode overrides only the signals each instruction needs. This guarantees that every output is assigned on every path, and makes each opcode's entry short and readable.

**Design decision:** The reference design computes the PC source in the controller as Branch AND Zero OR Jump. This implementation outputs separate `branch`, `jump` and `jalr` signals, and the Next-PC Logic makes the PC-source decision.

## 7. Integration Requirements

Input:

- `op` from the fetched instruction.

Outputs:

- `immsrc` to the Immediate Generator.
- `regwrite` to the Register File write enable.
- `alusrc` to the ALU operand B multiplexer.
- `memwrite` to the Data Memory write enable.
- `resultsrc` to the result multiplexer.
- `branch`, `jump` and `jalr` to the Next-PC Logic.
- `aluop` to the ALU Decoder.

## 8. Verification Requirements

The module is verified through the system tests, which execute every opcode class:

- `software/tests/rv32i_smoke.S` (one test group per instruction class).
- The official `riscv-tests` suite for RV32I (40 tests).
- An unknown opcode leaves registers and memory unchanged.

A unit testbench, if added, shall check the full table in Section 4 for each opcode and confirm the defaults for an unknown opcode.

## 9. Completion Criteria

The module is considered complete when:

- [ ] All nine opcode classes produce the signals in Section 4.
- [ ] Unknown opcodes behave as a no-op.
- [ ] No latches are inferred.
- [ ] All system tests pass (`make test`).

## 10. File Locations

RTL:

`rtl/core/main_decoder.sv`

Specification:

`docs/specs/main_decoder.md`
