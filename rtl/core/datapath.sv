//   Wires every datapath block together. 
//   FETCH    pc_reg -> (pc goes out to instruction memory)
//   DECODE   register_file reads rs1/rs2; extend builds the immediate
//   EXECUTE  mux2 picks ALU operand B; alu computes; branch_comp compares
//   MEMORY   (aluresult / writedata go out to data memory)
//   WRITE    result_mux picks the value written back into rd
//   NEXT     next_pc picks the next PC, which pc_reg loads at the clock edge


module datapath (
  input  logic        clk,
  input  logic        reset,
  // ---- control signals (from controller.sv)
  input  logic        regwrite,     // write rd this cycle?
  input  logic [2:0]  immsrc,       // immediate format
  input  logic        alusrc,       // ALU operand B: rs2 (0) or immediate (1)
  input  logic [2:0]  resultsrc,    // what to write back
  input  logic        branch,
  input  logic        jump,
  input  logic        jalr,
  input  logic [3:0]  alucontrol,   // ALU operation
  // ---- instruction memory port
  output logic [31:0] pc,           // address of the current instruction
  input  logic [31:0] instr,        // the instruction at that address
  // ---- data memory port
  output logic [31:0] aluresult,    // ALU result; also the data memory address
  output logic [31:0] writedata,    // rs2 value, stored by sb/sh/sw
  input  logic [31:0] readdata      // data loaded from memory
);

  // Internal wires connecting the blocks below.
  logic [31:0] pcnext;      // next PC, from next_pc to pc_reg
  logic [31:0] pcplus4;     // pc + 4
  logic [31:0] pctarget;    // pc + immediate
  logic [31:0] immext;      // extended immediate
  logic [31:0] srca;        // ALU operand A = rs1 value
  logic [31:0] srcb;        // ALU operand B = rs2 value or immediate
  logic [31:0] result;      // value written back to rd
  logic        branchtaken; // branch condition true?

  // ================================================================== FETCH
  pc_reg u_pc_reg (
    .clk    (clk),
    .reset  (reset),
    .en     (1'b1),         // single-cycle: the PC updates every cycle
    .pcnext (pcnext),
    .pc     (pc)
  );

  next_pc u_next_pc (
    .pc          (pc),
    .immext      (immext),
    .aluresult   (aluresult),   // jalr target = rs1 + imm, computed by ALU
    .branch      (branch),
    .jump        (jump),
    .jalr        (jalr),
    .branchtaken (branchtaken),
    .pcnext      (pcnext),
    .pcplus4     (pcplus4),
    .pctarget    (pctarget)
  );

  // ================================================================= DECODE
  // Register fields are always in the same bit positions in RISC-V:
  //   rs1 = instr[19:15], rs2 = instr[24:20], rd = instr[11:7]
  //
 
  register_file u_register_file (
    .clk (clk),
    .rst (reset),
    .reg_write (regwrite),        // write enable
    .rs1  (instr[19:15]),    // read address 1 = rs1
    .rs2  (instr[24:20]),    // read address 2 = rs2
    .rd  (instr[11:7]),     // write address  = rd
    .write_data (result),          // write data     = output of the result mux
    .rd1 (srca),            // rs1 value -> ALU operand A, branch_comp
    .rd2 (writedata)        // rs2 value -> operand B mux, branch_comp, store data
  );

  // Bhoomika's immediate generator (module "extend").
  extend u_extend (
    .instr  (instr),
    .immsrc (immsrc),
    .immext (immext)
  );

  // ================================================================ EXECUTE
  // ALU operand B: register rs2 (R-type, branches) or immediate (everything
  // with an immediate: addi, loads, stores, jalr).
  mux2 #(.WIDTH(32)) u_srcb_mux (
    .d0  (writedata),       // rs2
    .d1  (immext),          // immediate
    .sel (alusrc),
    .y   (srcb)
  );

  alu u_alu (
    .a          (srca),
    .b          (srcb),
    .alucontrol (alucontrol),
    .result     (aluresult)
  );

  branch_comp u_branch_comp (
    .rd1         (srca),          // rs1
    .rd2         (writedata),     // rs2 (always the register, never the immediate)
    .funct3      (instr[14:12]),  // which comparison
    .branchtaken (branchtaken)
  );

  // ============================================================= WRITE-BACK
  result_mux u_result_mux (
    .resultsrc (resultsrc),
    .aluresult (aluresult),
    .readdata  (readdata),
    .pcplus4   (pcplus4),
    .immext    (immext),
    .pctarget  (pctarget),
    .result    (result)          // goes back to the register file's wd3
  );

endmodule