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
    logic [63:0] stage1_s [4:0];
    logic [64:0] stage1_c [4:0];
    
    // LAYER 1: Compress 15 rows into 10 vectors (pp[15] bypasses)
    generate
        for (genvar g = 0; g < 5; g++) begin : gen_stage1
            compressor_3_2 #(.WIDTH(64)) c1 (
                .A(pp[3*g]), .B(pp[3*g+1]), .C(pp[3*g+2]),
                .sum(stage1_s[g]), .cout(stage1_c[g])
            );
        end
    </generate>

    // LAYER 2: Compress 9 inputs down to 6 vectors
    logic [64:0] stage2_s [2:0];
    logic [65:0] stage2_c [2:0];
    logic [64:0] s2_in_A0, s2_in_A1, s2_in_A2;

    assign s2_in_A0 = {stage1_s[0][63], stage1_s[0]}; // Sign-extended to 65 bits
    assign s2_in_A1 = {stage1_s[1][63], stage1_s[1]};
    assign s2_in_A2 = {stage1_s[2][63], stage1_s[2]};

    compressor_3_2 #(.WIDTH(65)) c2_0 (.A(s2_in_A0), .B(stage1_c[0]), .C(s2_in_A1), .sum(stage2_s[0]), .cout(stage2_c[0]));
    compressor_3_2 #(.WIDTH(65)) c2_1 (.A(s2_in_A2), .B(stage1_c[1]), .C(stage1_c[2]), .sum(stage2_s[1]), .cout(stage2_c[1]));
    compressor_3_2 #(.WIDTH(65)) c2_2 (.A({stage1_s[3][63], stage1_s[3]}), .B(stage1_c[3]), .C({stage1_s[4][63], stage1_s[4]}), .sum(stage2_s[2]), .cout(stage2_c[2]));

    // LAYER 3: Compress 6 inputs down to 4 vectors
    logic [65:0] s3_0, s3_1;
    logic [66:0] c3_0, c3_1;

    compressor_3_2 #(.WIDTH(66)) c3_inst0 (
        .A({stage2_s[0][64], stage2_s[0]}), .B(stage2_c[0]), .C({stage2_s[1][64], stage2_s[1]}),
        .sum(s3_0), .cout(c3_0)
    );
    compressor_3_2 #(.WIDTH(66)) c3_inst1 (
        .A(stage2_c[1]), .B({stage2_s[2][64], stage2_s[2]}), .C(stage2_c[2]),
        .sum(s3_1), .cout(c3_1)
    );

    // LAYER 4: Bring in leftovers (stage1_c[4] and bypassed pp[15])
    // 6 vectors remaining -> Compress down to 4 vectors
    logic [66:0] s4_0, s4_1;
    logic [67:0] c4_0, c4_1;
    
    compressor_3_2 #(.WIDTH(67)) c4_inst0 (
        .A({s3_0[65], s3_0}), 
        .B({s3_1[65], s3_1}), 
        .C({stage1_c[4][64], stage1_c[4][64], stage1_c[4]}), // Sign-extend 65 to 67 bits
        .sum(s4_0), .cout(c4_0)
    );

    compressor_3_2 #(.WIDTH(67)) c4_inst1 (
        .A(c3_0), 
        .B(c3_1), 
        .C({pp[15][63], pp[15][63], pp[15][63], pp[15]}),   // Sign-extend 64 to 67 bits
        .sum(s4_1), .cout(c4_1)
    );

    // LAYER 5: 4 vectors remaining -> Compress down to 3 vectors
    logic [67:0] s5_0;
    logic [68:0] c5_0;

    compressor_3_2 #(.WIDTH(68)) c5_inst0 (
        .A({s4_0[66], s4_0}), 
        .B({s4_1[66], s4_1}), 
        .C(c4_0),
        .sum(s5_0), .cout(c5_0)
    );

    // LAYER 6 (FINAL COMPRESSOR LAYER): 3 vectors remaining -> Compress down to 2 vectors
    // Vectors: s5_0 (68 bits), c5_0 (69 bits), c4_1 (68 bits leftover from Layer 4)
    logic [68:0] final_s;
    logic [69:0] final_c;

    compressor_3_2 #(.WIDTH(69)) c6_final (
        .A({s5_0[67], s5_0}),
        .B({c4_1[67], c4_1}),
        .C(c5_0),
        .sum(final_s), .cout(final_c)
    );

    // 4. Final Carry-Propagate Adder (CPA)
    // Sign-extend final_s to 70 bits to match final_c's expanded width
    logic [69:0] complete_sum;
    assign complete_sum = {final_s[68], final_s} + final_c;
    assign product      = complete_sum[63:0];

    // 5. Modulo-3 Residue Checker (Placeholder hook)
    assign error_flag = 1'b0; 

endmodule
