module extend( input [2:0]immsrc,
                input [31:0]instr,
                output logic [31:0]immext
                );

always @(*)
begin 
case(immsrc)
//I-type
IMM_I: immext = {{20{instr[31]}},instr[31:20]};
//S-type
IMM_S: immext = {{20{instr[31]}},instr[31:25],instr[11:7]};
//B-type
IMM_B: immext = {{19{instr[31]}},instr[31],instr[7],instr[30:25],instr[11:8],1'b0};
//U-type
IMM_U: immext = {instr[31:12],12'b0};
//J-type
IMM_J: immext = {{11{instr[31]}},instr[31],instr[19:12],instr[20],instr[30:21],1'b0};
default: immext = 32'bx; //undefined
endcase
end
endmodule
