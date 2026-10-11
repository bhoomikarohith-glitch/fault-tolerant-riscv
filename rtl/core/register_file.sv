module register_file( input logic clk,
                        input logic rst,
                        input logic [4:0]rs1, //address of first source reg
                        input logic [4:0]rs2, //address of second source reg
                        input logic [4:0]rd, //address of the destination register
                        input logic reg_write, //to enable write_data
                        input logic [31:0]write_data, //data to be written into the destination register
                        output logic [31:0]rd1, //read data from rs1
                        output logic [31:0]rd2   //read data from rs2
                     );


logic [31:0]register[0:31]; //32 registers with each width 32 bits
// logic [31:0] instruction[0:31];

// assign rs1 = instruction[19:15];
// assign rs2 = instruction[24:20];
// rd = instruction[11:7];

always @(posedge clk)
begin
if(rst == 1'b1)
begin
        for(int i= 0; i< 32; i++)
        begin 
            register[i] <= 32'b0;
        end
end
else
begin 
    if(reg_write == 1'b1 && rd != 5'b0 )
    begin 
        register[rd] <= write_data;
    end
end
end

always_comb 
begin 
        rd1 = (rs1 == 5'b0)? 32'b0 : register[rs1];
        rd2 = (rs2 == 5'b0)? 32'b0 : register[rs2];
end

endmodule
