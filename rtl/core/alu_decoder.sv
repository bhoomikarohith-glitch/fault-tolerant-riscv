
module alu_decoder (
  input  logic       opb5,        // instr[5]: 1 = R-type, 0 = I-type ALU
  input  logic [2:0] funct3,      // instr[14:12]
  input  logic       funct7b5,    // instr[30] (only for R-type - to distinguish in between diff R-types w diff funct3)
  input  logic [1:0] aluop,       // class from the main decoder
  output logic [3:0] alucontrol   // code for the ALU
);

  import rv_pkg::*;               // ALU_ADD, ALU_SUB, ALUOP_* ...

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


