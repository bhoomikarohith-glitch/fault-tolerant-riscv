// =============================================================================
// ecc_top.sv  -  ECC loopback: encoder -> fault injection -> decoder
// -----------------------------------------------------------------------------
// WHAT IT DOES
//   Models one word going into memory and coming back out:
//     1. secded_enc turns data_in into a 39-bit codeword ("write to memory")
//     2. flip_mask flips chosen codeword bits ("radiation hits memory");
//        every 1 in flip_mask flips that bit, all zeros = no fault
//     3. secded_dec checks and repairs the word ("read from memory")
//
//   This is the unit the layered testbench drives, and a clean top for a
//   Vivado synthesis schematic of the whole ECC path.
//
// TYPE: purely combinational.
// =============================================================================

module ecc_top (
  input  logic [31:0] data_in,      // word to store
  input  logic [38:0] flip_mask,    // bits to corrupt (fault injection)
  output logic [38:0] codeword,     // encoder output, before corruption
  output logic [31:0] data_out,     // decoder output, after correction
  output logic        single_err,   // decoder corrected one bit
  output logic        double_err,   // decoder found two bad bits
  output logic [5:0]  syndrome      // decoder syndrome (debug)
);

  logic [38:0] corrupted;           // what the "memory" hands back

  secded_enc u_enc (
    .data     (data_in),
    .codeword (codeword)
  );

  assign corrupted = codeword ^ flip_mask;   // XOR with 1 flips a bit

  secded_dec u_dec (
    .codeword   (corrupted),
    .data       (data_out),
    .single_err (single_err),
    .double_err (double_err),
    .syndrome   (syndrome)
  );

endmodule
