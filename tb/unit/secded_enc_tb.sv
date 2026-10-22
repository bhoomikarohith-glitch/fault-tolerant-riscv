// secded_enc_tb.sv
// Self-checking test of the (39,32) SECDED encoder. A reference decoder in
// this testbench proves the code's guarantees for every test word:
//   1. a clean codeword has zero syndrome and even overall parity
//   2. every single-bit flip (all 39 positions) is located exactly and,
//      once corrected, gives back the original data
//   3. every double-bit flip (all 741 pairs) is flagged as uncorrectable
// Prints PASS or FAIL; exits with an error on failure (for CI).

`timescale 1ns/1ps

module secded_enc_tb;

  logic [31:0] data;
  logic [38:0] codeword;
  int          errors = 0;
  int          words  = 0;

  secded_enc dut (.data(data), .codeword(codeword));

  // Syndrome: recompute each check over its positions (check bit included).
  function automatic logic [5:0] syndrome(input logic [38:0] cw);
    logic [5:0] s;
    s = '0;
    for (int k = 0; k < 6; k++)
      for (int pos = 1; pos <= 38; pos++)
        if ((pos >> k) & 1) s[k] = s[k] ^ cw[pos];
    return s;
  endfunction

  // Pull the 32 data bits back out of the non-power-of-two positions.
  function automatic logic [31:0] extract(input logic [38:0] cw);
    logic [31:0] d;
    int          di;
    di = 0;
    for (int pos = 1; pos <= 38; pos++)
      if ((pos & (pos - 1)) != 0) begin
        d[di] = cw[pos];
        di++;
      end
    return d;
  endfunction

  task automatic check_word(input logic [31:0] value);
    logic [38:0] cw, bad, fixed;
    logic [5:0]  s;
    logic        parity;

    data = value;
    #1;
    cw = codeword;
    words++;

    // 1. clean codeword
    if (syndrome(cw) != 0 || ^cw != 0 || extract(cw) != value) begin
      errors++;
      $display("ERROR clean word %h: codeword %h", value, cw);
    end

    // 2. every single-bit error is located and corrected
    for (int i = 0; i < 39; i++) begin
      bad    = cw ^ (39'b1 << i);
      s      = syndrome(bad);
      parity = ^bad;
      fixed  = bad;
      if (parity && s != 0) fixed[s] = ~fixed[s];   // error in position s
      else if (parity)      fixed[0] = ~fixed[0];   // error in parity bit
      if (!parity || s != ((i == 0) ? 0 : i) || extract(fixed) != value) begin
        errors++;
        $display("ERROR single flip of bit %0d in word %h", i, value);
      end
    end

    // 3. every double-bit error is detected (syndrome != 0, parity even)
    for (int i = 0; i < 39; i++)
      for (int j = i + 1; j < 39; j++) begin
        bad = cw ^ (39'b1 << i) ^ (39'b1 << j);
        if (^bad != 0 || syndrome(bad) == 0) begin
          errors++;
          $display("ERROR double flip of bits %0d,%0d in word %h", i, j, value);
        end
      end
  endtask

  initial begin
    check_word(32'h0000_0000);
    check_word(32'hFFFF_FFFF);
    check_word(32'hAAAA_AAAA);
    check_word(32'h5555_5555);
    for (int b = 0; b < 32; b++) check_word(32'b1 << b);   // walking one
    for (int n = 0; n < 200; n++) check_word($urandom);

    if (errors == 0)
      $display("PASS: %0d words, every single error corrected, every double error detected", words);
    else begin
      $display("FAIL: %0d errors", errors);
      $fatal(1);
    end
    $finish;
  end

endmodule