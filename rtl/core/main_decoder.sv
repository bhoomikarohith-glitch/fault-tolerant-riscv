module main_decoder (
  input  logic [6:0] op,          // opcode = instr[6:0]
  output logic       regwrite,    // 1 = write a result into register rd
  output logic [2:0] immsrc,      // immediate format for the immediate generator
  output logic       alusrc,      // ALU operand B: 0 = register rs2, 1 = immediate
  output logic       memwrite,    // 1 = store to data memory
  output logic [2:0] resultsrc,   // which value is written back to rd
  output logic       branch,      // 1 = conditional branch (beq, bne, ...)
  output logic       jump,        // 1 = JAL
  output logic       jalr,        // 1 = JALR
  output logic [1:0] aluop        // operation class, sent to the ALU decoder
);

  // Bring in the named constants (OP_LOAD, IMM_S, RES_MEM, ALUOP_FUNCT ...)
  // from the shared package, so the codes are defined in one place only.
  import rv_pkg::*;

  always_comb begin

    // ---------------------------------------------------------------- 1. defaults
    // Every output gets a value first. This guarantees every output is
    // assigned on every path (no latches) and makes unknown opcodes harmless.
    regwrite  = 1'b0;       // don't write a register
    immsrc    = IMM_I;      // any format; unused when no immediate is needed
    alusrc    = 1'b0;       // ALU operand B = rs2
    memwrite  = 1'b0;       // don't write memory
    resultsrc = RES_ALU;    // write-back value = ALU result (unused if regwrite = 0)
    branch    = 1'b0;       // not a branch
    jump      = 1'b0;       // not JAL
    jalr      = 1'b0;       // not JALR
    aluop     = ALUOP_ADD;  // ALU adds (harmless default)

    // ------------------------------------------------------- 2. per-opcode changes
    case (op)

      OP_LOAD: begin             // lb/lh/lw/lbu/lhu: rd = mem[rs1 + imm]
        regwrite  = 1'b1;        //   result goes into rd
        alusrc    = 1'b1;        //   ALU computes rs1 + immediate (the address)
        resultsrc = RES_MEM;     //   write back the data read from memory
      end                        //   (immsrc I and aluop ADD come from defaults)

      OP_STORE: begin            // sb/sh/sw: mem[rs1 + imm] = rs2
        immsrc    = IMM_S;       //   store immediate is split across two fields
        alusrc    = 1'b1;        //   ALU computes the address rs1 + immediate
        memwrite  = 1'b1;        //   write memory; regwrite stays 0
      end

      OP_REG: begin              // add/sub/and/or/xor/sll/srl/sra/slt/sltu
        regwrite  = 1'b1;        //   rd = rs1 op rs2 (alusrc stays 0 = rs2)
        aluop     = ALUOP_FUNCT; //   ALU decoder picks the op from funct3/bit 30
      end

      OP_IMM: begin              // addi/andi/ori/xori/slti/sltiu/slli/srli/srai
        regwrite  = 1'b1;        //   rd = rs1 op immediate
        alusrc    = 1'b1;        //   operand B = immediate
        aluop     = ALUOP_FUNCT; //   ALU decoder picks the op
      end

      OP_BRANCH: begin           // beq/bne/blt/bge/bltu/bgeu
        immsrc    = IMM_B;       //   branch offset format
        branch    = 1'b1;        //   next_pc uses branch_comp's answer
        aluop     = ALUOP_SUB;   //   kept for textbook compatibility (unused)
      end                        //   nothing is written to rd or memory

      OP_JAL: begin              // jal: rd = pc + 4; pc = pc + offset
        regwrite  = 1'b1;        //   save the return address
        immsrc    = IMM_J;       //   jump offset format
        resultsrc = RES_PC4;     //   write back pc + 4
        jump      = 1'b1;        //   next_pc jumps to pc + offset
      end

      OP_JALR: begin             // jalr: rd = pc + 4; pc = (rs1 + imm) & ~1
        regwrite  = 1'b1;        //   save the return address
        alusrc    = 1'b1;        //   ALU computes rs1 + immediate = target
        resultsrc = RES_PC4;     //   write back pc + 4
        jalr      = 1'b1;        //   next_pc takes the ALU result, clears bit 0
      end

      OP_LUI: begin              // lui: rd = imm << 12
        regwrite  = 1'b1;
        immsrc    = IMM_U;       //   upper-immediate format (low 12 bits = 0)
        resultsrc = RES_IMM;     //   write the immediate itself
      end

      OP_AUIPC: begin            // auipc: rd = pc + (imm << 12)
        regwrite  = 1'b1;
        immsrc    = IMM_U;
        resultsrc = RES_PCTGT;   //   write pc + immediate (computed by next_pc)
      end

      default: ;                 // anything else: keep the no-op defaults

    endcase
  end

endmodule