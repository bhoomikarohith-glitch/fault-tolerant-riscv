module alu (
  input  logic [31:0] a,
  input  logic [31:0] b,
  input  logic [3:0]  alucontrol,
  output logic [31:0] result
);

  import rv_pkg::*;

  logic [4:0] shamt;  //shift amount
  assign shamt = b[4:0];  //takes last 5 LSBits of b

  always_comb begin
    case (alucontrol)
      ALU_ADD:  result = a + b;  //addition
      ALU_SUB:  result = a - b;  //subtraction
      ALU_SLL:  result = a << shamt;  //logical LEFT shift 'a' by shamt
      ALU_SLT:  result = {31'b0, $signed(a) < $signed(b)};  //result = 1 if signed(a<b), concatenation
      ALU_SLTU: result = {31'b0, a < b};  //result = 1 if unsigned(a<b)
      ALU_XOR:  result = a ^ b; // a xor b
      ALU_SRL:  result = a >> shamt; //logical RIGHT shift by shamt
      ALU_SRA:  result = $signed(a) >>> shamt;  //arithmetic RIGHT shift by shamt
      ALU_OR:   result = a | b; //a or b
      ALU_AND:  result = a & b; //a and b

      // Route the lower 32 bits of the Booth Multiplier out to rd
      ALU_MULX: result = multiplier_out[31:0]; 
      
      default:  result = 32'b0; //default alu result = 0
    endcase
  end

endmodule
