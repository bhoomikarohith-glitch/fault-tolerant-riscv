//   Turns the main decoder's coarse "aluop" into the exact 4-bit ALU code.
//
//   aluop = 00 -> ADD   (loads, stores, jalr: compute an address)
//   aluop = 01 -> SUB   (branches; unused because branch_comp decides them)
//   aluop = 10 -> look at funct3 and instruction bit 30 (R-type / I-type)
//   aluop = 11 -> ADD   (never produced; safe default)

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
    case (ALUOp)

      ALUOP_ADD: alucontrol = ALU_ADD;
      ALUOP_SUB: alucontrol = ALU_SUB;
      default: case(funct3)
        3'b000: if(RtypeSub)
                  alucontrol = ALU_SUB; //sub
                else 
                  alucontrol = ALU_ADD;  //add, addi
        3'b001: alucontrol = ALU_XOR; 
        3'b010: alucontrol = ALU_SLL; //sll, slli 
        3'b011: alucontrol = ALU_SRA;
        3'b100: alucontrol = ALU_SLT; //slt, slti
        3'b101: alucontrol = ALU_SRA;
        3'b110: alucontrol = ALU_OR; //or, ori
        3'b111: alucontrol = ALU_AND; //and, andi
      endcase
    endcase
    
endmodule

// -----------------------------------------------------------------------------
// EXAMPLES (aluop = 10)
//   add  : funct3 000, R-type, bit30 0 -> {0,000} = 0000 ADD
//   sub  : funct3 000, R-type, bit30 1 -> {1,000} = 1000 SUB
//   addi -9 : funct3 000, I-type, bit30 1 -> {0,000} = 0000 ADD  (not SUB!)
//   srai : funct3 101, bit30 1         -> {1,101} = 1101 SRA
//   xor  : funct3 100                  -> {0,100} = 0100 XOR
// -----------------------------------------------------------------------------
