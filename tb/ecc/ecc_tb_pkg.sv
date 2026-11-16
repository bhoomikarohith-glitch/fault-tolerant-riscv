// =============================================================================
// ecc_tb_pkg.sv  -  layered, class-based testbench for the SECDED ECC path
// -----------------------------------------------------------------------------
// LAYERS (each one is a class below, in this order)
//
//   transaction   one test case: a data word + which bits to corrupt
//   generator     makes transactions (directed sweeps, then random ones)
//        |  mailbox gen2drv
//        v
//   driver        puts each transaction onto the interface pins
//        |  (DUT: ecc_top = encoder -> flip bits -> decoder)
//        v
//   monitor       watches the pins, rebuilds what happened as a transaction
//        |  mailbox mon2scb
//        v
//   scoreboard    compares against a reference model, counts pass/fail
//
//   environment   builds and connects all of the above, runs them together
//   test          configures the environment and starts it
//
// A mailbox is a FIFO for passing objects between threads: put() adds one,
// get() waits until one is there and takes it.
//
// Everything is in one package so Vivado needs no include paths: add this
// file, ecc_if.sv and ecc_tb_top.sv as simulation sources and it compiles.
// =============================================================================

`timescale 1ns/1ps

package ecc_tb_pkg;

  // Which fault a transaction injects
  typedef enum {ERR_NONE, ERR_SINGLE, ERR_DOUBLE} err_kind_e;

  // ===========================================================================
  // TRANSACTION - one test case and, after the monitor fills it, its result
  // ===========================================================================
  class transaction;
    // ---- stimulus. 'rand' fields are filled by randomize().
    rand bit [31:0]   data;       // word to protect
    rand err_kind_e   kind;       // how many bits to flip
    rand int unsigned pos1;       // first bit to flip  (0..38)
    rand int unsigned pos2;       // second bit to flip (0..38), DOUBLE only

    // ---- response, filled in by the monitor
    bit [38:0] flip_mask;
    bit [38:0] codeword;
    bit [31:0] data_out;
    bit        single_err;
    bit        double_err;
    bit [5:0]  syndrome;

    // Constraints: rules randomize() must respect
    constraint c_pos  { pos1 < 39; pos2 < 39; pos1 != pos2; }
    constraint c_kind { kind dist {ERR_NONE := 1, ERR_SINGLE := 2, ERR_DOUBLE := 2}; }

    // Runs automatically right after randomize(). Vivado honours the
    // constraints above, so this changes nothing there; it only keeps values
    // legal on simulators that skip constraints (e.g. older Verilator).
    function void post_randomize();
      if (pos1 >= 39) pos1 = pos1 % 39;
      if (pos2 >= 39) pos2 = pos2 % 39;
      if (pos2 == pos1) pos2 = (pos1 + 1) % 39;
      if (kind > ERR_DOUBLE) kind = ERR_DOUBLE;
    endfunction

    // Turn kind/pos1/pos2 into the 39-bit mask the DUT needs
    function bit [38:0] make_mask();
      bit [38:0] m;
      m = '0;
      if (kind != ERR_NONE)   m[pos1] = 1'b1;
      if (kind == ERR_DOUBLE) m[pos2] = 1'b1;
      return m;
    endfunction

    function string to_string();
      return $sformatf("data=%08h mask=%010h -> cw=%010h out=%08h se=%0b de=%0b syn=%0d",
                       data, flip_mask, codeword, data_out, single_err, double_err, syndrome);
    endfunction
  endclass

  // ===========================================================================
  // GENERATOR - decides WHAT to test
  // ===========================================================================
  class generator;
    mailbox #(transaction) gen2drv;
    int unsigned           n_random;   // how many random cases after the sweeps
    int unsigned           count;      // total transactions sent
    event                  done;       // fires when all are sent

    function new(mailbox #(transaction) gen2drv, int unsigned n_random);
      this.gen2drv  = gen2drv;
      this.n_random = n_random;
    endfunction

    // helper: send one hand-built transaction
    task send(bit [31:0] d, err_kind_e k, int unsigned p1, int unsigned p2);
      transaction tr = new();
      tr.data = d; tr.kind = k; tr.pos1 = p1; tr.pos2 = p2;
      gen2drv.put(tr);
      count++;
    endtask

    task run();
      bit [31:0] patterns[4] = '{32'h0000_0000, 32'hFFFF_FFFF,
                                 32'hA5A5_5A5A, 32'h1234_5678};
      count = 0;

      // ---- phase 1: directed sweep. For each pattern: no error, every
      //      single-bit flip (39), and every pair of flips (39*38/2 = 741).
      foreach (patterns[i]) begin
        send(patterns[i], ERR_NONE, 0, 1);
        for (int p = 0; p < 39; p++)
          send(patterns[i], ERR_SINGLE, p, (p + 1) % 39);
        for (int p = 0; p < 39; p++)
          for (int q = p + 1; q < 39; q++)
            send(patterns[i], ERR_DOUBLE, p, q);
      end

      // ---- phase 2: constrained random
      repeat (n_random) begin
        transaction tr = new();
        if (!tr.randomize()) $fatal(1, "[GEN] randomize() failed");
        gen2drv.put(tr);
        count++;
      end

      $display("[GEN] sent %0d transactions", count);
      -> done;
    endtask
  endclass

  // ===========================================================================
  // DRIVER - turns transactions into pin wiggles
  // ===========================================================================
  class driver;
    virtual ecc_if         vif;
    mailbox #(transaction) gen2drv;

    function new(virtual ecc_if vif, mailbox #(transaction) gen2drv);
      this.vif     = vif;
      this.gen2drv = gen2drv;
    endfunction

    task reset();
      vif.valid     <= 1'b0;
      vif.data_in   <= '0;
      vif.flip_mask <= '0;
      @(posedge vif.clk);
    endtask

    task run();
      transaction tr;
      forever begin
        gen2drv.get(tr);                 // wait for the next case
        @(posedge vif.clk);
        vif.valid     <= 1'b1;
        vif.data_in   <= tr.data;
        vif.flip_mask <= tr.make_mask();
      end
    endtask
  endclass

  // ===========================================================================
  // MONITOR - only watches; never drives anything
  // ===========================================================================
  class monitor;
    virtual ecc_if         vif;
    mailbox #(transaction) mon2scb;

    function new(virtual ecc_if vif, mailbox #(transaction) mon2scb);
      this.vif     = vif;
      this.mon2scb = mon2scb;
    endfunction

    task run();
      forever begin
        @(negedge vif.clk);              // inputs set at posedge, settled now
        if (vif.valid) begin
          transaction tr = new();
          tr.data       = vif.data_in;
          tr.flip_mask  = vif.flip_mask;
          tr.codeword   = vif.codeword;
          tr.data_out   = vif.data_out;
          tr.single_err = vif.single_err;
          tr.double_err = vif.double_err;
          tr.syndrome   = vif.syndrome;
          mon2scb.put(tr);
        end
      end
    endtask
  endclass

  // ===========================================================================
  // SCOREBOARD - reference model + checks
  // ===========================================================================
  class scoreboard;
    mailbox #(transaction) mon2scb;
    int unsigned checked, errors;
    int unsigned n_none, n_single, n_double;   // how many of each were seen

    function new(mailbox #(transaction) mon2scb);
      this.mon2scb = mon2scb;
    endfunction

    // Reference encoder, written independently of the RTL: build each check
    // bit straight from the data-bit positions instead of a placed codeword.
    function bit [38:0] ref_encode(bit [31:0] d);
      bit [38:0] cw;
      int unsigned pos_of[32];           // pos_of[i] = Hamming position of data bit i
      int unsigned i = 0;
      for (int unsigned pos = 3; pos <= 38; pos++)
        if (!$onehot(pos)) begin pos_of[i] = pos; i++; end
      cw = '0;
      for (int b = 0; b < 32; b++) cw[pos_of[b]] = d[b];
      for (int k = 0; k < 6; k++)
        for (int b = 0; b < 32; b++)
          if (pos_of[b] & (1 << k)) cw[1 << k] ^= d[b];
      cw[0] = ^cw[38:1];
      return cw;
    endfunction

    task check(transaction tr);
      int unsigned flips = $countones(tr.flip_mask);
      bit [38:0]   exp_cw = ref_encode(tr.data);
      bit          ok = 1'b1;
      string       why = "";

      if (tr.codeword !== exp_cw) begin ok = 0; why = {why, " codeword"}; end

      case (flips)
        0: begin
             n_none++;
             if (tr.data_out !== tr.data) begin ok = 0; why = {why, " data"}; end
             if (tr.single_err || tr.double_err) begin ok = 0; why = {why, " false-flag"}; end
           end
        1: begin
             n_single++;
             if (tr.data_out !== tr.data) begin ok = 0; why = {why, " not-corrected"}; end
             if (!tr.single_err || tr.double_err) begin ok = 0; why = {why, " flags"}; end
             // the syndrome must point at the flipped bit (0 means bit 0)
             if ((1 << tr.syndrome) != tr.flip_mask) begin ok = 0; why = {why, " syndrome"}; end
           end
        2: begin
             n_double++;
             // data may be wrong here; the decoder only has to SAY so
             if (tr.single_err || !tr.double_err) begin ok = 0; why = {why, " not-detected"}; end
           end
        default: begin ok = 0; why = " >2 flips (generator bug)"; end
      endcase

      checked++;
      if (!ok) begin
        errors++;
        if (errors <= 10)
          $display("[SCB] MISMATCH (%s ): %s", why, tr.to_string());
      end
    endtask

    task run();
      transaction tr;
      forever begin
        mon2scb.get(tr);
        check(tr);
      end
    endtask

    function void report();
      $display("");
      $display("==================== ECC SCOREBOARD ====================");
      $display("  no-error cases     : %0d", n_none);
      $display("  single-bit (fixed) : %0d", n_single);
      $display("  double-bit (caught): %0d", n_double);
      $display("  checked %0d, mismatches %0d", checked, errors);
      $display("  RESULT: %s", (errors == 0 && checked > 0) ? "PASS" : "FAIL");
      $display("========================================================");
    endfunction
  endclass

  // ===========================================================================
  // ENVIRONMENT - builds, connects and runs every component
  // ===========================================================================
  class environment;
    generator  gen;
    driver     drv;
    monitor    mon;
    scoreboard scb;
    mailbox #(transaction) gen2drv, mon2scb;
    virtual ecc_if vif;

    function new(virtual ecc_if vif, int unsigned n_random);
      this.vif = vif;
      gen2drv  = new();
      mon2scb  = new();
      gen = new(gen2drv, n_random);
      drv = new(vif, gen2drv);
      mon = new(vif, mon2scb);
      scb = new(mon2scb);
    endfunction

    task run();
      drv.reset();
      fork                     // start all four, each in its own thread
        gen.run();
        drv.run();
        mon.run();
        scb.run();
      join_none

      @(gen.done);                               // everything generated ...
      while (scb.checked != gen.count)            // ... and everything checked
        @(posedge vif.clk);
      scb.report();
    endtask
  endclass

  // ===========================================================================
  // TEST - the top-level recipe. New tests = new classes like this one.
  // ===========================================================================
  class ecc_test;
    environment env;

    function new(virtual ecc_if vif, int unsigned n_random = 2000);
      env = new(vif, n_random);
    endfunction

    task run();
      env.run();
    endtask
  endclass

endpackage
