//   Chooses which value gets written into the destination register rd.

//   resultsrc  value written to rd        used by
//   000        ALU result                 R-type, I-type ALU
//   001        data memory read data      loads
//   010        PC + 4 (return address)    jal, jalr
//   011        U-type immediate           lui
//   100        PC + immediate             auipc

module result_mux (
  input  logic [2:0]  resultsrc,  // select, from the main decoder
  input  logic [31:0] aluresult,  // from the ALU
  input  logic [31:0] readdata,   // from data memory
  input  logic [31:0] pcplus4,    // from next_pc
  input  logic [31:0] immext,     // from the immediate generator (extend)
  input  logic [31:0] pctarget,   // from next_pc (PC + immediate)
  output logic [31:0] result      // to the register file's write data
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



               // RES_ALU, RES_MEM, RES_PC4, RES_IMM, RES_PCTGT

  always_comb begin
    case (resultsrc)
      RES_ALU:   result = aluresult;
      RES_MEM:   result = readdata;
      RES_PC4:   result = pcplus4;
      RES_IMM:   result = immext;
      RES_PCTGT: result = pctarget;
      default:   result = 32'b0;   // unused codes: defined value, no latch
    endcase
  end

endmodule