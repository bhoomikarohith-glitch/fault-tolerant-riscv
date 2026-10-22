//     pcplus4  = pc + 4         next sequential instruction; also the return
//                               address that jal/jalr save in rd
//     pctarget = pc + immediate target of a branch or jal; also auipc's result
//
//   Choice of next PC, highest priority first:
//     1. jalr                 -> (rs1 + imm) with bit 0 cleared
//     2. jal                  -> pctarget
//     3. branch AND taken     -> pctarget
//     4. otherwise            -> pcplus4
//
// TYPE: purely combinational. The PC itself is stored in pc_reg.sv, which
//   loads pcnext at the next rising clock edge.


module next_pc (
  input  logic [31:0] pc,           // current PC (from pc_reg)
  input  logic [31:0] immext,       // immediate (B-type, J-type or U-type)
  input  logic [31:0] aluresult,    // ALU output = rs1 + imm for jalr
  input  logic        branch,       // from main decoder
  input  logic        jump,         // from main decoder (jal)
  input  logic        jalr,         // from main decoder
  input  logic        branchtaken,  // from branch_comp
  output logic [31:0] pcnext,       // to pc_reg
  output logic [31:0] pcplus4,      // to the result mux (link address)
  output logic [31:0] pctarget      // to the result mux (auipc)
);

  // Adder 1: pc + 4. Every instruction is 4 bytes, so this is the next one.
  adder #(.WIDTH(32)) u_add_pc4 (   // #(.WIDTH(32)) sets the adder's parameter
    .a   (pc),
    .b   (32'd4),                   // 32'd4 = the number 4, 32 bits wide
    .sum (pcplus4)
  );

  // Adder 2: pc + immediate. The immediate is already sign-extended, so a
  // negative offset (a backward branch, e.g. a loop) simply subtracts.
  adder #(.WIDTH(32)) u_add_target (
    .a   (pc),
    .b   (immext),
    .sum (pctarget)
  );

  // The selection. An if / else-if chain in always_comb gives a priority
  // order: the first true condition wins.
  always_comb begin
    if (jalr)
      // RISC-V says the jalr target's bit 0 must be cleared:
      // keep bits 31..1, put 0 in bit 0.
      pcnext = {aluresult[31:1], 1'b0};
    else if (jump)
      pcnext = pctarget;                 // jal: always jumps
    else if (branch && branchtaken)
      pcnext = pctarget;                 // branch whose condition is true
    else
      pcnext = pcplus4;                  // normal case: next instruction
  end
  // branchtaken is ignored unless branch = 1, because branch_comp produces
  // an answer for every instruction, not just branches.

endmodule