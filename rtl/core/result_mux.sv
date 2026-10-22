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

  import rv_pkg::*;               // RES_ALU, RES_MEM, RES_PC4, RES_IMM, RES_PCTGT

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