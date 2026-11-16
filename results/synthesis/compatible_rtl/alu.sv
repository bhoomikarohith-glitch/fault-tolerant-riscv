module alu (
  input  logic [31:0] a,
  input  logic [31:0] b,
  input  logic [3:0]  alucontrol,
  output logic [31:0] result
);

  



  localparam logic [6:0] OP_LOAD   = 7'b0000011;
  localparam logic [6:0] OP_STORE  = 7'b0100011;
  localparam logic [6:0] OP_REG    = 7'b0110011;  
  localparam logic [6:0] OP_IMM    = 7'b0010011;  
  localparam logic [6:0] OP_BRANCH = 7'b1100011;
  localparam logic [6:0] OP_JAL    = 7'b1101111;
  localparam logic [6:0] OP_JALR   = 7'b1100111;
  localparam logic [6:0] OP_LUI    = 7'b0110111;
  localparam logic [6:0] OP_AUIPC  = 7'b0010111;

    localparam logic [2:0] IMM_I = 3'b000;
  localparam logic [2:0] IMM_S = 3'b001;
  localparam logic [2:0] IMM_B = 3'b010;
  localparam logic [2:0] IMM_U = 3'b011;
  localparam logic [2:0] IMM_J = 3'b100;

    localparam logic [1:0] ALUOP_ADD   = 2'b00;  
  localparam logic [1:0] ALUOP_SUB   = 2'b01;  
  localparam logic [1:0] ALUOP_FUNCT = 2'b10;  

  
  localparam logic [3:0] ALU_ADD  = 4'b0000;
  localparam logic [3:0] ALU_SUB  = 4'b1000;
  localparam logic [3:0] ALU_SLL  = 4'b0001;
  localparam logic [3:0] ALU_SLT  = 4'b0010;
  localparam logic [3:0] ALU_SLTU = 4'b0011;
  localparam logic [3:0] ALU_XOR  = 4'b0100;
  localparam logic [3:0] ALU_SRL  = 4'b0101;
  localparam logic [3:0] ALU_SRA  = 4'b1101;
  localparam logic [3:0] ALU_OR   = 4'b0110;
  localparam logic [3:0] ALU_AND  = 4'b0111;
  localparam logic [3:0] ALU_MULX = 4'b1010;  // custom MULX
  localparam logic [2:0] RES_ALU    = 3'b000;  
  localparam logic [2:0] RES_MEM    = 3'b001;  
  localparam logic [2:0] RES_PC4    = 3'b010;  
  localparam logic [2:0] RES_IMM    = 3'b011;  
  localparam logic [2:0] RES_PCTGT  = 3'b100;  

  // 1. Add the RISC-V Custom-0 standard Opcode mapping descriptor
  localparam logic [6:0] OP_CUSTOM0 = 7'b0001011;

  // 2. Add your new control tokens to your existing enums:
  // Assuming ALUOP_ADD=2'b00, ALUOP_SUB=2'b01, ALUOP_FUNCT=2'b10
  localparam logic [1:0] ALUOP_CUSTOM0 = 2'b11; // Uses the free 4th state





  // MULX: the Booth multiplier always computes a*b; the case below
  // only routes its low 32 bits out when alucontrol = ALU_MULX.
  logic [63:0] multiplier_out;
  logic        mul_error;        // residue-check hook, unused for now

  booth_multiplier u_mul (
    .A          (a),
    .B          (b),
    .product    (multiplier_out),
    .error_flag (mul_error)
  );

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
