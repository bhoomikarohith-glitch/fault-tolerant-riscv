// =============================================================================
// fpga_top.sv  -  Board wrapper for the Digilent Basys 3       (rows 22-23)
// -----------------------------------------------------------------------------
// WHAT IT DOES
//   Puts cpu_top on the real board and connects it to the outside world:
//     clk   100 MHz board clock -> MMCM (clock generator) -> 25 MHz core clock
//     btnC  centre button = reset (press to run the program again)
//     led   the program's result: the last value stored to SIG_ADDR
//             led[15]    turns on once the program has stored its result
//             led[14:0]  low 15 bits of that result, in binary
//
//   Expected LEDs (all with led[15] on):
//     rv32i_smoke 1, array_sum 64, fibonacci 6765, bubble_sort 8111
//
// WHY 25 MHz
//   In a single-cycle core the WHOLE instruction (fetch, decode, ALU, memory,
//   write-back) must finish in one clock period. 100 MHz (10 ns) is too short;
//   25 MHz (40 ns) leaves plenty of margin. Vivado's timing report confirms it.
// =============================================================================

module fpga_top #(
  parameter        MEM_FILE = "program.mem",    // program; add this file to Vivado
  parameter [31:0] SIG_ADDR = 32'h0000_0FFC     // where programs store their result
) (
  input  logic        clk,      // 100 MHz from the board's oscillator (pin W5)
  input  logic        btnC,     // centre push button (pin U18), 1 when pressed
  output logic [15:0] led       // the 16 LEDs above the switches
);

  logic clk_core;   // the 25 MHz clock the core runs on
  logic locked;     // 1 once the clock generator's output is stable

  // ================================================================ CLOCKING
  // `ifdef SYNTHESIS ... `else ... `endif chooses code at compile time.
  // Vivado defines SYNTHESIS, so it builds the real clock generator.
  // Icarus does not, so simulation uses the board clock directly.
`ifdef SYNTHESIS
  logic clk_fb;      // MMCM feedback loop
  logic clk_unbuf;   // 25 MHz before the global clock buffer

  // MMCME2_BASE is a clock-generator block built into every Artix-7 FPGA.
  // It multiplies the input to an internal "VCO" frequency, then divides:
  //   VCO  = 100 MHz x 10 = 1000 MHz   (must stay within 600-1200 MHz)
  //   out0 = 1000 MHz / 40 = 25 MHz
  // If the timing report shows a negative slack, change 40.0 to 50.0 (20 MHz).
  MMCME2_BASE #(
    .CLKIN1_PERIOD    (10.0),   // input clock period in ns (100 MHz)
    .CLKFBOUT_MULT_F  (10.0),   // multiply to the VCO frequency
    .CLKOUT0_DIVIDE_F (40.0),   // divide down for output 0
    .DIVCLK_DIVIDE    (1)       // no input division
  ) u_mmcm (
    .CLKIN1   (clk),            // board clock in
    .CLKFBIN  (clk_fb),         // feedback in ...
    .CLKFBOUT (clk_fb),         // ... connected to feedback out
    .CLKOUT0  (clk_unbuf),      // 25 MHz out
    .LOCKED   (locked),         // stable?
    .RST      (1'b0),           // never reset the MMCM
    .PWRDWN   (1'b0)            // never power it down
  );

  // BUFG puts the clock on a dedicated global clock network, so it reaches
  // every flip-flop at (almost) the same time.
  BUFG u_bufg (.I(clk_unbuf), .O(clk_core));
`else
  assign clk_core = clk;        // simulation: no MMCM model needed
  assign locked   = 1'b1;
`endif

  // =================================================================== RESET
  // A push button can change at any moment, unrelated to the clock. If a
  // reset were released at a random moment, some flip-flops could leave
  // reset one cycle before others. The fix ("reset synchroniser"):
  //   - ASSERT reset immediately (asynchronously) when the button is pressed
  //     or the clock is not yet stable,
  //   - RELEASE it only on a clock edge, after two flip-flops, so every
  //     flip-flop sees the release on the same edge.
  logic       rst_async;   // raw reset request
  logic [1:0] rst_sync;    // two-stage shift register
  logic       rst_core;    // clean reset for the core

  assign rst_async = btnC | ~locked;           // button pressed OR clock unstable

  always_ff @(posedge clk_core or posedge rst_async) begin
    if (rst_async) rst_sync <= 2'b11;          // assert at once
    else           rst_sync <= {rst_sync[0], 1'b0};  // shift a 0 in each edge
  end

  assign rst_core = rst_sync[1];               // goes low 2 edges after release

  // ==================================================================== CORE
  logic [31:0] pc, dataadr, writedata;
  logic        memwrite;

  cpu_top #(.MEM_FILE(MEM_FILE)) u_cpu (
    .clk       (clk_core),
    .reset     (rst_core),
    .pc        (pc),
    .memwrite  (memwrite),
    .dataadr   (dataadr),
    .writedata (writedata)
  );

  // ========================================================= RESULT ON LEDs
  // Watch every store. When the program stores to SIG_ADDR, remember the
  // value (a register, so the LEDs keep showing it) and set "done".
  logic        done;     // 1 after the result has been stored
  logic [14:0] result;   // low 15 bits of the stored result

  always_ff @(posedge clk_core or posedge rst_core) begin
    if (rst_core) begin
      done   <= 1'b0;                          // LEDs off during reset
      result <= '0;
    end else if (memwrite && dataadr == SIG_ADDR) begin
      done   <= 1'b1;
      result <= writedata[14:0];
    end
  end

  assign led = {done, result};                 // led[15] = done, led[14:0] = result

endmodule