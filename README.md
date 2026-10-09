# Fault-Tolerant RV32I RISC-V Processor

A fault-tolerant RV32I RISC-V processor designed with hardware reliability, verification, and implementation in mind.

## Overview

This project develops a RISC-V processor from RTL through verification and hardware implementation, with a focus on improving processor reliability against hardware faults.

The project explores and evaluates different fault-tolerance techniques, including:

- Error Correcting Codes (ECC)
- Triple Modular Redundancy (TMR)
- Fault injection and recovery
- Formal verification
- FPGA implementation
- ASIC synthesis and physical design

The goal is to study the trade-offs between **reliability, performance, area, and power** across different processor configurations.

## Architecture

The processor is based on the **RISC-V RV32I instruction set architecture**.

Planned development stages:

1. RV32I single-cycle processor
2. 5-stage pipelined processor
3. Data forwarding and hazard detection
4. Pipeline flushing and branch handling
5. Performance monitoring and CPI measurement
6. ECC-protected memories
7. TMR-based fault tolerance
8. Fault injection and reliability analysis
9. FPGA implementation
10. ASIC synthesis and physical design

## Verification

The processor will be verified using a combination of:

- Directed tests
- Randomized instruction testing
- Cocotb
- Verilator
- RISC-V architectural tests
- Spike reference-model comparison
- SystemVerilog assertions
- Functional coverage
- Formal verification using riscv-formal and SymbiYosys

## Fault-Tolerance Study

Multiple processor configurations will be evaluated to quantify the cost and effectiveness of fault-tolerance mechanisms.

| Configuration | Description |
|---|---|
| A | Baseline processor |
| B | ECC-protected processor |
| C | TMR-protected processor |
| D | ECC + TMR |
| E | ECC + TMR + custom instruction |
| F | ECC + TMR + protected accelerator |

Metrics will include:

- FPGA LUT utilization
- Flip-flop utilization
- Maximum operating frequency
- ASIC area
- Power
- CPI
- Execution cycles
- Fault detection rate
- Fault correction rate
- Silent Data Corruption (SDC) rate
- Reliability improvement
- Performance and area overhead

## Repository Structure

```text
rtl/              Processor RTL
tb/               Testbenches
verification/     Verification infrastructure
software/         RISC-V software and test programs
scripts/          Build and simulation scripts
fpga/             FPGA implementation
asic/             ASIC synthesis and physical design
fault_injection/  Fault injection experiments
results/          Experimental results and measurements
docs/             Architecture and project documentation
```

## Tools

The project is expected to use tools including:

- SystemVerilog
- RISC-V GCC
- Verilator
- Cocotb
- Spike
- riscv-formal
- SymbiYosys
- Yosys
- OpenLane
- SKY130
- Vivado

## Project Status

**Active Development**

The architecture, verification environment, fault-tolerance mechanisms, and implementation flow are being developed incrementally.

## Authors

**Bhoomika Rohith**

**Chinmay Rao**
