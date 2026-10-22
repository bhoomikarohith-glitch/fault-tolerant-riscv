# Running the core on the Basys 3

1. Build the program you want to run, e.g. `make sim PROG=fibonacci PASS_VAL=6765`.
   This creates `build/fibonacci.mem`.
2. Copy it to `fpga/program.mem` (the name `fpga_top.sv` expects).
3. In Vivado, create a project for part **xc7a35tcpg236-1** (Basys 3) and add:
   - design sources: everything in `rtl/common/` (add `rv_pkg.sv`), `rtl/core/`,
     `rtl/memory/`, `rtl/cpu_top.sv` and `fpga/fpga_top.sv`
   - `fpga/program.mem` (as a design source; Vivado treats it as a memory init file)
   - constraints: `fpga/basys3.xdc`
4. Set `fpga_top` as the top module.
5. Run Synthesis, then Implementation. Open the timing summary:
   **WNS must be positive**. If it is negative, change `CLKOUT0_DIVIDE_F` in
   `fpga_top.sv` from 40.0 to 50.0 (20 MHz) and rerun.
6. Generate Bitstream, open Hardware Manager, Auto Connect, Program Device.
7. Press the centre button (reset). The LEDs show the result:
   `led[15]` on = program finished; `led[14:0]` = result in binary.

| Program | Expected `led[14:0]` |
|---|---|
| rv32i_smoke | 1 (`000000000000001`) |
| array_sum | 64 (`000000001000000`) |
| fibonacci | 6765 (`001101001101101`) |
| bubble_sort | 8111 (`001111110101111`) |

To switch programs, replace `fpga/program.mem` and rerun from synthesis.