# Fault-Tolerant RISC-V Processor

An RV32I-based single-cycle RISC-V processor extended with radix-4 Booth multiplication and SECDED-protected data memory, implemented in SystemVerilog.

Five-stage pipelining with hazard detection and forwarding units, along with ECC fault-injection testing, is under development.

## Overview

This project explores processor design, hardware arithmetic, memory protection, verification, synthesis, and static timing analysis.

The current implementation includes:

- A single-cycle RV32I-based processor with MUL instruction support.
- An integrated radix-4 Booth multiplier.
- SECDED-protected data memory.
- C program execution on the RTL using Verilator.
- Vivado synthesis and schematic inspection.
- Yosys synthesis and Nangate45 standard-cell mapping.
- Pre-layout static timing analysis using OpenSTA.

## Current Implementation

### Single-Cycle Processor

- 32-bit datapath.
- 32 x 32-bit register file.
- ALU, instruction decoding, and control logic.
- I/S/B/U/J immediate generation.
- Load/store operations, branches, and jumps.
- Integrated MUL instruction support.

The processor extends an RV32I-based design with MUL support; it does not implement the complete RV32M extension.

### Radix-4 Booth Multiplier

- Signed 32 x 32-bit multiplication.
- Full 64-bit product generation.
- Radix-4 Booth recoding, reducing partial-product rows from 32 to 16.
- 3:2 compressor tree for partial-product reduction.
- Final carry-propagate adder (CPA).
- Lower 32 bits written to the destination register for MUL.

### SECDED-Protected Data Memory

- (39,32) Hamming SECDED encoding: 32 data bits and 7 check bits.
- Single-bit error correction.
- Double-bit error detection.
- Encoding during stores and decoding during loads.
- Read-modify-write support for byte and halfword stores.
- Interface-based SystemVerilog ECC testbench.

## Verification and Results

### C Program Execution

An AI-assisted Python interface was used to run C programs on the processor through Verilator and check their results.

Successfully executed programs include:

- 3 x 3 matrix multiplication.
- Bubble sort.
- Recursive factorial.
- Weighted checksum.

A C benchmark produced the following result:

```text
PASS: C main returned 1532 (expected 1532), 3046 cycles
```

This benchmark used approximately half the execution cycles required by the software-multiplication version.

This comparison measures execution cycles for the selected workload. Execution-time comparisons also require the operating clock frequency.

Simulation checks include expected-result comparisons and assertions for processor and memory behavior. Automated regression checks are configured through GitHub Actions.

### Synthesis and Schematic Inspection

- Synthesized processor RTL using Yosys.
- Inspected gate-level netlists and datapath structure.
- Performed Vivado synthesis and schematic inspection of the multiplier and ECC circuitry.
- Mapped the single-cycle core to **14,229 Nangate45 standard cells** using Yosys.

## Static Timing Analysis

### Flow

The single-cycle core was synthesized and mapped to the Nangate45 standard-cell library using Yosys. The mapped design was then analyzed using OpenSTA.

The analysis included:

- Evaluating pre-layout timing at a **100 MHz target clock frequency**.
- Checking setup timing against a **10 ns clock period**.
- Inspecting the reported critical path.
- Tracing the critical path through the radix-4 Booth multiplier.

Yosys performed synthesis and standard-cell mapping; OpenSTA performed static timing analysis.

### Results

| Parameter | Result |
|---|---|
| Analyzed design | Single-cycle RV32I-based core |
| Synthesis tool | Yosys |
| Standard-cell library | Nangate45 |
| Mapped standard-cell count | 14,229 |
| Static timing analysis tool | OpenSTA |
| Analysis stage | Pre-layout |
| Target clock frequency | 100 MHz |
| Target clock period | 10 ns |
| Worst setup slack | +2.46 ns |
| Critical-path logic | Radix-4 Booth multiplier |

The reported **+2.46 ns worst setup slack** indicates that the analyzed setup timing met the 100 MHz target under the applied constraints.

These are pre-layout results for the synthesized core. Placement, routing, extracted interconnect parasitics, and post-layout timing analysis remain future work.

