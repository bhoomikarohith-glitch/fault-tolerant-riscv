module alu_decoder (
  input  logic       opb5,
  input  logic [2:0] funct3,
  input  logic       funct7b5,
  input  logic       funct7b0,    // instr[25]
  input  logic [1:0] aluop,
  output logic [3:0] alucontrol
);

  import rv_pkg::*;

  logic RtypeSub, RtypeMul;
  assign RtypeSub = funct7b5 & opb5;
  assign RtypeMul = funct7b0 & opb5;   // opb5 gate: for I-types, instr[25] is immediate data

  always_comb begin
    case (aluop)
      ALUOP_ADD:     alucontrol = ALU_ADD;
      ALUOP_SUB:     alucontrol = ALU_SUB;
      ALUOP_CUSTOM0: alucontrol = ALU_MULX;

            default:
        if (RtypeMul && funct3 == 3'b000)
          alucontrol = ALU_MULX;
        else case (funct3)
          3'b000: alucontrol = RtypeSub ? ALU_SUB : ALU_ADD;
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