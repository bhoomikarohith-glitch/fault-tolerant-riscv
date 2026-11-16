make sim VCD=1`timescale 1ns/1ps

// ==============================================================================
// 1. TRANSACTION INTERFACE (Sequence Item)
// ==============================================================================
class mul_transaction;
    rand logic signed [31:0] A;
    rand logic signed [31:0] B;
         logic signed [63:0] product;
         logic               error_flag;

    // Print utility function for debugging telemetry
    function void display(string name);
        $display("[%s] A = %d, B = %d | Product = %h (Dec: %d), Err = %b",
                  name, A, B, product, product, error_flag);
    endfunction
endclass


// ==============================================================================
// 2. GENERATOR (Creates Stimulus Vectors)
// ==============================================================================
class generator;
    mul_transaction trans;
    mailbox #(mul_transaction) gen2drv; // Mailbox to pass transaction tokens to driver
    int num_tests;
    event drv_done; // Event to handshake with driver sync

    function new(mailbox #(mul_transaction) gen2drv, int num_tests, event drv_done);
        this.gen2drv   = gen2drv;
        this.num_tests  = num_tests;
        this.drv_done   = drv_done;
    endfunction

    task run();
        $display("[Generator] Starting stimulus loop for %d iterations.", num_tests);
       
        // 1. Inject initial heavy structural corner test sets manually
        for (int i = 0; i < 6; i++) begin
            trans = new();
            case(i)
                0: begin trans.A = 32'd0;          trans.B = 32'd0;          end
                1: begin trans.A = 32'd7;          trans.B = -32'd6;         end // Textbook check
                2: begin trans.A = 32'h7FFFFFFF;   trans.B = 32'h7FFFFFFF;   end // Max Pos * Max Pos
                3: begin trans.A = 32'h80000000;   trans.B = 32'h80000000;   end // Max Neg * Max Neg
                4: begin trans.A = 32'h80000000;   trans.B = 32'h7FFFFFFF;   end // Max Neg * Max Pos
                5: begin trans.A = -32'd1;         trans.B = 32'd500;        end
            endcase
            gen2drv.put(trans);
            @drv_done; // Wait until driver finishes pushing this specific token
        end

        // 2. Inject constrained-random validation trials
        repeat(num_tests) begin
            trans = new();
            if (!trans.randomize()) $fatal("[Generator] Transaction Randomization Failed!");
            gen2drv.put(trans);
            @drv_done;
        end
    endtask
endclass


// ==============================================================================
// 3. DRIVER (Drives Stimulus Wires into DUT Interface)
// ==============================================================================
class driver;
    virtual mul_interface vif;
    mailbox #(mul_transaction) gen2drv;
    event drv_done;

    function new(virtual mul_interface vif, mailbox #(mul_transaction) gen2drv, event drv_done);
        this.vif     = vif;
        this.gen2drv = gen2drv;
        this.drv_done = drv_done;
    endfunction

    task run();
        forever begin
            mul_transaction trans;
            gen2drv.get(trans);
           
            // Sync with virtual clock edge to prevent setup/hold time violations
            @(posedge vif.clk);
            vif.A <= trans.A;
            vif.B <= trans.B;
           
            // Allow signals to settle over the physical combinational tree path
            #1;
            ->drv_done; // Release generator to calculate the next loop token
        end
    endtask
endclass


// ==============================================================================
// 4. MONITOR (Passively Observes I/O Wires and Extracts Transactions)
// ==============================================================================
class monitor;
    virtual mul_interface vif;
    mailbox #(mul_transaction) mon2scb; // Mailbox to pass output tokens to scoreboard

    function new(virtual mul_interface vif, mailbox #(mul_transaction) mon2scb);
        this.vif     = vif;
        this.mon2scb = mon2scb;
    endfunction

    task run();
        forever begin
            mul_transaction trans;
           
            // Sample on the negative clock edge when values have fully stabilized
            @(negedge vif.clk);
            trans = new();
            trans.A          = vif.A;
            trans.B          = vif.B;
            trans.product    = vif.product;
            trans.error_flag = vif.error_flag;
           
            mon2scb.put(trans);
        end
    endtask
endclass


// ==============================================================================
// 5. SCOREBOARD (Golden Reference Model Validation and Metric Capture)
// ==============================================================================
class scoreboard;
    mailbox #(mul_transaction) mon2scb;
    int total_checked = 0;
    int error_mismatches = 0;

    function new(mailbox #(mul_transaction) mon2scb);
        this.mon2scb = mon2scb;
    endfunction

    task run();
        forever begin
            mul_transaction trans;
            logic signed [63:0] golden_product;
           
            mon2scb.get(trans);
           
            // Golden reference mathematical calculation matrix
            golden_product = signed'(trans.A) * signed'(trans.B);
            total_checked++;

            if (trans.product !== golden_product) begin
                $display("[SCOREBOARD ERROR] Mismatch Found!");
                trans.display("DUT");
                $display("[SCOREBOARD EXPECTED] Product = %h (Dec: %d)", golden_product, golden_product);
                error_mismatches++;
            end
        end
    endtask
endclass


// ==============================================================================
// 6. HARDWARE VIRTUAL INTERFACE DEFINITION
// ==============================================================================
interface mul_interface(input logic clk);
    logic signed [31:0] A;
    logic signed [31:0] B;
    logic signed [63:0] product;
    logic               error_flag;
endinterface


// ==============================================================================
// 7. ENVIRONMENT WRAPPER AND TOP MODULE CONTAINER
// ==============================================================================
module tb_booth_multiplier_oop;

    // Generate physical clock network
    logic clk;
    always #5 clk = (clk === 1'b0) ? 1'b1 : 1'b0; // Clean 100MHz simulation clock

    // Instantiate physical tracking interface bus
    mul_interface intf(clk);

    // Instantiate your physical design unit under test (DUT) core module
    booth_multiplier dut (
        .A(intf.A),
        .B(intf.B),
        .product(intf.product),
        .error_flag(intf.error_flag)
    );

    // Centralized Interconnect Handshaking Architecture
    mailbox #(mul_transaction) gen2drv_mb;
    mailbox #(mul_transaction) mon2scb_mb;
    event drv_done_evt;

    generator  gen;
    driver     drv;
    monitor    mon;
    scoreboard scb;

    initial begin
        clk = 0;
       
        // Instantiate Interconnect Mailboxes
        gen2drv_mb = new();
        mon2scb_mb = new();

        // Instantiate verification components, injecting the virtual interfaces
        gen = new(gen2drv_mb, 2000, drv_done_evt); // Runs 6 corner cases + 2000 random test iterations
        drv = new(intf, gen2drv_mb, drv_done_evt);
        mon = new(intf, mon2scb_mb);
        scb = new(mon2scb_mb);

        $display("=========================================================");
        $display(" STARTING OOP OBJECT MODEL BOOTH MULTIPLIER TESTBENCH   ");
        $display("=========================================================");

        // Spawn component execution loops in parallel using a fork-join block
        fork
            gen.run();
            drv.run();
            mon.run();
            scb.run();
        join_any // Continues parsing execution once the generator thread closes out

        // Allow trailing transactions inside the pipe line mailboxes to flush out clean
        #50;

        $display("=========================================================");
        $display(" OOP SCOREBOARD REPORT SUMMARY                           ");
        $display("=========================================================");
        $display(" Total Vectors Processed and Verified : %d", scb.total_checked);
        $display(" Total Mathematical Mismatch Errors   : %d", scb.error_mismatches);
        $display("=========================================================");
       
        if (scb.error_mismatches == 0) begin
            $display(" STATUS CLASSIFICATION: SUCCESSFUL VERIFICATION RUN PASSED");
        end else begin
            $display(" STATUS CLASSIFICATION: CRITICAL BREAKAGE DETECTED FAILED");
        end
        $display("=========================================================");
       
        $finish;
    end

endmodule
