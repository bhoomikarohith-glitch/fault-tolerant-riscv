module compressor_3_2 #(
    parameter int WIDTH = 64
)(
    input  logic [WIDTH-1:0] A,
    input  logic [WIDTH-1:0] B,
    input  logic [WIDTH-1:0] C,
    output logic [WIDTH-1:0] sum,
    output logic [WIDTH:0]   cout // One bit wider to prevent loss of highest carry
);
    logic [WIDTH-1:0] cout_raw;

    assign sum      = A ^ B ^ C;
    assign cout_raw = (A & B) | (B & C) | (A & C);
    assign cout     = {cout_raw, 1'b0}; // Safe left-shift alignment
endmodule

