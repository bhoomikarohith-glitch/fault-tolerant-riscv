# ALU Specification

**Project:** Fault-Tolerant RV32I RISC-V Processor  
**Module:** Arithmetic Logic Unit (ALU)  
**RTL File:** `rtl/core/alu.sv`  
**Specification File:** `docs/specs/alu.md`  
**Status:** Design Specification

## 1. Purpose

The ALU performs the arithmetic, logical, shift and comparison operations required by RV32I instructions.

Its result is used for:

- Register-register operations (R-type)
- Register-immediate operations (I-type)
- Load and store address calculation
- JALR target calculation (before bit 0 is cleared by the next-PC logic)

The module is purely combinational.

## 2. Functional Requirements

The module shall:

1. Accept two 32-bit operands.
2. Accept a 4-bit operation select from the ALU decoder.
3. Perform all ten RV32I ALU operations listed in Section 4.
4. Produce a 32-bit result.
5. Produce a deterministic zero result for unsupported operation codes.

The module shall not decode instructions, select its own operands, or decide whether a branch is taken.

## 3. Interface Specification

| Signal | Direction | Width | Description |
|---|---|---|---|
| `a` | Input | 32 bits | Operand A (`SrcA`, register `rs1`) |
| `b` | Input | 32 bits | Operand B (`SrcB`, register `rs2` or the extended immediate) |
| `alucontrol` | Input | 4 bits | Operation select from the ALU decoder |
| `result` | Output | 32 bits | Operation result |

### Interface Notes

- The operand B multiplexer (register or immediate) is outside this module.
- The module does not require a clock or reset input.
- The module has no Zero output (see Section 7).

## 4. Operation Encoding

The `alucontrol` signal shall use the following encoding:

| `alucontrol` | Operation | Result | Instructions |
|---|---|---|---|
| `4'b0000` | ADD | `a + b` | ADD, ADDI, loads, stores, JALR |
| `4'b1000` | SUB | `a - b` | SUB |
| `4'b0001` | SLL | `a` shifted left by `b[4:0]` | SLL, SLLI |
| `4'b0010` | SLT | 1 if `a < b` (signed), else 0 | SLT, SLTI |
| `4'b0011` | SLTU | 1 if `a < b` (unsigned), else 0 | SLTU, SLTIU |
| `4'b0100` | XOR | `a ^ b` | XOR, XORI |
| `4'b0101` | SRL | `a` shifted right by `b[4:0]`, zero-filled | SRL, SRLI |
| `4'b1101` | SRA | `a` shifted right by `b[4:0]`, sign-filled | SRA, SRAI |
| `4'b0110` | OR | `a \| b` | OR, ORI |
| `4'b0111` | AND | `a & b` | AND, ANDI |
| Other values | Invalid | Zero | None |

**Design decision:** The reference ALU uses a 3-bit control signal and supports five operations (add, subtract, AND, OR, set-less-than). This implementation uses a 4-bit control signal to support all ten RV32I operations.

**Design decision:** The low three bits of the encoding equal the instruction's `funct3`, and bit 3 is set only for SUB and SRA (the operations selected by instruction bit 30). This makes the ALU decoder simple.

## 5. Arithmetic Behavior

- ADD and SUB shall wrap modulo 2^32. There is no overflow detection, because RV32I does not trap on overflow.
- SLT shall compare the operands as signed two's-complement values.
- SLTU shall compare the operands as unsigned values.
- SLT and SLTU shall produce a full 32-bit result of exactly 0 or 1.

## 6. Shift Behavior

- Shift amounts shall use only `b[4:0]`. Bits `b[31:5]` shall be ignored, so a shift amount of 32 behaves as a shift of 0.
- SLL and SRL shall fill vacated bits with zeros.
- SRA shall fill vacated bits with copies of `a[31]`. Operand A must be treated as signed for this operation; otherwise SRA behaves like SRL.

## 7. Operations Outside the ALU

- **No Zero flag.** The reference datapath uses the ALU's Zero output to resolve BEQ. This implementation resolves all six branch types in a separate branch comparator, so the ALU has no Zero output and branch logic does not depend on it.
- **LUI** is handled by selecting the U-type immediate in the result (write-back) multiplexer.
- **AUIPC** is handled by the next-PC logic's `pctarget` output (PC + immediate), selected in the result multiplexer.

## 8. Combinational Behavior

The module shall implement combinational logic only. Whenever `a`, `b` or `alucontrol` changes, `result` shall update after the logic settles.

Every path through the logic shall assign `result`, so that no latch is inferred.

## 9. Integration Requirements

Inputs:

- `a` from register file read port 1.
- `b` from the operand B multiplexer (register file read port 2, or the immediate generator).
- `alucontrol` from the ALU decoder.

Output:

- `result` to the data memory address, the result multiplexer, and the next-PC logic (for JALR).

## 10. Verification Requirements

The unit testbench shall be self-checking and shall report a pass/fail count. It shall verify the following.

### Directed Edge Cases (every operation)

- Operand values 0, 1, −1 (`0xFFFF_FFFF`), `0x7FFF_FFFF` and `0x8000_0000`, in combination.

### Arithmetic

- ADD overflow wraps: `0x7FFF_FFFF + 1 = 0x8000_0000`.
- SUB underflow wraps: `0 − 1 = 0xFFFF_FFFF`.

### Comparison

- `0xFFFF_FFFF` compared with 1: SLT gives 1, SLTU gives 0.
- `0x8000_0000` compared with `0x7FFF_FFFF`: SLT gives 1, SLTU gives 0.
- Equal operands give 0 for both.

### Shifts

- Shift amounts 0, 1 and 31.
- `b` = 32 and `b` = `0xFFFF_FFE1` use only `b[4:0]`.
- SRA and SRL differ on a negative operand.

### Invalid Codes

- Every unsupported `alucontrol` value produces zero.

### Random Testing

- At least 1000 random operand pairs per operation, checked against a reference result computed in the testbench.

## 11. Completion Criteria

The module is considered complete when:

- [ ] All ten operations are supported.
- [ ] The operation encodings match this specification.
- [ ] Shifts use only `b[4:0]`.
- [ ] SRA sign-fills and SLT/SLTU compare correctly.
- [ ] Invalid operation codes produce zero.
- [ ] No latches are inferred.
- [ ] The implementation passes its unit testbench.
- [ ] The module integrates correctly with the ALU decoder and CPU datapath.

## 12. File Locations

RTL:

`rtl/core/alu.sv`

Unit testbench:

`tb/unit/alu_tb.sv`

Specification:

`docs/specs/alu.md`