// =============================================================================
// adder.sv  -  Generic adder (used twice inside next_pc.sv)          (row 15)
// -----------------------------------------------------------------------------
// Adds two WIDTH-bit numbers. The result wraps around modulo 2^WIDTH
// (e.g. 0xFFFFFFFC + 4 = 0x00000000); there is no carry-out.
// A parameter makes it reusable at any width.
// =============================================================================

module adder #(
  parameter int WIDTH = 32          // default width; can be changed per use
) (
  input  logic [WIDTH-1:0] a,
  input  logic [WIDTH-1:0] b,
  output logic [WIDTH-1:0] sum
);

  // assign = continuous combinational connection: sum always equals a + b.
  assign sum = a + b;

endmodule