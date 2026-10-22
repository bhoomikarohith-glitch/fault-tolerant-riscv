# ALU Decoder Specification

**Project:** Fault-Tolerant RV32I RISC-V Processor  
**Module:** ALU Decoder  
**RTL File:** `rtl/core/alu_decoder.sv`  
**Specification File:** `docs/specs/alu_decoder.md`  
**Status:** Design Specification

## 1. Purpose

The ALU Decoder generates the ALU operation select (`alucontrol`). It combines the coarse `aluop` signal from the main decoder with the instruction's `funct3` field and bits 5 and 30.

It is the second half of the processor's control unit. The main decoder decides the class of operation; the ALU Decoder decides the exact ALU operation.

The module is purely combinational.

## 2. Functional Requirements

The module shall:

1. Accept the 2-bit `aluop` signal from the main decoder.
2. Accept the instruction fields `funct3`, `opb5` (instruction bit 5) and `funct7b5` (instruction bit 30).
3. Produce the 4-bit `alucontrol` code defined in the ALU specification.
4. Distinguish ADD from SUB, and SRL from SRA.
5. Produce a deterministic output for every input combination.

The module shall not detect illegal instructions. That responsibility belongs to the main decoder.

## 3. Interface Specification

| Signal | Direction | Width | Description |
|---|---|---|---|
| `opb5` | Input | 1 bit | Instruction bit 5: 1 for R-type, 0 for I-type ALU instructions |
| `funct3` | Input | 3 bits | Instruction bits `[14:12]` |
| `funct7b5` | Input | 1 bit | Instruction bit 30 |
| `aluop` | Input | 2 bits | Operation class from the main decoder |
| `alucontrol` | Output | 4 bits | ALU operation select |

### Interface Notes

- Port names follow the reference controller, so the module drops into a textbook-style controller.
- `alucontrol` encodings are defined in `docs/specs/alu.md`, Section 4.

**Design decision:** The reference ALU decoder produces a 3-bit output and supports only ADD, SUB, AND, OR and SLT. This implementation produces a 4-bit output and supports all ten RV32I ALU operations.

## 4. ALUOp Encoding

`aluop` is shared with the main decoder and shall use the following encoding:

| `aluop` | Meaning | Typical instructions | `alucontrol` |
|---|---|---|---|
| `2'b00` | Add | Loads, stores, JALR | ADD (`4'b0000`) |
| `2'b01` | Subtract | Branches (reference design) | SUB (`4'b1000`) |
| `2'b10` | Decode from instruction fields | R-type, I-type ALU | See Section 5 |
| `2'b11` | Invalid | None | ADD (`4'b0000`) |

**Note:** Branches in this processor are resolved by the branch comparator, so the ALU result is unused for branches. The `2'b01` encoding is kept so that a reference-style main decoder works unchanged.

## 5. Field Decoding (`aluop` = `2'b10`)

| `funct3` | Condition | `alucontrol` | Instructions |
|---|---|---|---|
| `000` | `opb5` = 1 and `funct7b5` = 1 | SUB (`1000`) | SUB |
| `000` | Otherwise | ADD (`0000`) | ADD, ADDI |
| `001` | — | SLL (`0001`) | SLL, SLLI |
| `010` | — | SLT (`0010`) | SLT, SLTI |
| `011` | — | SLTU (`0011`) | SLTU, SLTIU |
| `100` | — | XOR (`0100`) | XOR, XORI |
| `101` | `funct7b5` = 1 | SRA (`1101`) | SRA, SRAI |
| `101` | `funct7b5` = 0 | SRL (`0101`) | SRL, SRLI |
| `110` | — | OR (`0110`) | OR, ORI |
| `111` | — | AND (`0111`) | AND, ANDI |

### Why SUB Checks `opb5` but SRA Does Not

- For `funct3` = `000`, instruction bit 30 is part of the immediate in ADDI. An ADDI with a negative immediate (for example `addi x7, x3, -9`) has bit 30 set. Checking `funct7b5` alone would wrongly decode it as SUB, so SUB also requires `opb5` = 1 (R-type).
- For `funct3` = `101`, bit 30 selects arithmetic shift in both SRA and SRAI. It must be honored for both R-type and I-type instructions, so no `opb5` check is applied.

### Equivalent Formulation

For `aluop` = `2'b10`, the output equals `{bit3, funct3}`, where `bit3` is 1 only for (`funct3` = `000` and `opb5` and `funct7b5`) or (`funct3` = `101` and `funct7b5`).

## 6. Combinational Behavior

The module shall implement combinational logic only. Every input combination shall produce a defined `alucontrol` value, so that no latch is inferred.

## 7. Integration Requirements

Inputs:

- `aluop` from the main decoder.
- `funct3`, `opb5` and `funct7b5` from the fetched instruction.

Output:

- `alucontrol` to the ALU.

The ALU Decoder is instantiated inside the controller, alongside the main decoder.

## 8. Verification Requirements

The unit testbench shall verify the following.

### R-Type

- All ten R-type instructions, using their real `funct3` and `funct7` values, produce the correct code.

### I-Type

- All nine I-type ALU instructions (ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI) produce the correct code.
- ADDI with a negative immediate (bit 30 set) produces ADD, not SUB.
- SRAI produces SRA and SRLI produces SRL.

### Other ALUOp Values

- `aluop` = `00` produces ADD for every combination of the other inputs.
- `aluop` = `01` produces SUB for every combination of the other inputs.
- `aluop` = `11` produces ADD.

## 9. Completion Criteria

The module is considered complete when:

- [ ] All ten R-type and nine I-type ALU instructions decode correctly.
- [ ] ADDI with a negative immediate decodes as ADD.
- [ ] SRA/SRAI and SRL/SRLI are distinguished correctly.
- [ ] Every `aluop` value produces the specified output.
- [ ] No latches are inferred.
- [ ] The implementation passes its unit testbench.
- [ ] The module integrates correctly with the main decoder and ALU.

## 10. File Locations

RTL:

`rtl/core/alu_decoder.sv`

Unit testbench:

`tb/unit/alu_decoder_tb.sv`

Specification:

`docs/specs/alu_decoder.md`
