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