## Ongoing Development

### Five-Stage Pipelined Processor

Extending the single-cycle implementation into a five-stage pipeline:

1. Instruction Fetch (IF).
2. Instruction Decode / Register Read (ID).
3. Execute (EX).
4. Memory Access (MEM).
5. Writeback (WB).

Current development includes:

- Hazard detection units.
- Data forwarding units.

Pipeline stalling, flushing, and branch handling are part of the pipeline development plan.

### ECC Fault-Injection Testing

Developing fault-injection tests to evaluate:

- Single-bit error correction.
- Double-bit error detection.
- Processor behavior when protected memory contains corrupted data.

Broader reliability analysis and comparisons across protection configurations remain planned.

## Development Roadmap

| Stage | Status |
|---|---|
| Single-cycle RV32I-based processor | Implemented |
| Radix-4 Booth multiplier | Implemented |
| MUL instruction integration | Implemented |
| SECDED-protected data memory | Implemented |
| Interface-based SystemVerilog ECC testbench | Implemented |
| C program execution using Verilator | Demonstrated |
| GitHub Actions regression automation | Configured |
| Vivado synthesis and schematic inspection | Performed |
| Yosys synthesis and Nangate45 standard-cell mapping | Performed |
| OpenSTA pre-layout timing analysis | Performed |
| Five-stage pipelined processor | In progress |
| Data forwarding and hazard detection | In progress |
| ECC fault-injection test development | In progress |
| Pipeline stalling, flushing, and branch handling | Planned |
| Performance monitoring and CPI measurement | Planned |
| TMR-based protection | Planned |
| Systematic fault-injection and reliability analysis | Planned |
| FPGA implementation | Planned |
| ASIC physical design and post-layout timing analysis | Planned |

## Further Verification

Further verification will include:

- Additional directed instruction tests.
- Randomized instruction testing.
- Expanded SystemVerilog assertions.
- Expanded functional coverage.
- Cocotb-based testing.
- RISC-V architectural tests.
- Spike reference-model comparison.
- Formal verification using riscv-formal and SymbiYosys.
- Expanded fault-injection experiments and reliability measurements.

These activities extend the existing simulation checks. Comprehensive architectural and formal verification are not claimed as complete.

## Planned Fault-Tolerance Study

The project aims to compare processor configurations using consistent workloads and fault-injection conditions.

| Configuration | Description |
|---|---|
| Baseline | Processor without added fault protection |
| ECC | Processor with ECC-protected data memory |
| TMR | Processor with redundancy in selected hardware blocks |
| ECC + TMR | Combined memory protection and hardware redundancy |
| Protected accelerator | Processor with an accelerator and additional fault protection |

Evaluation metrics will include:

- Execution cycles and CPI.
- FPGA LUT and flip-flop utilization.
- Maximum operating frequency.
- ASIC area and estimated power.
- Fault detection rate.
- Fault correction rate.
- Silent Data Corruption (SDC) rate.
- Performance and resource overhead.

## Tools

### Used in Current Development

| Tool / Language | Purpose |
|---|---|
| SystemVerilog | Processor, multiplier, ECC, and testbench implementation |
| Python | AI-assisted C-to-RTL execution interface |
| RISC-V GCC | RISC-V software compilation |
| Verilator | RTL simulation and C program execution |
| Vivado | Synthesis and schematic inspection |
| Yosys | RTL synthesis and standard-cell mapping |
| OpenSTA | Pre-layout static timing analysis |
| Nangate45 | Standard-cell library for ASIC mapping and timing analysis |
| GitHub Actions | Regression automation |

### Planned for Further Development

- Cocotb.
- Spike.
- riscv-formal.
- SymbiYosys.
- OpenLane.
- SKY130.

## Project Status

**Active Development**

The single-cycle processor, hardware multiplier, and SECDED-protected data memory are implemented.

C program execution, synthesis, standard-cell mapping, and pre-layout timing analysis have been demonstrated.

Five-stage pipelining with hazard detection and forwarding units, along with ECC fault-injection testing, is ongoing.

## Authors

- Bhoomika Rohith
- Chinmay Rao
