# Fault-Tolerant RISC-V Processor

An RV32I-based single-cycle RISC-V processor extended with radix-4 Booth multiplication and SECDED-protected data memory, implemented in SystemVerilog.

## Overview

This project explores processor design, hardware arithmetic, memory protection, and verification.

The current implementation includes a single-cycle processor, an integrated hardware multiplier, and ECC-protected data memory. C programs have been executed on the RTL using Verilator, and synthesized logic has been inspected in Vivado.

Future development will introduce a five-stage pipeline and evaluate additional fault-tolerance techniques, with a focus on reliability, performance, area, and power.

## Current Implementation

### Single-Cycle Processor

- 32-bit datapath.
- 32 x 32-bit register file.
- ALU, instruction decoding, immediate generation, and control logic.
- Load/store operations, branches, and jumps.
- Integrated MUL instruction support.

The processor extends an RV32I-based design with MUL support; it does not implement the complete RV32M extension.

### Radix-4 Booth Multiplier

- Signed 32 x 32-bit multiplication.
- Full 64-bit product generation.
- Radix-4 Booth recoding to reduce partial products.
- 3:2 compressor tree for partial-product reduction.
- Final carry-propagate adder.
- Lower 32 bits written to the destination register for MUL.

### SECDED-Protected Data Memory

- (39,32) Hamming SECDED encoding.
- Single-bit error correction.
- Double-bit error detection.
- Encoding during stores and decoding during loads.
- Read-modify-write support for byte and halfword stores.

## Verification and Results

An AI-assisted interface was used to run C programs on the processor through Verilator and check their results.

Successfully executed programs include:

- 3 x 3 matrix multiplication.
- Bubble sort.
- Recursive factorial.
- Weighted checksum.

A C benchmark returned the expected value of 1532 in 3,046 cycles, approximately half the cycles required by the software-multiplication version.

This comparison measures execution cycles. Execution-time comparisons also require the operating clock frequency.

Vivado synthesis and schematic inspection have been performed, including inspection of the multiplier and ECC circuitry.

## Development Roadmap

| Stage | Status |
|---|---|
| Single-cycle RV32I-based processor | Implemented |
| Radix-4 Booth multiplier | Implemented |
| MUL instruction integration | Implemented |
| SECDED-protected data memory | Implemented |
| C program execution using Verilator | Demonstrated |
| Vivado synthesis and schematic inspection | Performed |
| Five-stage pipelined processor | Planned |
| Data forwarding and hazard detection | Planned |
| Pipeline flushing and branch handling | Planned |
| Performance monitoring and CPI measurement | Planned |
| TMR-based protection | Planned |
| Fault injection and reliability analysis | Planned |
| FPGA implementation | Planned |
| ASIC synthesis and physical design | Planned |

## Planned Verification

Further verification will include:

- Additional directed instruction tests.
- Randomized instruction testing.
- SystemVerilog assertions.
- Functional coverage.
- Cocotb-based testing.
- RISC-V architectural tests.
- Spike reference-model comparison.
- Formal verification using riscv-formal and SymbiYosys.
- Fault-injection experiments.

These activities are planned and are not claimed as completed verification.

## Planned Fault-Tolerance Study

The project aims to compare different processor configurations using consistent workloads and fault-injection conditions.

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

- SystemVerilog
- RISC-V GCC
- Verilator
- Vivado

### Planned for Further Development

- Cocotb
- Spike
- riscv-formal
- SymbiYosys
- Yosys
- OpenLane
- SKY130

## Project Status

Active Development

The single-cycle processor, hardware multiplier, and SECDED-protected data memory are implemented.

The next major stage is a five-stage pipeline with data forwarding, hazard detection, pipeline flushing, and branch handling.

## Authors

- Bhoomika Rohith
- Chinmay Rao
