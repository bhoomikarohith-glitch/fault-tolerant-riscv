# Branch Comparator Specification

**Project:** Fault-Tolerant RV32I RISC-V Processor  
**Module:** Branch Comparator  
**RTL File:** `rtl/core/branch_comp.sv`  
**Specification File:** `docs/specs/branch_comp.md`  
**Status:** Design Specification

## 1. Purpose

The Branch Comparator decides whether a conditional branch is taken. It compares the two source registers using the comparison selected by the instruction's `funct3` field.

Its output is used by the next-PC logic to choose between the branch target and PC + 4.

The module is purely combinational.

## 2. Functional Requirements

The module shall:

1. Accept the values of source registers `rs1` and `rs2`.
2. Accept the branch instruction's `funct3` field.
3. Perform the comparison for all six RV32I branch instructions.
4. Produce a 1-bit result that is 1 when the branch condition is true.
5. Produce zero for `funct3` values that are not branch conditions.

The module shall not determine whether the current instruction is a branch. The next-PC logic qualifies the result with the `branch` control signal.

## 3. Interface Specification

| Signal | Direction | Width | Description |
|---|---|---|---|
| `rd1` | Input | 32 bits | Value of source register `rs1` |
| `rd2` | Input | 32 bits | Value of source register `rs2` |
| `funct3` | Input | 3 bits | Instruction bits `[14:12]` |
| `branchtaken` | Output | 1 bit | 1 when the branch condition is true |

### Interface Notes

- `rd1` and `rd2` connect directly to the register file read ports, not to the ALU operand B multiplexer.
- The module does not require a clock or reset input.

## 4. Comparison Selection

| `funct3` | Instruction | Condition for `branchtaken` = 1 |
|---|---|---|
| `000` | BEQ | `rd1 == rd2` |
| `001` | BNE | `rd1 != rd2` |
| `100` | BLT | `rd1 < rd2` (signed) |
| `101` | BGE | `rd1 >= rd2` (signed) |
| `110` | BLTU | `rd1 < rd2` (unsigned) |
| `111` | BGEU | `rd1 >= rd2` (unsigned) |
| `010`, `011` | Not a branch | `branchtaken` = 0 |

- Signed comparisons shall treat both operands as two's-complement values.
- Unsigned comparisons shall treat both operands as unsigned values.

**Design decision:** The reference design resolves BEQ by subtracting in the ALU and testing its Zero output, and supports only BEQ. This implementation uses a dedicated comparator for all six branch types. The ALU stays independent of branch logic, and the comparison can later be moved earlier in the pipeline to reduce the branch penalty.

## 5. Combinational Behavior

The module shall implement combinational logic only. Whenever `rd1`, `rd2` or `funct3` changes, `branchtaken` shall update after the logic settles.

Every path through the logic shall assign `branchtaken`, so that no latch is inferred.

## 6. Integration Requirements

Inputs:

- `rd1` and `rd2` from the register file read ports.
- `funct3` from the fetched instruction.

Output:

- `branchtaken` to the next-PC logic.

## 7. Verification Requirements

The unit testbench shall verify the following.

### Each Branch Type

- Every branch type with operands that are equal, less than and greater than each other.

### Signed vs Unsigned

- `rd1` = `0xFFFF_FFFF`, `rd2` = 1: BLT taken (−1 < 1), BLTU not taken.
- `rd1` = `0x8000_0000`, `rd2` = `0x7FFF_FFFF`: BLT taken, BLTU not taken.
- Equal operands: BGE and BGEU taken, BLT and BLTU not taken.

### Invalid Selection

- `funct3` = `010` and `011` produce zero.

### Random Testing

- At least 1000 random operand pairs per branch type, checked against a reference result computed in the testbench.

## 8. Completion Criteria

The module is considered complete when:

- [ ] All six branch conditions are supported.
- [ ] Signed and unsigned comparisons behave correctly.
- [ ] Non-branch `funct3` values produce zero.
- [ ] No latches are inferred.
- [ ] The implementation passes its unit testbench.
- [ ] The module integrates correctly with the register file and next-PC logic.

## 9. File Locations

RTL:

`rtl/core/branch_comp.sv`

Unit testbench:

`tb/unit/branch_comp_tb.sv`

Specification:

`docs/specs/branch_comp.md`
