// =============================================================================
// mux2.sv  -  Two-input multiplexer (ALU operand B select)           
// -----------------------------------------------------------------------------
// sel = 0 -> y = d0,  sel = 1 -> y = d1.
// In the datapath: d0 = register rs2, d1 = immediate, sel = alusrc.
// =============================================================================

module mux2 #(
  parameter int WIDTH = 32
) (
  input  logic [WIDTH-1:0] d0,      // chosen when sel = 0
  input  logic [WIDTH-1:0] d1,      // chosen when sel = 1
  input  logic             sel,
  output logic [WIDTH-1:0] y
);

  // condition ? if_true : if_false
  assign y = sel ? d1 : d0;

endmodule