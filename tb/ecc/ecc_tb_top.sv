// =============================================================================
// ecc_tb_top.sv  -  top module of the layered ECC testbench
// -----------------------------------------------------------------------------
// The only "static" part: makes the clock, the interface and the DUT, then
// hands the interface to the test class and runs it. All the real work is in
// ecc_tb_pkg.sv. Set THIS module as the simulation top in Vivado.
// =============================================================================

`timescale 1ns/1ps

module ecc_tb_top;
  import ecc_tb_pkg::*;

  logic clk = 1'b0;
  always #5 clk = ~clk;                 // 100 MHz pacing clock

  ecc_if vif (clk);                     // the pin bundle

`ifndef VERILATOR
  // ---- normal connection (Vivado xsim, Questa, VCS ...)
  ecc_top dut (                         // encoder -> flip bits -> decoder
    .data_in    (vif.data_in),
    .flip_mask  (vif.flip_mask),
    .codeword   (vif.codeword),
    .data_out   (vif.data_out),
    .single_err (vif.single_err),
    .double_err (vif.double_err),
    .syndrome   (vif.syndrome)
  );
`else
  // ---- Verilator only: it cannot settle a class writing an interface
  // signal that feeds combinational logic, so copy the DUT outputs into the
  // interface 2 ns after each rising edge (still before the monitor's
  // falling-edge sample). Vivado never compiles this part.
  logic [38:0] cw_w;  logic [31:0] out_w;  logic se_w, de_w;  logic [5:0] syn_w;
  ecc_top dut (
    .data_in    (vif.data_in),
    .flip_mask  (vif.flip_mask),
    .codeword   (cw_w),
    .data_out   (out_w),
    .single_err (se_w),
    .double_err (de_w),
    .syndrome   (syn_w)
  );
  always @(posedge clk) begin
    #2;
    vif.codeword = cw_w;  vif.data_out = out_w;
    vif.single_err = se_w; vif.double_err = de_w; vif.syndrome = syn_w;
  end
`endif

  initial begin
    ecc_test t;
    t = new(vif, 2000);                 // 3124 directed + 2000 random cases
    t.run();
    if (t.env.scb.errors != 0) $fatal(1, "ECC layered test FAILED");
    $finish;
  end

  // safety net in case something hangs
  initial begin
    #1ms;
    $fatal(1, "TIMEOUT: testbench did not finish");
  end
endmodule
