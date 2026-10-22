module branch_comp (
  input  logic [31:0] rd1,           // value of register rs1 (32 bits)
  input  logic [31:0] rd2,           // value of register rs2 (32 bits)
  input  logic [2:0]  funct3,        // instr[14:12]: says WHICH comparison
  output logic        branchtaken    // 1 = condition is true, branch taken
);

  // always_comb = combinational logic: re-evaluates whenever an input changes.
  // A case statement must sit inside a block like this one.
  always_comb begin

    // case picks one line based on funct3. Each line assigns the result of a
    // comparison; a comparison like (rd1 == rd2) is already a 1-bit 0 or 1.
    case (funct3)

      3'b000: branchtaken = (rd1 == rd2);   // BEQ : branch if equal
      3'b001: branchtaken = (rd1 != rd2);   // BNE : branch if not equal

      // $signed() makes the comparison treat the bits as two's-complement
      // numbers, so 0xFFFFFFFF means -1. BOTH sides must be wrapped; if only
      // one is, Verilog silently falls back to an unsigned compare.
      3'b100: branchtaken = ($signed(rd1) <  $signed(rd2));  // BLT : signed <
      3'b101: branchtaken = ($signed(rd1) >= $signed(rd2));  // BGE : signed >=

      // logic values are unsigned by default, so a plain < is the unsigned
      // compare: 0xFFFFFFFF here means 4,294,967,295.
      3'b110: branchtaken = (rd1 <  rd2);   // BLTU: unsigned <
      3'b111: branchtaken = (rd1 >= rd2);   // BGEU: unsigned >=

      // funct3 = 010 and 011 are not branch instructions. Giving a defined
      // 0 here keeps the logic latch-free and predictable.
      default: branchtaken = 1'b0;

    endcase
  end

endmodule