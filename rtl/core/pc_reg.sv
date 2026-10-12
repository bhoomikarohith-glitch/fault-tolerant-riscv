module pc_reg #(
  parameter logic [31:0] RESET_PC = 32'h0000_0000
) (
  input  logic        clk,
  input  logic        reset,
  input  logic        en,
  input  logic [31:0] pcnext,
  output logic [31:0] pc
);

  always_ff @(posedge clk or posedge reset) begin
    if (reset)   pc <= RESET_PC;
    else if (en) pc <= pcnext;
  end

endmodule
