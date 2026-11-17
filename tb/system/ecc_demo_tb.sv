// =============================================================================
// ecc_demo_tb.sv  -  live ECC demo: flip bits in memory while a program runs
// -----------------------------------------------------------------------------
// Runs bubble_sort on the processor. At cycle 20, after the program has
// written its array to memory but before it reads it back, the testbench
// flips bits in the stored word at 0x810 (array value 42), like a radiation
// strike on the memory chip. Then it shows what the ECC decoder does when the
// core loads that word, and whether the program still gets the right answer.
//
//   +FLIPS=0   no fault (baseline)
//   +FLIPS=1   one flipped bit   -> ECC corrects it, answer still right
//   +FLIPS=2   two flipped bits  -> ECC detects it (double_err), can't fix
//
// Run (from the repo root, after `make test` has built build/bubble_sort.mem):
//   make ecc-demo FLIPS=1
// =============================================================================

`timescale 1ns/1ps

module ecc_demo_tb;
  import ecc_pkg::*;

  localparam [31:0] TARGET   = 32'h0000_0810;  // array element holding 42
  localparam int    WIDX     = TARGET >> 2;    // its word index in memory
  localparam int    AT_CYCLE = 20;             // when the "strike" happens
  localparam [31:0] PASS_VAL = 32'd8111;       // bubble_sort's correct answer

  logic        clk = 1'b0, reset;
  logic [31:0] pc, dataadr, writedata;
  logic        memwrite;
  int          cycles = 0, flips = 1;
  bit          watching   = 1'b0;   // 1 while the damaged word is in memory
  bit          saw_double = 1'b0;   // decoder raised double_err on that word

  cpu_top #(.MEM_FILE("build/bubble_sort.mem")) dut (
    .clk (clk), .reset (reset), .pc (pc), .memwrite (memwrite),
    .dataadr (dataadr), .writedata (writedata)
  );

  always #5 clk = ~clk;

  // data bits sitting in a codeword WITHOUT any correction:
  // what a memory with no ECC would hand to the core
  function automatic logic [31:0] raw_data(input logic [38:0] cw);
    logic [31:0] d; int di = 0;
    for (int pos = 1; pos <= 38; pos++)
      if ((pos & (pos - 1)) != 0) begin d[di] = cw[pos]; di++; end
    return d;
  endfunction

  initial begin
    if (!$value$plusargs("FLIPS=%d", flips)) flips = 1;
    $display("");
    $display("=================== ECC DEMO: bubble_sort, %0d flipped bit(s) ===================", flips);
    reset = 1'b1;
    repeat (2) @(posedge clk);
    #1 reset = 1'b0;
  end

  // ============================================ WAVEFORM SIGNALS (GTKWave)
  // Named so they read clearly on screen. Open with:
  //   gtkwave build/ecc_demo.vcd tb/system/ecc_demo.gtkw
  logic        strike;                  // 1 for the cycle the bits are flipped
  logic [38:0] stored_codeword;         // the 39 bits physically in memory
  logic [31:0] value_without_ecc;       // what a plain memory would return
  logic [31:0] value_with_ecc;          // what the ECC decoder returns
  logic [5:0]  syndrome;                // which bit the checks point at
  logic        single_err, double_err;  // decoder verdict on that word
  logic        core_loads_word;         // core is reading 0x810 this cycle
  logic [31:0] core_receives;           // data actually handed to the core

  assign stored_codeword   = dut.u_data_mem.mem[WIDX];
  assign value_without_ecc = raw_data(stored_codeword);
  assign core_loads_word   = !reset && dut.instr[6:0] == 7'b0000011 && dataadr == TARGET;
  assign core_receives     = core_loads_word ? dut.readdata : 32'b0;

  // A second decoder that watches the target word all the time, so the
  // waveform shows the error from the moment it appears (the memory's own
  // decoder only looks at whatever address the core is using).
  secded_dec u_watch (
    .codeword   (stored_codeword),
    .data       (value_with_ecc),
    .single_err (single_err),
    .double_err (double_err),
    .syndrome   (syndrome)
  );

  assign strike = (cycles == AT_CYCLE) && (flips > 0);

  initial begin
    $dumpfile("build/ecc_demo.vcd");
    $dumpvars(1, ecc_demo_tb);          // just the signals above
    #800 $dumpoff;                      // keep the trace to the interesting part
  end

  // ------------------------------------------------------------- the strike
  always @(negedge clk) begin
    if (!reset) begin
      cycles++;
      if (cycles == AT_CYCLE && flips > 0) begin
        logic [38:0] cw_old, cw_new;
        cw_old = dut.u_data_mem.mem[WIDX];
        cw_new  = cw_old ^ (39'd1 << 12);                 // codeword bit 12 = data bit 7
        if (flips == 2) cw_new = cw_new ^ (39'd1 << 20);   // codeword bit 20 = data bit 14
        dut.u_data_mem.mem[WIDX] = cw_new;
        watching = 1'b1;
        $display("cycle %0d: RADIATION STRIKE on memory word 0x%08h", cycles, TARGET);
        $display("    stored codeword before: %039b", cw_old);
        $display("    stored codeword after : %039b", cw_new);
        $display("    value stored           : %0d", raw_data(cw_old));
        $display("    a memory WITHOUT ECC would now return: %0d  <-- corrupted", raw_data(cw_new));
      end
    end
  end

  // ------------------------------------------- watch the core read that word
  // (only while the faulty word is still in memory: once the program stores
  //  a new value there, the fault is overwritten and gone)
  always @(negedge clk) begin
    if (!reset && watching && memwrite && dataadr == TARGET) begin
      $display("cycle %0d: program stores a new value to 0x%08h -> damaged word overwritten",
               cycles, TARGET);
      watching = 1'b0;
    end
    if (dut.u_data_mem.u_dec.double_err && dut.instr[6:0] == 7'b0000011 && dataadr == TARGET)
      saw_double = 1'b1;
    if (!reset && watching && dut.instr[6:0] == 7'b0000011 && dataadr == TARGET) begin
      $display("cycle %0d: core loads 0x%08h -> decoder: syndrome=%0d single_err=%0b double_err=%0b -> core receives %0d",
               cycles, TARGET, dut.u_data_mem.u_dec.syndrome,
               dut.u_data_mem.u_dec.single_err, dut.u_data_mem.u_dec.double_err,
               dut.u_data_mem.word);
    end
  end

  // ------------------------------------------------------------- the result
  always @(negedge clk) begin
    if (!reset && memwrite && dataadr == 32'h0000_0FFC) begin
      $display("");
      if (writedata == PASS_VAL)
        $display("RESULT: program returned %0d (expected %0d) -> CORRECT", writedata, PASS_VAL);
      else
        $display("RESULT: program returned %0d (expected %0d) -> WRONG ANSWER", writedata, PASS_VAL);
      if (saw_double)
        $display("        but ECC raised double_err: the hardware KNOWS the data was bad,\n        so a real system would stop or retry instead of trusting it.");
      $display("=================================================================================");
      $finish;
    end
    if (cycles > 5000) begin $display("RESULT: timeout"); $finish; end
  end
endmodule
