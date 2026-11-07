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

  import rv_pkg::*;

  always_comb begin
    // ---------------------------------------------------------------- 1. defaults
    regwrite  = 1'b0;       
    immsrc    = IMM_I;      
    alusrc    = 1'b0;       
    memwrite  = 1'b0;       
    resultsrc = RES_ALU;    
    branch    = 1'b0;       
    jump      = 1'b0;       
    jalr      = 1'b0;       
    aluop     = ALUOP_ADD;  

    // ------------------------------------------------------- 2. per-opcode changes
    case (op)
      OP_LOAD: begin             
        regwrite  = 1'b1;        
        alusrc    = 1'b1;        
        resultsrc = RES_MEM;     
      end                        

      OP_STORE: begin            
        immsrc    = IMM_S;       
        alusrc    = 1'b1;        
        memwrite  = 1'b1;        
      end

      OP_REG: begin              
        regwrite  = 1'b1;        
        aluop     = ALUOP_FUNCT; 
      end

      OP_IMM: begin              
        regwrite  = 1'b1;        
        alusrc    = 1'b1;        
        aluop     = ALUOP_FUNCT; 
      end

      OP_BRANCH: begin           
        immsrc    = IMM_B;       
        branch    = 1'b1;        
        aluop     = ALUOP_SUB;   
      end                        

      OP_JAL: begin              
        regwrite  = 1'b1;        
        immsrc    = IMM_J;       
        resultsrc = RES_PC4;     
        jump      = 1'b1;        
      end

      OP_JALR: begin             
        regwrite  = 1'b1;        
        alusrc    = 1'b1;        
        resultsrc = RES_PC4;     
        jalr      = 1'b1;        
      end

      OP_LUI: begin              
        regwrite  = 1'b1;
        immsrc    = IMM_U;       
        resultsrc = RES_IMM;     
      end

      OP_AUIPC: begin            
        regwrite  = 1'b1;
        immsrc    = IMM_U;
        resultsrc = RES_PCTGT;   
      end

      // --- ADDED FOR CUSTOM RISC-V HARDWARE MULTIPLIER EXTENSION ---
      OP_CUSTOM0: begin          // MULX rd, rs1, rs2
        regwrite  = 1'b1;        // Write full product low word back to rd
        alusrc    = 1'b0;        // Select rs2 as source operand B
        resultsrc = RES_ALU;    // Write-back source is the ALU calculation path
        aluop     = ALUOP_CUSTOM0; // Direct token lookup command for the ALU decoder
      end

      default: ;                 

    endcase
  end

endmodule
