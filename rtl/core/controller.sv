// Control unit = main decoder + ALU decoder     (row 11/12)
// main_decoder : opcode           -> datapath control signals + aluop
// alu_decoder  : aluop + funct3 + bit 30 -> exact ALU operation

module controller (
  input  logic [6:0] op,          // instr[6:0]
  input  logic [2:0] funct3,      // instr[14:12]
  input  logic       funct7b5,    // instr[30]
  output logic       regwrite,
  output logic [2:0] immsrc,
  output logic       alusrc,
  output logic       memwrite,
  output logic [2:0] resultsrc,
  output logic       branch,
  output logic       jump,
  output logic       jalr,
  output logic [3:0] alucontrol   // final ALU operation code
);

  // Internal wire: carries aluop from the main decoder to the ALU decoder.
  // It is not a port because nothing outside the controller needs it.
  logic [1:0] aluop;

  // Instantiate (place) the main decoder. The syntax is
  //   module_name instance_name ( .port_of_module (signal_here), ... );
  main_decoder u_main_decoder (
    .op        (op),
    .regwrite  (regwrite),
    .immsrc    (immsrc),
    .alusrc    (alusrc),
    .memwrite  (memwrite),
    .resultsrc (resultsrc),
    .branch    (branch),
    .jump      (jump),
    .jalr      (jalr),
    .aluop     (aluop)        // goes to the internal wire above
  );

  // Instantiate the ALU decoder.
  alu_decoder u_alu_decoder (
    .opb5       (op[5]),      // opcode bit 5: 1 for R-type, 0 for I-type ALU
    .funct3     (funct3),
    .funct7b5   (funct7b5),
    .aluop      (aluop),      // from the main decoder
    .alucontrol (alucontrol)
  );

endmodule