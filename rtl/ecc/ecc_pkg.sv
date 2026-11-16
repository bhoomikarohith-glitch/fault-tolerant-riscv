// =============================================================================
// ecc_pkg.sv  -  SECDED encode/decode as functions, usable from any module
// -----------------------------------------------------------------------------
// WHY THIS FILE EXISTS
//   secded_enc.sv and secded_dec.sv are modules: you can only use them by
//   placing an instance and wiring it up. But data_mem needs to encode the
//   initial memory image inside an "initial" block, where you can't place a
//   module, only call a function. A package is like a C header: any module
//   (or testbench) can "import ecc_pkg::*;" and call these functions.
//
//   The maths is the same as secded_enc.sv / secded_dec.sv (same codeword
//   layout), so all of them agree.
// =============================================================================

package ecc_pkg;

  // ----------------------------------------------------- 32 bits -> 39 bits
  function automatic logic [38:0] secded_encode(input logic [31:0] d);
    logic [38:0] cw;
    int          di;
    logic        p;

    cw = '0;
    di = 0;

    // put data bits in the positions that are NOT powers of two
    for (int pos = 1; pos <= 38; pos++) begin
      if ((pos & (pos - 1)) != 0) begin
        cw[pos] = d[di];
        di++;
      end
    end

    // check bit at position 2^k = XOR of data positions with bit k set
    for (int k = 0; k < 6; k++) begin
      p = 1'b0;
      for (int pos = 1; pos <= 38; pos++)
        if (((pos >> k) & 1) && ((pos & (pos - 1)) != 0))
          p = p ^ cw[pos];
      cw[1 << k] = p;
    end

    // overall parity in bit 0
    cw[0] = ^cw[38:1];
    return cw;
  endfunction

  // ------------------------------------------ 39 bits -> corrected 32 bits
  // (used by testbenches to read back what is stored in memory)
  function automatic logic [31:0] secded_decode_data(input logic [38:0] cw);
    logic [5:0]  syn;
    logic        parity;
    logic [38:0] fixed;
    logic [31:0] d;
    int          di;

    syn = '0;
    for (int k = 0; k < 6; k++)
      for (int pos = 1; pos <= 38; pos++)
        if ((pos >> k) & 1)
          syn[k] = syn[k] ^ cw[pos];

    parity = ^cw;
    fixed  = cw;
    if (parity && syn != 6'd0 && syn <= 6'd38)     // single error -> fix it
      fixed = cw ^ (39'd1 << syn);

    d  = '0;
    di = 0;
    for (int pos = 1; pos <= 38; pos++)
      if ((pos & (pos - 1)) != 0) begin
        d[di] = fixed[pos];
        di++;
      end
    return d;
  endfunction

endpackage
