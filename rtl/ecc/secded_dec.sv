// =============================================================================
// secded_dec.sv  -  (39,32) SECDED Hamming decoder
// Pairs with secded_enc.sv (same codeword layout).
// -----------------------------------------------------------------------------
// WHAT IT DOES
//   Takes a 39-bit codeword that may have flipped bits and gives back the
//   32-bit data, plus two flags:
//     single_err = 1  one bit was wrong and has been CORRECTED (data is good)
//     double_err = 1  two bits were wrong: DETECTED, but data is not trusted
//
// HOW (recompute the checks, then read the answer off them)
//   syndrome[k] = XOR of every position 1..38 whose number has bit k set,
//                 INCLUDING the stored check bit at position 2^k.
//                 With no error every check comes out 0.
//   parity      = XOR of all 39 bits. With no error it is 0 (the encoder
//                 made the number of 1s even).
//
//   syndrome  parity   meaning
//   --------  ------   ----------------------------------------------------
//      0        0      no error
//      0        1      single error in bit 0 (the parity bit itself)
//     != 0      1      single error at position = syndrome -> flip it back
//     != 0      0      double error (parity is even again, checks still fail)
//   A nonzero syndrome above 38 with odd parity cannot come from one flip,
//   so it is reported as double_err (uncorrectable) too.
//
// TYPE: purely combinational.
// =============================================================================

module secded_dec (
  input  logic [38:0] codeword,     // possibly corrupted codeword
  output logic [31:0] data,         // corrected data
  output logic        single_err,   // one error found and corrected
  output logic        double_err,   // two errors found (uncorrectable)
  output logic [5:0]  syndrome      // which position failed (for debug)
);

  // ---------------------------------------------- step 1: the 6 checks
  // A function keeps the running XOR in its own local variable, so the
  // hardware is a clean XOR tree with no feedback.
  function automatic logic [5:0] calc_syndrome(input logic [38:0] cw);
    logic [5:0] s;
    s = '0;
    for (int k = 0; k < 6; k++)
      for (int pos = 1; pos <= 38; pos++)
        if ((pos >> k) & 1)
          s[k] = s[k] ^ cw[pos];
    return s;
  endfunction

  // ---------------------------------------------- step 4 helper: data out
  // Same order the encoder used: data bits sit at the positions that are
  // not powers of two (3, 5, 6, 7, 9, ...).
  function automatic logic [31:0] extract(input logic [38:0] cw);
    logic [31:0] d;
    int          di;
    d  = '0;
    di = 0;
    for (int pos = 1; pos <= 38; pos++)
      if ((pos & (pos - 1)) != 0) begin
        d[di] = cw[pos];
        di++;
      end
    return d;
  endfunction

  logic        parity;              // overall parity of the received word
  logic [38:0] flip;                // one-hot: which bit to correct
  logic [38:0] fixed;               // codeword after correction

  assign syndrome = calc_syndrome(codeword);
  assign parity   = ^codeword;      // reduction XOR of all 39 bits

  // ---------------------------------------------- step 2: classify
  assign single_err = parity && (syndrome <= 6'd38);
  assign double_err = (!parity && syndrome != 6'd0) || (parity && syndrome > 6'd38);

  // ---------------------------------------------- step 3: correct
  // Flip the bit the syndrome points at. Syndrome 0 with odd parity means
  // bit 0 (the parity bit) was hit, which holds no data, so nothing to fix.
  assign flip  = (single_err && syndrome != 6'd0) ? (39'd1 << syndrome) : 39'd0;
  assign fixed = codeword ^ flip;

  // ---------------------------------------------- step 4: pull data out
  assign data = extract(fixed);

endmodule
