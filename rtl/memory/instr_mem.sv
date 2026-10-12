
module instr_mem #(
  parameter int DEPTH     = 1024,           // words (1024 = 4 KB)
  parameter int WIDTH     = 32,
  parameter     INIT_FILE = "program.mem"   // one hex word per line
) (
  input  logic [31:0]      a,
  output logic [WIDTH-1:0] rd
);

  localparam int AW = $clog2(DEPTH);

  logic [WIDTH-1:0] mem [0:DEPTH-1];
  logic [29:0]      word_idx;

  assign word_idx = a[31:2];

  initial begin
    for (int i = 0; i < DEPTH; i++) mem[i] = '0;
    if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
  end

  always_comb begin
    if (word_idx < DEPTH) rd = mem[word_idx[AW-1:0]];
    else                  rd = '0;
  end

endmodule
