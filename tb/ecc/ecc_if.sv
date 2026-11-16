// =============================================================================
// ecc_if.sv  -  interface between the class-based testbench and ecc_top
// -----------------------------------------------------------------------------
// An interface is a bundle of wires with a name. The testbench classes can't
// hold real wires, so they hold a "virtual interface": a handle that points
// at this bundle. The driver writes the inputs through it, the monitor reads
// everything back through it.
//
// ecc_top is combinational, so the clock here only paces the testbench:
// the driver changes inputs on the rising edge, the monitor samples on the
// falling edge (half a cycle later, when everything has settled).
// =============================================================================

interface ecc_if (input logic clk);
  logic        valid;        // 1 = the inputs below hold a real transaction
  logic [31:0] data_in;
  logic [38:0] flip_mask;
  logic [38:0] codeword;
  logic [31:0] data_out;
  logic        single_err;
  logic        double_err;
  logic [5:0]  syndrome;
endinterface
