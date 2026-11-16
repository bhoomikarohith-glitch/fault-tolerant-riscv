`timescale 1ns/1ps
module tb_c_program;
    logic clk = 0;
    logic reset = 1;
    wire [31:0] pc, dataadr, writedata;
    wire memwrite;
    int expected = 55;
    int max_cycles = 100000;
    int cycles = 0;
    bit stack_initialized = 0;

    cpu_top #(
        .MEM_FILE("build/c_runner/program.mem"),
        .DATA_FILE("build/c_runner/program.mem")
    ) dut (
        .clk(clk), .reset(reset), .pc(pc), .memwrite(memwrite),
        .dataadr(dataadr), .writedata(writedata)
    );

    always #5 clk = ~clk;

    initial begin
        void'($value$plusargs("EXPECTED=%d", expected));
        void'($value$plusargs("MAX_CYCLES=%d", max_cycles));
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/c_runner/c_program.vcd");
            $dumpvars(0, tb_c_program);
        end
        repeat (3) @(posedge clk);
        @(negedge clk);
        reset = 0;
    end

    ap_reset_pc: assert property (@(posedge clk) reset |=> pc == 0)
        else $fatal(1, "Reset failed");
    ap_x0: assert property (@(posedge clk) disable iff (reset)
        dut.u_core.u_datapath.u_register_file.register[0] == 0)
        else $fatal(1, "x0 changed");
    ap_fetch: assert property (@(posedge clk) disable iff (reset)
        !$isunknown(pc) && pc[1:0] == 0 && pc < 32'h800)
        else $fatal(1, "Invalid instruction PC %h", pc);

    always @(posedge clk) begin
        if (!reset) begin
            cycles++;
            assert (!$isunknown({memwrite, dataadr, writedata}))
                else $fatal(1, "Unknown memory signal");
            // This program uses only the allocated static-data/stack region.
            if (memwrite || dut.instr[6:0] == 7'h03) begin
                assert (dataadr >= 32'h800 && dataadr < 32'h1000)
                    else $fatal(1, "Data access outside RAM allocation: %h", dataadr);
                case (dut.memfunct3)
                    3'b001, 3'b101:
                        assert (dataadr[0] == 0) else $fatal(1, "Unaligned halfword");
                    3'b010:
                        assert (dataadr[1:0] == 0) else $fatal(1, "Unaligned word");
                    default: ;
                endcase
            end
            // AUIPC/ADDI constructs sp in two instructions. Enable the stack
            // bounds check once that startup sequence has completed.
            if (dut.u_core.u_datapath.u_register_file.register[2] == 32'hff0)
                stack_initialized = 1;
            if (stack_initialized) begin
                assert (dut.u_core.u_datapath.u_register_file.register[2] >= 32'hc00 &&
                        dut.u_core.u_datapath.u_register_file.register[2] <= 32'hff0)
                    else $fatal(1, "Stack pointer outside reserved stack");
            end
            if (memwrite && dataadr == 32'hffc) begin
                assert (dut.memfunct3 == 3'b010)
                    else $fatal(1, "Result must be a word store");
                assert (writedata === 32'(expected))
                    else $fatal(1, "FAIL: C main returned %0d, expected %0d",
                                $signed(writedata), expected);
                #1; // Verify that the actual data-memory RTL committed the result.
                                assert (ecc_pkg::secded_decode_data(dut.u_data_mem.mem[1023]) === 32'(expected))
                    else $fatal(1, "Result was not stored in data memory");
                $display("PASS: C main returned %0d (expected %0d), %0d cycles",
                         expected, expected, cycles);
                $finish;
            end
            assert (cycles < max_cycles)
                else $fatal(1, "C program timed out at PC %h", pc);
        end
    end
endmodule
