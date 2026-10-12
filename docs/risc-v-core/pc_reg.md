# Program Counter Register Specification

**Project:** Fault-Tolerant RV32I RISC-V Processor  
**Module:** Program Counter Register  
**RTL File:** `rtl/core/pc_reg.sv`  
**Specification File:** `docs/specs/pc_reg.md`  
**Status:** Design Specification

## 1. Purpose

The Program Counter (PC) Register holds the byte address of the instruction currently being executed. On every rising clock edge it loads the next address produced by the next-PC logic.

It is the only state element in the instruction-fetch path. In the single-cycle processor it updates on every cycle; in the pipelined processor its enable input will be used to stall fetch.

## 2. Functional Requirements

The module shall:

1. Store a 32-bit program counter value.
2. Load the reset address whenever reset is asserted.
3. Load `pcnext` on each rising clock edge when enabled.
4. Hold its current value on a rising clock edge when not enabled.
5. Give reset priority over enable.
6. Drive its current value continuously on its output.

The module shall not calculate the next address. That responsibility belongs to the next-PC logic.

## 3. Interface Specification

| Signal | Direction | Width | Description |
|---|---|---|---|
| `clk` | Input | 1 bit | Clock; the register updates on the rising edge |
| `reset` | Input | 1 bit | Active-high, asynchronous reset |
| `en` | Input | 1 bit | Update enable |
| `pcnext` | Input | 32 bits | Next PC value from the next-PC logic |
| `pc` | Output | 32 bits | Current PC value |

### Parameters

| Parameter | Default | Description |
|---|---|---|
| `RESET_PC` | `32'h0000_0000` | Address loaded on reset |

### Interface Notes

- In the single-cycle processor, `en` is tied to `1'b1`.
- `pc` drives the instruction memory address and the next-PC logic.

## 4. Reset Behavior

Reset shall be active-high and asynchronous, matching the reference resettable flip-flop.

- When `reset` is asserted, `pc` shall become `RESET_PC` immediately, without waiting for a clock edge.
- While `reset` remains asserted, `pc` shall stay at `RESET_PC`.
- After `reset` is released, normal updates resume from the next rising clock edge.

**Design decision:** The reset address is a parameter rather than a fixed zero, so that a different boot address (for example on the FPGA) needs no RTL change.

## 5. Update Behavior

| `reset` | `en` | Behavior |
|---|---|---|
| 1 | Any | `pc` = `RESET_PC` (asynchronous) |
| 0 | 1 | `pc` <= `pcnext` on the rising clock edge |
| 0 | 0 | `pc` holds its value |

**Design decision:** The reference single-cycle processor uses a register with no enable. This implementation adds `en` now, so the pipelined processor's stall logic can reuse the module without modification.

## 6. Alignment

The module shall store all 32 bits exactly as received and shall not force alignment.

Alignment is guaranteed by the next-PC logic: PC + 4, even branch and jump offsets, and JALR with bit 0 cleared. Exceptions for misaligned instruction addresses are outside the scope of this processor.

## 7. Fault-Tolerance Requirements

The register shall be implemented as a single clocked block holding one 32-bit value, with no other logic inside the module.

This allows the TMR stage to instantiate three copies of the module and add a majority voter on their outputs, without changing this module.

## 8. Integration Requirements

Inputs:

- `pcnext` from the next-PC logic.
- `clk` and `reset` from the processor top level.
- `en` tied to `1'b1` in the single-cycle processor.

Output:

- `pc` to the instruction memory address input and to the next-PC logic.

## 9. Verification Requirements

The unit testbench shall verify the following.

### Reset

- `pc` equals `RESET_PC` while reset is asserted.
- Reset asserted between clock edges takes effect immediately (asynchronous).
- A non-default `RESET_PC` parameter value is honored.
- Reset overrides `en` = 1 and `en` = 0.

### Update

- A sequence of `pcnext` values is loaded on successive rising edges.
- No update occurs on the falling clock edge.

### Enable

- With `en` = 0, `pc` holds its value for several cycles while `pcnext` changes.
- Updates resume correctly when `en` returns to 1.

## 10. Completion Criteria

The module is considered complete when:

- [ ] Reset loads `RESET_PC` asynchronously.
- [ ] The register updates only on the rising clock edge.
- [ ] The enable input holds the value when deasserted.
- [ ] Reset has priority over enable.
- [ ] The implementation passes its unit testbench.
- [ ] The module integrates correctly with the instruction memory and next-PC logic.

## 11. File Locations

RTL:

`rtl/core/pc_reg.sv`

Unit testbench:

`tb/unit/pc_reg_tb.sv`

Specification:

`docs/specs/pc_reg.md`