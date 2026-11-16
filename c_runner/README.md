# Run C on the single-cycle RISC-V RTL

Place this `c_runner` folder inside your project beside `rtl`, `tb`, and `scripts`.
Open the project root in VS Code and use your WSL terminal.

Activate the environment you already created.

```bash
source .venv-rv/bin/activate
python -m pip install "ziglang==0.13.0"
python c_runner/run.py --vcd
```

The runner uses the existing Verilator installation. If missing, install it
with `python -m pip install verilator`. A C++ compiler and make are also required
(`sudo apt install g++ make`).

The default program is `c_runner/programs/sum.c`. It loads an initialized array,
checks that a BSS variable starts at zero, sums 1 through 10, and returns 55.
The runner compiles the C and startup assembly, extracts the executable into
`build/c_runner/program.mem`, builds the RTL simulator, and executes the program.

Expected successful output includes this line.

```text
PASS: C main returned 55 (expected 55), 671 cycles
```

View the optional waveform after a successful run.

```bash
gtkwave build/c_runner/c_program.vcd
```

Expand `tb_c_program` and `dut` to inspect `pc`, `instr`, `memwrite`, `dataadr`,
`writedata`, `readdata`, and the core's internal registers.

## Run recursive factorial

```bash
python c_runner/run.py --program factorial --vcd
```

Expected output includes `C main returned 720`. The C `*` operator uses the
included RV32I software multiplication helper. This exercises recursion, stack
frames, JAL/JALR, and the base integer instruction set.

## Run your own C source

Return the result from `int main(void)` and supply the expected signed integer.
For example, after saving `my_program.c` in the project root, run this command.

```bash
python c_runner/run.py --source my_program.c --expected 42 --vcd
```

A successful run requires exact agreement with the expected result. A mismatch,
invalid memory access, stack overflow, alignment failure, or watchdog timeout
terminates the simulation with an error. Increase the instruction budget for a
longer program with `--max-cycles 500000`.

## Files and execution

- `run.py` builds the program, converts ELF to hex, and runs Verilator.
- `start.S` initializes sp/gp, clears BSS, calls main, and stores its result.
- `link.ld` places executable instructions and static data in memory.
- `runtime.c` supplies software 32-bit multiplication.
- `tb_c_program.sv` instantiates your existing `cpu_top`, instruction memory, and
  data memory, and checks the result and enabled assertions.
- `programs/sum.c` and `programs/factorial.c` are editable examples.

The runner uses Zig 0.13.0's Clang C compiler with a generic RV32I target and ILP32
ABI. An installed `riscv64-unknown-elf-gcc` is a fallback when Zig is unavailable.
Local validation used Zig and Verilator. The GCC fallback has not been run here.
Compiler optimization is set to `-O0` so the loop, stack accesses, and function
calls are visible. Execution begins at address zero.

Both actual RTL memories load the same complete 4096-byte image. Each memory
interprets addresses identically, and the linker places instructions and data
in distinct ranges. Initialized data and constants are therefore available to
the load instructions as soon as execution starts.

| Byte addresses | Allocation |
| --- | --- |
| `0x000–0x7FF` | Up to 2 KB of instructions |
| `0x800–0xBFF` | Up to 1 KB of initialized data, constants, and BSS |
| `0xC00–0xFEF` | Stack growing downward from `0xFF0` |
| `0xFFC–0xFFF` | Main's return value, observed by the testbench |

Programs must fit these allocations. Linker assertions enforce the code and
static-data limits. The simulator checks the stack pointer after startup has
finished initializing it.

Use small freestanding integer programs. Operating-system services, `printf`,
heap allocation, floating-point support, division runtime helpers, and 64-bit
arithmetic runtime helpers require additional runtime implementation. Regular
32-bit C multiplication uses the supplied software helper. The compiler targets
RV32I and does not automatically emit the custom MULX opcode.

This program-execution harness checks the expected return value and basic RTL
invariants. Its PASS message describes the selected C program run. The separate
layered testbench provides the earlier 385-bin functional coverage results.

## Local validation

The original uploaded RTL was exercised with the following results.

| Program | Expected return | Observed return | Cycles |
| --- | ---: | ---: | ---: |
| Array sum | 55 | 55 | 671 |
| Recursive factorial of 6 | 720 | 720 | 734 |

Enabled assertions passed, and a VCD waveform was generated for the sum test.
An intentionally wrong expected return of 721 for factorial triggered a fatal
mismatch, confirming that the result checker rejects incorrect results.
