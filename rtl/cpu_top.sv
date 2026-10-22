// =============================================================================
// cpu_top.sv  -  Top level: core + instruction memory + data memory 
// -----------------------------------------------------------------------------
// WHAT IT DOES
//   Puts the core next to its two memories (a "Harvard" design: separate
//   instruction and data memories, so an instruction can be fetched and data
//   loaded in the same cycle).
//
//   The data-memory store port (memwrite, dataadr, writedata) is brought out
//   as outputs so the testbench, or the FPGA wrapper, can watch stores.
// =============================================================================

module cpu_top #(
  parameter MEM_FILE  = "program.mem",  // program loaded into instruction memory
  parameter DATA_FILE = ""              // optional starting contents of data memory
) (
  input  logic        clk,
  input  logic        reset,
  output logic [31:0] pc,               // for debugging / testbench
  output logic        memwrite,         // a store is happening
  output logic [31:0] dataadr,          // its address
  output logic [31:0] writedata         // its data
);

  logic [31:0] instr;       // instruction memory -> core
  logic [31:0] readdata;    // data memory -> core
  logic [2:0]  memfunct3;   // core -> data memory (access size/sign)

  rv32i_single u_core (
    .clk       (clk),
    .reset     (reset),
    .pc        (pc),
    .instr     (instr),
    .memwrite  (memwrite),
    .memfunct3 (memfunct3),
    .aluresult (dataadr),        // the ALU result is the memory address
    .writedata (writedata),
    .readdata  (readdata)
  );

  // Pass the file name down as a parameter (#(...)).
  instr_mem #(.INIT_FILE(MEM_FILE)) u_instr_mem (
    .a  (pc),                    // fetch address
    .rd (instr)                  // instruction out
  );

  data_mem #(.INIT_FILE(DATA_FILE)) u_data_mem (
    .clk    (clk),
    .we     (memwrite),
    .funct3 (memfunct3),
    .a      (dataadr),
    .wd     (writedata),
    .rd     (readdata)
  );

endmodule