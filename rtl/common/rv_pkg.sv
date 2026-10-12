

package rv_pkg;

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
  localparam logic [2:0] RES_ALU    = 3'b000;  
  localparam logic [2:0] RES_MEM    = 3'b001;  
  localparam logic [2:0] RES_PC4    = 3'b010;  
  localparam logic [2:0] RES_IMM    = 3'b011;  
  localparam logic [2:0] RES_PCTGT  = 3'b100;  

endpackage
