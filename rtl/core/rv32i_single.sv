module rv32i_single (
  input  logic        clk,
  input  logic        reset,
  // ---- instruction memory port
  output logic [31:0] pc,          // address to fetch
  input  logic [31:0] instr,       // instruction fetched
  // ---- data memory port
  output logic        memwrite,    // 1 = store this cycle
  output logic [2:0]  memfunct3,   // size/sign of the load or store
  output logic [31:0] aluresult,   // memory address
  output logic [31:0] writedata,   // store data
  input  logic [31:0] readdata     // load data
);

  // Wires carrying control signals from the controller to the datapath.
  logic       regwrite, alusrc, branch, jump, jalr;
  logic [2:0] immsrc, resultsrc;
  logic [3:0] alucontrol;

  // Data memory needs funct3 to know byte / halfword / word and signed or not.
  assign memfunct3 = instr[14:12];

  controller u_controller (
    .op         (instr[6:0]),      // opcode
    .funct3     (instr[14:12]),
    .funct7b5   (instr[30]),       // distinguishes add/sub and srl/sra
    .regwrite   (regwrite),
    .immsrc     (immsrc),
    .alusrc     (alusrc),
    .memwrite   (memwrite),        // goes straight out to data memory
    .resultsrc  (resultsrc),
    .branch     (branch),
    .jump       (jump),
    .jalr       (jalr),
    .alucontrol (alucontrol)
  );

  datapath u_datapath (
    .clk        (clk),
    .reset      (reset),
    .regwrite   (regwrite),
    .immsrc     (immsrc),
    .alusrc     (alusrc),
    .resultsrc  (resultsrc),
    .branch     (branch),
    .jump       (jump),
    .jalr       (jalr),
    .alucontrol (alucontrol),
    .pc         (pc),
    .instr      (instr),
    .aluresult  (aluresult),
    .writedata  (writedata),
    .readdata   (readdata)
  );

endmodule