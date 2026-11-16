//     1. creates a clock and pulses reset,
//     2. lets the processor run a program,
//     3. watches every store; when the program stores to SIG_ADDR (the
//        "signature" address) it checks the value:
//          value == PASS_VAL  -> prints PASS
//          anything else      -> prints FAIL (the value says which test failed)
//     4. if no signature appears within MAX_CYCLES, prints FAIL (timeout).
//
//   Because it decides PASS/FAIL by itself ("self-checking"), it can run
//   automatically in make test and in CI with no one reading waveforms.
//
//   The parameters are overridden from the command line (iverilog -P...),
//   so the same testbench runs every program. Add +vcd when running vvp to
//   save a waveform file (cpu_top_tb.vcd) for GTKWave.
// =============================================================================

`timescale 1ns/1ps   // simulation time unit = 1 ns, precision = 1 ps

module cpu_top_tb;   // a testbench has no ports: it is the outermost block

  // ------------------------------------------------------------ parameters
  parameter        MEM_FILE   = "build/rv32i_smoke.mem"; // program to run
  parameter        DATA_FILE  = "";                      // riscv-tests: same as MEM_FILE
  parameter [31:0] SIG_ADDR   = 32'h0000_0FFC;           // where the result is stored
  parameter [31:0] PASS_VAL   = 32'd1;                   // value that means "passed"
  parameter int    MAX_CYCLES = 10000;                   // give up after this many cycles

  // ------------------------------------------------------------- signals
  logic        clk = 1'b0;      // clock starts at 0
  logic        reset;
  logic [31:0] pc, dataadr, writedata;
  logic        memwrite;
  int          cycles = 0;      // cycle counter

  // ------------------------------------------- the design under test (DUT)
  cpu_top #(.MEM_FILE(MEM_FILE), .DATA_FILE(DATA_FILE)) dut (
    .clk       (clk),
    .reset     (reset),
    .pc        (pc),
    .memwrite  (memwrite),
    .dataadr   (dataadr),
    .writedata (writedata)
  );

  // --------------------------------------------------------------- clock
  // Every 5 ns, flip the clock: a 10 ns period = 100 MHz.
  always #5 clk = ~clk;

  // --------------------------------------------------------------- reset
  // initial = runs once at time 0 (only allowed in testbenches, and for
  // loading memories).
  initial begin
    if ($test$plusargs("vcd")) begin        // was +vcd given on the command line?
      $dumpfile("cpu_top_tb.vcd");          // waveform file name
      $dumpvars(0, cpu_top_tb);             // record every signal
    end
    reset = 1'b1;                           // hold reset ...
    repeat (2) @(posedge clk);              // ... for two rising clock edges
    #1 reset = 1'b0;                        // then release it, just after the edge
  end

  // -------------------------------------------------------------- checker
  // Check on the FALLING edge: by then this cycle's signals have settled,
  // and the store has not happened yet (it happens on the rising edge).
  always @(negedge clk) begin
    if (!reset) begin
      cycles++;

      // Is the program storing to the signature address right now?
      if (memwrite && dataadr == SIG_ADDR) begin
        if (writedata == PASS_VAL) begin
          $display("PASS: signature 0x%08h at 0x%08h after %0d cycles",
                   writedata, SIG_ADDR, cycles);
          $finish;                          // stop the simulation (success)
        end else begin
          $display("FAIL: signature 0x%08h at 0x%08h (expected 0x%08h), pc = 0x%08h",
                   writedata, SIG_ADDR, PASS_VAL, pc);
          $fatal(1);                        // stop with an error code
        end
      end

      // Safety net: a program stuck in a loop never stores a signature.
      if (cycles >= MAX_CYCLES) begin
        $display("FAIL: timeout after %0d cycles, pc = 0x%08h", cycles, pc);
        $fatal(1);
      end
    end
  end

endmodule