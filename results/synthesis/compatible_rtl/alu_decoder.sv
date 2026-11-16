
module alu_decoder (
  input  logic       opb5,        // instr[5]: 1 = R-type, 0 = I-type ALU
  input  logic [2:0] funct3,      // instr[14:12]
  input  logic       funct7b5,    // instr[30] (only for R-type - to distinguish in between diff R-types w diff funct3)
  input  logic [1:0] aluop,       // class from the main decoder
  output logic [3:0] alucontrol   // code for the ALU
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



               // ALU_ADD, ALU_SUB, ALUOP_* ...

  logic RtypeSub;    
  assign RtypeSub = funct7b5 & opb5; // TRUE for Rtype subtract

  always_comb begin

    // ---------------------------------------------- step 1: the extra bit
    case (aluop)

      ALUOP_ADD: alucontrol = ALU_ADD;
      ALUOP_SUB: alucontrol = ALU_SUB;

      // --- INTERCEPT CUSTOM MULTIPLIER INSTRUCTION ---
      ALUOP_CUSTOM0: alucontrol = ALU_MULX; 
      
      default: case(funct3)
        3'b000: if(RtypeSub)
                  alucontrol = ALU_SUB; //sub
                else 
                  alucontrol = ALU_ADD;  //add, addi
        3'b001: alucontrol = ALU_SLL; 
        3'b010: alucontrol = ALU_SLT; 
        3'b011: alucontrol = ALU_SLTU;
        3'b100: alucontrol = ALU_XOR; 
        3'b101: alucontrol = funct7b5 ? ALU_SRA : ALU_SRL;
        3'b110: alucontrol = ALU_OR;
        3'b111: alucontrol = ALU_AND; 
      endcase
    endcase
  end
endmodule


