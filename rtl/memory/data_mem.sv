// =============================================================================
// data_mem.sv  -  Data memory with byte / halfword / word access    (row 13)
// Spec: docs/risc-v-core/data_mem.md
// -----------------------------------------------------------------------------
// WHAT IT DOES
//   Holds the program's data. Supports every RV32I load and store:
//     loads : lb, lh, lw, lbu, lhu   (read is combinational, same cycle)
//     stores: sb, sh, sw             (write happens on the rising clock edge)
//
// HOW AN ADDRESS IS USED
//   Memory is stored as 32-bit words. A byte address is split in two:
//     a[31:2] -> which word        (address / 4)
//     a[1:0]  -> which byte inside that word
//   Little-endian: byte 0 is the least significant byte of the word.
//
// funct3 (from the instruction) gives the size and sign:
//   000 = byte, 001 = halfword, 010 = word; bit 2 set = unsigned (lbu, lhu)
// =============================================================================

module data_mem #(
  parameter int DEPTH     = 1024,   // number of 32-bit words (1024 = 4 KB)
  parameter     INIT_FILE = ""      // optional file with starting contents
) (
  input  logic        clk,          // clock: stores happen on its rising edge
  input  logic        we,           // write enable = memwrite from the decoder
  input  logic [2:0]  funct3,       // access size and sign (instr[14:12])
  input  logic [31:0] a,            // byte address (from the ALU)
  input  logic [31:0] wd,           // store data (register rs2)
  output logic [31:0] rd            // load data, already extended to 32 bits
);

  // Number of address bits needed to pick one of DEPTH words.
  // $clog2(1024) = 10. localparam = a constant fixed inside this module.
  localparam int AW = $clog2(DEPTH);

  // ---------------------------------------------------------------- storage
  // mem is an array of DEPTH entries, each 32 bits wide.
  logic [31:0] mem [0:DEPTH-1];

  // Internal signals (wires) used below.
  logic [29:0] word_idx;   // which word: address bits 31..2
  logic        in_range;   // 1 if that word exists in this memory
  logic [31:0] word;       // the whole 32-bit word at that address
  logic [7:0]  rbyte;      // the selected byte (for lb / lbu)
  logic [15:0] rhalf;      // the selected halfword (for lh / lhu)
  logic [3:0]  byte_en;    // which of the 4 bytes a store may change
  logic [31:0] wd_lanes;   // store data copied into the right byte lanes

  // ------------------------------------------------------- initial contents
  // initial blocks run once at start-up. This one is only allowed because it
  // sets a memory's starting contents (simulation and FPGA both support it).
  initial begin
    for (int i = 0; i < DEPTH; i++) mem[i] = 32'b0;   // clear everything
    if (INIT_FILE != "") $readmemh(INIT_FILE, mem);    // then load the file
  end

  // ------------------------------------------------------------ addressing
  assign word_idx = a[31:2];                 // byte address / 4
  assign in_range = (word_idx < DEPTH);      // past the end?
  // ?: is "if-else" for wires: condition ? value_if_true : value_if_false.
  // Reading past the end gives 0 instead of an undefined value.
  assign word     = in_range ? mem[word_idx[AW-1:0]] : 32'b0;

  // ------------------------------------------------------------------ loads
  // Pick one byte: a[1:0] = 0,1,2,3 selects bits [7:0], [15:8], [23:16],
  // [31:24]. "+: 8" means "8 bits starting at this position".
  assign rbyte = word[8*a[1:0] +: 8];
  // Pick one halfword: a[1] = 0 -> lower half, 1 -> upper half.
  assign rhalf = a[1] ? word[31:16] : word[15:0];

  always_comb begin
    case (funct3)
      // {24{rbyte[7]}} = 24 copies of the byte's top bit = SIGN EXTENSION,
      // so 0xF0 becomes 0xFFFFFFF0 (-16).
      3'b000:  rd = {{24{rbyte[7]}}, rbyte};   // LB : signed byte
      3'b001:  rd = {{16{rhalf[15]}}, rhalf};  // LH : signed halfword
      3'b100:  rd = {24'b0, rbyte};            // LBU: zero-extended byte
      3'b101:  rd = {16'b0, rhalf};            // LHU: zero-extended halfword
      default: rd = word;                      // LW : the whole word
    endcase
  end

  // ----------------------------------------------------------------- stores
  // Work out which bytes to change, and line the data up with them.
  // Only funct3[1:0] matters for stores: 00 sb, 01 sh, 10 sw.
  always_comb begin
    case (funct3[1:0])

      2'b00: begin                          // SB: one byte
        byte_en  = 4'b0001 << a[1:0];       //   e.g. a[1:0] = 2 -> 0100
        wd_lanes = {4{wd[7:0]}};            //   byte copied into all 4 lanes
      end

      2'b01: begin                          // SH: two bytes
        byte_en  = a[1] ? 4'b1100 : 4'b0011;//   upper or lower half
        wd_lanes = {2{wd[15:0]}};           //   halfword copied into both halves
      end

      default: begin                        // SW: all four bytes
        byte_en  = 4'b1111;
        wd_lanes = wd;
      end

    endcase
  end
  // Copying the data into every lane means whichever lane is enabled already
  // holds the right value. Real memories with byte-write enables work this way.

  // always_ff = clocked logic: runs only on the rising edge of clk.
  // <= (non-blocking) is used for registers/memories so every write in the
  // design happens together at the clock edge.
  always_ff @(posedge clk) begin
    if (we && in_range) begin                   // a store to a valid address
      for (int i = 0; i < 4; i++) begin         // look at each of the 4 bytes
        if (byte_en[i])                         // only enabled bytes change
          mem[word_idx[AW-1:0]][8*i +: 8] <= wd_lanes[8*i +: 8];
      end
    end
  end

endmodule