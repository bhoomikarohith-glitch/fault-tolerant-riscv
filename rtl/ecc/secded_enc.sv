// =============================================================================
// secded_enc.sv  -  (39,32) SECDED Hamming encoder                   (row 25)
// Spec: docs/risc-v-core/secded_enc.md
// -----------------------------------------------------------------------------
// WHAT IT DOES
//   Takes a 32-bit word and adds 7 check bits, making a 39-bit "codeword".
//   Later, the decoder uses those bits to
//     - CORRECT any single flipped bit (Single Error Correct), and
//     - DETECT any two flipped bits (Double Error Detect)  -> "SECDED".
//   This protects memory against radiation-induced bit flips.
//
// CODEWORD LAYOUT (39 bits)
//   codeword[0]        overall parity: XOR of bits 1..38, so the whole
//                      codeword always has an even number of 1s
//   codeword[1..38]    "Hamming positions" 1..38:
//     positions that are powers of two (1, 2, 4, 8, 16, 32) hold the
//     6 check bits p0..p5
//     the other 32 positions (3, 5, 6, 7, 9, ... 38) hold data[0..31] in order
//
// THE IDEA IN ONE SENTENCE
//   Check bit p_k covers every position whose position number has bit k set.
//   If one bit flips, exactly the checks covering it fail, and the failing
//   checks, read as a binary number, ARE that bit's position.
//
//   Example: position 6 = binary 110 is covered by p1 (bit 1) and p2 (bit 2).
//   If position 6 flips, p1 and p2 fail -> syndrome 110 = 6 -> flip bit 6 back.
//
//   The extra overall parity bit tells one error (parity odd) from two errors
//   (parity even again, but syndrome nonzero).
//
// TYPE: purely combinational. Cost: 7 extra bits per 32 = 21.9% more memory.
// =============================================================================

module secded_enc (
  input  logic [31:0] data,       // word to protect
  output logic [38:0] codeword    // data + 7 check bits
);

  // A function computes a value from its inputs, like in C. "automatic"
  // gives each call its own local variables. Loops with fixed bounds like
  // these are unrolled by synthesis into plain XOR gates; nothing loops in
  // the real hardware.
  function automatic logic [38:0] encode(input logic [31:0] d);
    logic [38:0] cw;    // codeword being built
    int          di;    // index of the next data bit to place
    logic        p;     // running XOR for one check bit

    cw = '0;            // start with all zeros
    di = 0;

    // ---------------------------------------------- step 1: place data bits
    // (pos & (pos - 1)) is 0 only for powers of two. Example: 8 & 7 =
    // 1000 & 0111 = 0. So "!= 0" means "not a power of two" = a data slot.
    for (int pos = 1; pos <= 38; pos++) begin
      if ((pos & (pos - 1)) != 0) begin
        cw[pos] = d[di];          // next data bit goes here
        di++;
      end
    end

    // ---------------------------------------------- step 2: the 6 check bits
    // For each k, XOR together every DATA position whose number has bit k
    // set, and store the result at position 2^k.
    for (int k = 0; k < 6; k++) begin
      p = 1'b0;
      for (int pos = 1; pos <= 38; pos++) begin
        // ((pos >> k) & 1): is bit k of pos set?
        if (((pos >> k) & 1) && ((pos & (pos - 1)) != 0))
          p = p ^ cw[pos];        // ^ = XOR
      end
      cw[1 << k] = p;             // 1 << k = 2^k: positions 1, 2, 4, 8, 16, 32
    end

    // ---------------------------------------------- step 3: overall parity
    // ^cw[38:1] is a "reduction XOR": XOR of all 38 bits. Storing it in
    // bit 0 makes the total number of 1s in the codeword even.
    cw[0] = ^cw[38:1];

    return cw;
  endfunction

  // The module's output is simply the function applied to the input.
  assign codeword = encode(data);

endmodule