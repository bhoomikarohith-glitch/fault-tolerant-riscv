// =============================================================================
// data_mem.sv  -  ECC-protected data memory, byte / halfword / word access
// Spec: docs/risc-v-core/data_mem.md
// -----------------------------------------------------------------------------
// WHAT IT DOES
//   Holds the program's data. Supports every RV32I load and store:
//     loads : lb, lh, lw, lbu, lhu   (read is combinational, same cycle)
//     stores: sb, sh, sw             (write happens on the rising clock edge)
//
//   Every word is stored as a 39-bit SECDED codeword (32 data + 7 check bits):
//     store -> secded_enc turns the 32-bit word into 39 bits, all 39 stored
//     load  -> secded_dec checks the 39 bits, fixes a single flipped bit,
//              and only the CORRECTED 32 bits reach the core
//   The core never knows ECC is there: same ports, same behaviour.
//
// HOW AN ADDRESS IS USED
//   a[31:2] -> which word (address / 4),  a[1:0] -> which byte inside it.
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

  import ecc_pkg::*;                // secded_encode() for the initial contents

  localparam int AW = $clog2(DEPTH);   // 1024 words -> 10 address bits

  // ---------------------------------------------------------------- storage
  // NEW: each entry is a 39-bit codeword instead of a plain 32-bit word.
  logic [38:0] mem [0:DEPTH-1];

  // NEW: the init file holds plain 32-bit words, so load it here first.
  logic [31:0] init_words [0:DEPTH-1];

  logic [29:0] word_idx;   // which word: address bits 31..2
  logic        in_range;   // 1 if that word exists in this memory
  logic [38:0] raw;        // NEW: the 39 bits stored there (maybe corrupted)
  logic [31:0] word;       // the CORRECTED 32-bit word (decoder output)
  logic [7:0]  rbyte;      // the selected byte (for lb / lbu)
  logic [15:0] rhalf;      // the selected halfword (for lh / lhu)
  logic [3:0]  byte_en;    // which of the 4 bytes a store changes
  logic [31:0] wd_lanes;   // store data copied into the right byte lanes
  logic [31:0] merged;     // NEW: old word with the new bytes dropped in
  logic [38:0] new_cw;     // NEW: merged, encoded -> what gets written

  // ------------------------------------------------------- initial contents
  // CHANGED: read the plain words, then encode each one into mem. Loading the
  // file straight into mem would leave the check bits wrong, and the first
  // load would "find an error" in perfectly good data.
  initial begin
    for (int i = 0; i < DEPTH; i++) init_words[i] = 32'b0;
    if (INIT_FILE != "") $readmemh(INIT_FILE, init_words);
    for (int i = 0; i < DEPTH; i++) mem[i] = secded_encode(init_words[i]);
  end

  // ------------------------------------------------------------ addressing
  assign word_idx = a[31:2];
  assign in_range = (word_idx < DEPTH);
  // CHANGED: read the 39-bit codeword. Past the end -> all zeros, which is
  // the valid codeword for data 0, so out-of-range loads still return 0.
  assign raw = in_range ? mem[word_idx[AW-1:0]] : 39'b0;

  // NEW: decode. "word" now comes out of the decoder, already corrected, so
  // everything below that uses "word" automatically gets the fixed data.
  secded_dec u_dec (
    .codeword   (raw),
    .data       (word),
    .single_err (),          // not used yet (next step: error flags)
    .double_err (),
    .syndrome   ()
  );

  // ------------------------------------------------------------------ loads
  // UNCHANGED: these already read from "word".
  assign rbyte = word[8*a[1:0] +: 8];
  assign rhalf = a[1] ? word[31:16] : word[15:0];

  always_comb begin
    case (funct3)
      3'b000:  rd = {{24{rbyte[7]}}, rbyte};   // LB : signed byte
      3'b001:  rd = {{16{rhalf[15]}}, rhalf};  // LH : signed halfword
      3'b100:  rd = {24'b0, rbyte};            // LBU: zero-extended byte
      3'b101:  rd = {16'b0, rhalf};            // LHU: zero-extended halfword
      default: rd = word;                      // LW : the whole word
    endcase
  end

  // ----------------------------------------------------------------- stores
  // UNCHANGED: which bytes the store changes, and the data lined up.
  always_comb begin
    case (funct3[1:0])
      2'b00: begin                          // SB: one byte
        byte_en  = 4'b0001 << a[1:0];
        wd_lanes = {4{wd[7:0]}};
      end
      2'b01: begin                          // SH: two bytes
        byte_en  = a[1] ? 4'b1100 : 4'b0011;
        wd_lanes = {2{wd[15:0]}};
      end
      default: begin                        // SW: all four bytes
        byte_en  = 4'b1111;
        wd_lanes = wd;
      end
    endcase
  end

  // NEW: read-modify-write. Check bits cover the WHOLE word, so we can't
  // just overwrite one byte any more. Build the complete new 32-bit word:
  // new bytes where the store writes, old (corrected) bytes everywhere else.
  // For sw, byte_en = 1111, so merged is simply wd.
  always_comb begin
    for (int i = 0; i < 4; i++)
      merged[8*i +: 8] = byte_en[i] ? wd_lanes[8*i +: 8] : word[8*i +: 8];
  end

  // NEW: encode the merged word.
  secded_enc u_enc (
    .data     (merged),
    .codeword (new_cw)
  );

  // CHANGED: always write all 39 bits (the old version wrote single bytes).
  always_ff @(posedge clk) begin
    if (we && in_range)
      mem[word_idx[AW-1:0]] <= new_cw;
  end

endmodule
