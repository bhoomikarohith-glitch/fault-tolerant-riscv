//   Turns the main decoder's coarse "aluop" into the exact 4-bit ALU code.
//
//   aluop = 00 -> ADD   (loads, stores, jalr: compute an address)
//   aluop = 01 -> SUB   (branches; unused because branch_comp decides them)
//   aluop = 10 -> look at funct3 and instruction bit 30 (R-type / I-type)
//   aluop = 11 -> ADD   (never produced; safe default)

module alu_decoder (
  input  logic       opb5,        // instr[5]: 1 = R-type, 0 = I-type ALU
  input  logic [2:0] funct3,      // instr[14:12]
  input  logic       funct7b5,    // instr[30]
  input  logic [1:0] aluop,       // class from the main decoder
  output logic [3:0] alucontrol   // code for the ALU
);

  import rv_pkg::*;               // ALU_ADD, ALU_SUB, ALUOP_* ...

  logic sub_or_sra;               // the extra top bit: 1 for SUB or SRA

  always_comb begin

    // ---------------------------------------------- step 1: the extra bit
    case (funct3)

      // funct3 = 000 is add or sub. Bit 30 = 1 means SUB, but ONLY for
      // R-type. In ADDI, bit 30 is part of the immediate, so a negative
      // immediate (e.g. addi x7, x3, -9) has bit 30 = 1. Checking opb5
      // (R-type only) stops ADDI being decoded as a subtract.
      3'b000:  sub_or_sra = opb5 & funct7b5;

      // funct3 = 101 is a right shift. Bit 30 = 1 means arithmetic (SRA),
      // and this is true for BOTH sra (R-type) and srai (I-type), so no
      // opb5 check here.
      3'b101:  sub_or_sra = funct7b5;

      // All other operations have no second variant.
      default: sub_or_sra = 1'b0;

    endcase

    // ---------------------------------------------- step 2: the final code
    case (aluop)
      ALUOP_ADD:   alucontrol = ALU_ADD;               // address calculation
      ALUOP_SUB:   alucontrol = ALU_SUB;               // branches (unused)
      ALUOP_FUNCT: alucontrol = {sub_or_sra, funct3};  // {} joins the bits
      default:     alucontrol = ALU_ADD;               // aluop 11: safe default
    endcase

  end

endmodule

// -----------------------------------------------------------------------------
// EXAMPLES (aluop = 10)
//   add  : funct3 000, R-type, bit30 0 -> {0,000} = 0000 ADD
//   sub  : funct3 000, R-type, bit30 1 -> {1,000} = 1000 SUB
//   addi -9 : funct3 000, I-type, bit30 1 -> {0,000} = 0000 ADD  (not SUB!)
//   srai : funct3 101, bit30 1         -> {1,101} = 1101 SRA
//   xor  : funct3 100                  -> {0,100} = 0100 XOR
// -----------------------------------------------------------------------------