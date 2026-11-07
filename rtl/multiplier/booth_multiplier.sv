module booth_multiplier (
    input  logic signed [31:0] A,          // Multiplicand
    input  logic signed [31:0] B,          // Multiplier
    output logic signed [63:0] product,    // Full 64-bit product
    output logic               error_flag  // For Modulo-3 residue check integration
);

    // 1. Pad the multiplier with an implicit 0 at LSB
    logic [32:0] B_ext;
    assign B_ext = {B, 1'b0};

    // 2. Generate 16 Partial Product Rows (Sign-extended to 64-bit)
    logic signed [63:0] pp [15:0];
    
    always_comb begin
        for (int i = 0; i < 16; i++) begin
            logic [2:0] window;
            logic signed [63:0] base_pp;
            
            window = B_ext[2*i + 2 : 2*i];
            
            case (window)
                3'b000, 3'b111 : base_pp = 64'd0;
                3'b001, 3'b010 : base_pp = signed'(A);
                3'b011         : base_pp = signed'(A) << 1;
                3'b100         : base_pp = -(signed'(A) << 1);
                3'b101, 3'b110 : base_pp = -signed'(A);
                default        : base_pp = 64'd0;
            endcase
            
            // Shift by 2*i bits to represent Radix-4 positional weight
            pp[i] = base_pp << (2 * i);
        end
    end

    // 3. 3:2 Compressor Tree Structure (16 rows down to 2 vectors)
    // Using a clear layered approach to compress the array structural rows
    logic [63:0] stage1_s [4:0];
    logic [64:0] stage1_c [4:0];
    
    // Layer 1: Compress 15 rows into 10 vectors (pp[15] bypasses)
    generate
        for (genvar g = 0; g < 5; g++) begin : gen_stage1
            compressor_3_2 #(.WIDTH(64)) c1 (
                .A(pp[3*g]), .B(pp[3*g+1]), .C(pp[3*g+2]),
                .sum(stage1_s[g]), .cout(stage1_c[g])
            );
        end
    </generate>

    // Remaining vectors now: 5 Sums + 5 Carries + 1 Bypassed Row = 11 rows
    logic [64:0] stage2_s [2:0];
    logic [65:0] stage2_c [2:0];

    // Layer 2: Compress 9 rows into 6 vectors
    // Sign-extend inputs to 65 bits to match Carry output sizing
    generate
        for (genvar g = 0; g < 3; g++) begin : gen_stage2
            compressor_3_2 #(.WIDTH(65)) c2 (
                .A( {stage1_s[g][63], stage1_s[g]} ), 
                .B( stage1_c[g] ), 
                .C( g == 2 ? {pp[15][63], pp[15]} : {stage1_s[g+3][63], stage1_s[g+3]} ),
                .sum(stage2_s[g]), .cout(stage2_c[g])
            );
        end
    </generate>

    // Remaining vectors: 3 Sums + 3 Carries + 2 Leftover Carries (stage1_c[3,4]) = 8 rows
    // To maintain high structural readability, we flatten the remaining vectors
    // sequentially until 2 remain.
    
    logic [65:0] r_s1; logic [66:0] r_c1;
    compressor_3_2 #(.WIDTH(66)) tree_r1 (
        .A({stage2_s[0][64], stage2_s[0]}), .B(stage2_c[0]), .C({stage2_s[1][64], stage2_s[1]}),
        .sum(r_s1), .cout(r_c1)
    );

    logic [65:0] r_s2; logic [66:0] r_c2;
    compressor_3_2 #(.WIDTH(66)) tree_r2 (
        .A(stage2_c[1]), .B({stage2_s[2][64], stage2_s[2]}), .C(stage2_c[2]),
        .sum(r_s2), .cout(r_c2)
    );

    // Leftovers from layer 1 injected back
    logic [66:0] r_s3; logic [67:0] r_c3;
    compressor_3_2 #(.WIDTH(67)) tree_r3 (
        .A({r_s1[65], r_s1}), .B(r_c1), .C({1'b0, stage1_c[3]}),
        .sum(r_s3), .cout(r_c3)
    );

    logic [67:0] r_s4; logic [68:0] r_c4;
    compressor_3_2 #(.WIDTH(68)) tree_r4 (
        .A({r_s3[66], r_s3}), .B(r_c3), .C({2'b0, stage1_c[4]}),
        .sum(r_s4), .cout(r_c4)
    );

    logic [68:0] final_s; logic [69:0] final_c;
    compressor_3_2 #(.WIDTH(69)) tree_final (
        .A({1'b0, r_s4}), .B(r_c4), .C({3'b0, r_s2}),
        .sum(final_s), .cout(final_c)
    );

    // 4. Final Carry-Propagate Adder (CPA)
    // Collapses the last two 70-bit rows down to the final product result
    logic [69:0] complete_sum;
    assign complete_sum = final_s + final_c;
    assign product      = complete_sum[63:0];

    // 5. Modulo-3 Residue Checker (Placeholder hook)
    // Compares independent residue calculations to toggle error flag
    assign error_flag = 1'b0; 

endmodule
