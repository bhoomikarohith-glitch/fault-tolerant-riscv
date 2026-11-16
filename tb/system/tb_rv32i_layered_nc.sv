// Save as tb/system/tb_rv32i_layered_nc.sv in the uploaded repository.
// Run from the repository root with Cadence Incisive/NC-Verilog:
// irun -sv -access +rwc -coverage all -top tb_rv_layered \
//   rtl/common/rv_pkg.sv rtl/common/adder.sv rtl/common/mux2.sv \
//   rtl/core/*.sv rtl/multiplier/*.sv tb/system/tb_rv32i_layered_nc.sv
// Optional runtime arguments: +RANDOM_COUNT=1000 +vcd
// Compile ONLY this testbench top and the RTL listed above.
//
// Target DUT: rv32i_single from your uploaded ZIP, including custom MULX.
// Debug probes use your exact datapath/register-file instance names.
// Core-level verification supplies external data-memory responses. The
// repository's instruction/data-memory RTL and ECC require separate testing.
// Directed instruction injection checks individual operations and PC changes.
// A separate PC-indexed loop program checks normal fetch/branch execution.
//
// Coverage comprises 385 explicit bins: 38 operations, 32 rs1 selections,
// 32 rs2 selections, 32 rd selections (including attempted x0 writes),
// 24 branch subtype/outcome/direction combinations, 13 load type/lane bins,
// 7 store type/lane bins, 192 shift operation/amount combinations,
// 6 operand-A classes, 6 operand-B classes, and 3 immediate sign classes.
// Both the explicit-bin percentage and the native covergroup percentage
// must exceed 92%, and every operation must be observed, to print PASS.
// Only scoreboard-checked instructions are sampled for coverage.
//
// Verified locally with Verilator using PORTABLE_COVERAGE: 385/385 bins
// (100%) and 1689 checked instructions with 500 random instructions.
// SVA and scoreboard assertions passed. NC-Verilog and its native covergroup
// results have not been executed here. The native covergroup uses the same
// sampled bins. Code coverage is a separate simulator-reported metric.
// Define PORTABLE_COVERAGE only when using a simulator without covergroups.
`ifndef PORTABLE_COVERAGE
  `define ENABLE_COVERGROUPS
`endif

`timescale 1ns/1ps
interface rv_if(input logic clk);
  logic reset=1, valid=0;
  logic [31:0] instr=32'h13, readdata=0;
  wire [31:0] pc, aluresult, writedata;
  wire memwrite;
  wire [2:0] memfunct3;
  wire [31:0] regs[0:31];
  wire [31:0] nextpc_debug;
  wire regwrite_debug;
  wire [31:0] result_debug;

  ap_pc_update: assert property (@(posedge clk) disable iff(reset)
    valid |=> pc == $past(nextpc_debug)) else $fatal(1,"PC update assertion");
  ap_reset: assert property (@(posedge clk) reset |=> pc==0)
    else $fatal(1,"Reset PC assertion");
  ap_x0: assert property (@(posedge clk) disable iff(reset) regs[0]==0)
    else $fatal(1,"x0 assertion");
  ap_store_decode: assert property (@(posedge clk) disable iff(reset)
    valid |-> (memwrite == (instr[6:0]==7'h23)))
    else $fatal(1,"Store decode assertion");
  ap_known: assert property (@(posedge clk) disable iff(reset)
    valid |-> !$isunknown({pc,instr,memwrite,aluresult,writedata,readdata}))
    else $fatal(1,"Unknown signal assertion");
endinterface

package rv_tb_pkg;
  typedef enum int {
    ADD,SUB,SLL,SLT,SLTU,XOR_OP,SRL,SRA,OR_OP,AND_OP,
    ADDI,SLLI,SLTI,SLTIU,XORI,SRLI,SRAI,ORI,ANDI,
    LB,LH,LW,LBU,LHU,SB,SH,SW,BEQ,BNE,BLT,BGE,BLTU,BGEU,
    LUI,AUIPC,JAL,JALR,MULX
  } operation_t;
  localparam int OP_COUNT=38, MEM_SIZE=4096;

  function automatic bit is_branch(operation_t op);
    return op inside {BEQ,BNE,BLT,BGE,BLTU,BGEU};
  endfunction
  function automatic bit is_load(operation_t op);
    return op inside {LB,LH,LW,LBU,LHU};
  endfunction
  function automatic bit is_store(operation_t op);
    return op inside {SB,SH,SW};
  endfunction
  function automatic bit is_shift(operation_t op);
    return op inside {SLL,SRL,SRA,SLLI,SRLI,SRAI};
  endfunction
  function automatic bit uses_rs1(operation_t op);
    return !(op inside {LUI,AUIPC,JAL});
  endfunction
  function automatic bit uses_rs2(operation_t op);
    return (op<=AND_OP) || is_branch(op) || is_store(op) || op==MULX;
  endfunction
  function automatic bit writes_rd(operation_t op);
    return !is_branch(op) && !is_store(op);
  endfunction

  class rv_transaction;
    rand operation_t op;
    rand bit [4:0] rd, rs1, rs2;
    rand int signed imm;
    bit stop=0;
    string label;
    constraint legal {
      op inside {[ADD:MULX]};
      if(op inside {SLLI,SRLI,SRAI}) imm inside {[0:31]};
      else if(is_branch(op)) { imm inside {[-256:256]}; imm%4==0; }
      else if(op==JAL) {imm inside {[-1024:1024]}; imm%4==0;}
      else if(op inside {LUI,AUIPC}) imm inside {[0:1048575]};
      else imm inside {[-2048:2047]};
      if(is_load(op) || is_store(op)) {
        rs1==20; imm inside {[0:252]};
        if(op inside {LH,LHU,SH}) imm%2==0;
        if(op inside {LW,SW}) imm%4==0;
      }
      if(op==JALR) {rs1==20; imm inside {[0:252]}; imm%4==0;}
      // Keep the memory/JALR base stable in randomized traffic.
      if(writes_rd(op)) rd!=20;
    }
    function bit [31:0] encode();
      bit [6:0] opc, f7;
      bit [2:0] f3;
      bit [31:0] v;
      opc=7'h33; f7=0; f3=0; v=32'(imm);
      case(op)
        ADD,SUB,ADDI: begin f3=0; if(op==SUB) f7=7'h20; end
        SLL,SLLI: f3=1;
        SLT,SLTI: f3=2;
        SLTU,SLTIU: f3=3;
        XOR_OP,XORI: f3=4;
        SRL,SRLI,SRA,SRAI: begin f3=5; if(op inside {SRA,SRAI}) f7=7'h20; end
        OR_OP,ORI: f3=6;
        AND_OP,ANDI: f3=7;
        LB,SB,BEQ: f3=0;
        LH,SH,BNE: f3=1;
        LW,SW: f3=2;
        LBU,BLT: f3=4;
        LHU,BGE: f3=5;
        BLTU: f3=6;
        BGEU: f3=7;
        default: f3=0;
      endcase
      if(op inside {[ADDI:ANDI]}) begin
        if(op inside {SLLI,SRLI,SRAI}) v={20'b0,f7,imm[4:0]};
        return {v[11:0],rs1,f3,rd,7'h13};
      end
      if(is_load(op) || op==JALR)
        return {v[11:0],rs1,(op==JALR ? 3'b0:f3),rd,(op==JALR ? 7'h67:7'h03)};
      if(is_store(op)) return {v[11:5],rs2,rs1,f3,v[4:0],7'h23};
      if(is_branch(op)) return {v[12],v[10:5],rs2,rs1,f3,v[4:1],v[11],7'h63};
      if(op inside {LUI,AUIPC}) return {v[19:0],rd,(op==LUI ? 7'h37:7'h17)};
      if(op==JAL) return {v[20],v[10:1],v[11],v[19:12],rd,7'h6f};
      if(op==MULX) opc=7'h0b;
      return {f7,rs2,rs1,f3,rd,opc};
    endfunction
  endclass

  class rv_observation;
    logic [31:0] instr, pc, next_pc, address, store_data, load_data;
    logic memwrite, regwrite;
    logic [31:0] writeback, regs[32];
  endclass

  class rv_generator;
    mailbox #(rv_transaction) outbox;
    function new(mailbox #(rv_transaction) outbox); this.outbox=outbox; endfunction
    task emit(operation_t op, int rd=3, int rs1=1, int rs2=2, int imm=0);
      rv_transaction t=new;
      t.op=op; t.rd=5'(rd); t.rs1=5'(rs1); t.rs2=5'(rs2); t.imm=imm;
      t.label=op.name(); outbox.put(t);
    endtask
    task set_reg(int rd, bit [31:0] value);
      bit [31:0] upper;
      int signed lower;
      lower=$signed({{20{value[11]}},value[11:0]});
      upper=(value+32'h800)>>12;
      emit(LUI,rd,0,0,int'(upper));
      emit(ADDI,rd,rd,0,lower);
    endtask
    task run(int random_count);
      rv_transaction t;
      bit [31:0] edges[6]='{0,1,32'hffffffff,32'h80000000,32'h7fffffff,32'h12345678};
      
      // Register selection coverage and immediate signs.
      for(int r=0;r<32;r++) begin
        emit(ADDI,r,0,0,r);
        emit(ADD,3,r,(r+1)%32);
      end
      // Every supported operation, with boundary operands and immediates.
      for(int k=0;k<OP_COUNT;k++) begin
        operation_t op=operation_t'(k);
        if(is_load(op) || is_store(op) || is_branch(op)) continue;
        for(int e=0;e<6;e++) begin
          set_reg(1,edges[e]); set_reg(2,edges[e]);
          case(op)
            JAL: emit(op,3,1,2,(e%2==0 ? 8:-8));
            JALR: begin set_reg(1,32'h400); emit(op,3,1,2,(e%2==0 ? 1:-3)); end
            LUI,AUIPC: emit(op,3,1,2,(e%2==0 ? 20'h80000:20'h7ffff));
            SLLI,SRLI,SRAI: emit(op,3,1,2,e);
            default: emit(op,3,1,2,(e%3==0 ? 0:(e%3==1 ? 37:-37)));
          endcase
        end
      end
      // All shift amounts, including 0 and 31, for each shift instruction.
      set_reg(1,32'h80000001);
      for(int sh=0;sh<32;sh++) begin
        set_reg(2,32'(sh));
        emit(SLL); emit(SRL); emit(SRA);
        emit(SLLI,3,1,0,sh); emit(SRLI,3,1,0,sh); emit(SRAI,3,1,0,sh);
      end
      // Every branch condition x taken/not-taken x positive/negative offset.
      for(int b=0;b<6;b++) for(int taken=0;taken<2;taken++) begin
        operation_t op=operation_t'(int'(BEQ)+b);
        set_reg(1,1);
        case(op)
          BEQ: set_reg(2,taken ? 1:2);
          BNE: set_reg(2,taken ? 2:1);
          BLT,BLTU: set_reg(2,taken ? 2:0);
          BGE,BGEU: set_reg(2,taken ? 0:2);
          default: ;
        endcase
        emit(op,0,1,2,8); emit(op,0,1,2,-8);
      end
      // Signed versus unsigned branch comparisons across the sign boundary.
      set_reg(1,32'hffffffff); set_reg(2,1);
      emit(BLT,0,1,2,8); emit(BGE,0,1,2,8);
      emit(BLTU,0,1,2,8); emit(BGEU,0,1,2,8);
      // All legal byte lanes and memory sizes. Overlapping stores are deliberate.
      set_reg(20,32'h200); set_reg(2,32'h80ff817e);
      for(int lane=0;lane<4;lane++) begin
        emit(SW,0,20,2,0);
        emit(LB,3,20,0,lane); emit(LBU,4,20,0,lane);
        emit(SB,0,20,2,lane); emit(LB,3,20,0,lane);
      end
      for(int lane=0;lane<4;lane+=2) begin
        emit(SH,0,20,2,lane); emit(LH,3,20,0,lane); emit(LHU,4,20,0,lane);
      end
      emit(SW,0,20,2,0); emit(LW,3,20,0,0);
      emit(SW,0,20,2,-4); emit(LW,0,20,0,-4);
      // Real instruction-fetch program, selected by actual PC, runs separately.
      for(int n=0;n<random_count;n++) begin
        t=new;
        assert(t.randomize()) else $fatal(1,"Randomization failed");
        t.label="random"; outbox.put(t);
      end
      t=new; t.stop=1; outbox.put(t);
    endtask
  endclass

  class rv_driver;
    virtual rv_if vif;
    mailbox #(rv_transaction) inbox;
    mailbox #(bit) ack;
    byte unsigned memory[MEM_SIZE];
    int driven=0;
    function new(virtual rv_if vif, mailbox #(rv_transaction) inbox, mailbox #(bit) ack);
      this.vif=vif; this.inbox=inbox; this.ack=ack;
      foreach(memory[i]) memory[i]=8'(i ^ (i>>4) ^ 8'ha5);
    endfunction
    task reset_dut();
      @(negedge vif.clk); vif.valid=0; vif.reset=1; vif.instr=32'h13;
      repeat(3) @(posedge vif.clk);
      @(negedge vif.clk); // Keep reset active until the first instruction is driven.
    endtask
    task drive_word(bit [31:0] word);
      bit accepted;
      bit [31:0] address, raw;
      int count;
      @(negedge vif.clk);
      vif.reset=0; vif.instr=word; vif.valid=1; vif.readdata=0;
      #1;
      address=vif.aluresult;
      if(word[6:0]==7'h03) begin
        count=(word[14:12] inside {0,4}) ? 1:((word[14:12] inside {1,5}) ? 2:4);
        assert(address <= MEM_SIZE-count) else $fatal(1,"Driver load out of range %h",address);
        raw=0;
        for(int j=0;j<count;j++) raw[j*8+:8]=memory[address+j];
        case(word[14:12])
          0: vif.readdata={{24{raw[7]}},raw[7:0]};
          1: vif.readdata={{16{raw[15]}},raw[15:0]};
          default: vif.readdata=raw;
        endcase
      end
      @(posedge vif.clk);
      if(vif.memwrite) begin
        address=vif.aluresult;
        count=(vif.memfunct3==0) ? 1:((vif.memfunct3==1) ? 2:4);
        assert(address <= MEM_SIZE-count) else $fatal(1,"Driver store out of range %h",address);
        for(int j=0;j<count;j++) memory[address+j]=vif.writedata[j*8+:8];
      end
      ack.get(accepted); driven++;
    endtask
    task run();
      rv_transaction t;
      forever begin
        inbox.get(t);
        if(t.stop) break;
        drive_word(t.encode());
      end
      @(negedge vif.clk); vif.valid=0; vif.instr=32'h13;
    endtask
    task run_program();
      bit [31:0] program_words[9];
      rv_transaction t=new;
      // x1=5, x2=0, loop {x2+=x1; x1--; if(x1!=0) loop;}, store sum, load, jump.
      t.op=ADDI; t.rd=1; t.rs1=0; t.imm=5; program_words[0]=t.encode();
      t.rd=2; t.imm=0; program_words[1]=t.encode();
      t.op=ADD; t.rd=2; t.rs1=2; t.rs2=1; program_words[2]=t.encode();
      t.op=ADDI; t.rd=1; t.rs1=1; t.imm=-1; program_words[3]=t.encode();
      t.op=BNE; t.rs1=1; t.rs2=0; t.imm=-8; program_words[4]=t.encode();
      t.op=SW; t.rs1=0; t.rs2=2; t.imm=64; program_words[5]=t.encode();
      t.op=LW; t.rd=3; t.rs1=0; t.imm=64; program_words[6]=t.encode();
      t.op=JAL; t.rd=4; t.imm=4; program_words[7]=t.encode();
      t.op=ADDI; t.rd=0; t.rs1=0; t.imm=0; program_words[8]=t.encode();
      for(int steps=0;steps<40;steps++) begin
        bit [31:0] fetch_pc=vif.pc;
        assert(fetch_pc[1:0]==0 && fetch_pc<36) else $fatal(1,"Program fetch PC %h",fetch_pc);
        drive_word(program_words[fetch_pc>>2]);
        if(fetch_pc==32) begin
          assert(vif.regs[3]==15) else $fatal(1,"Program sum expected 15");
          @(negedge vif.clk); vif.valid=0; vif.instr=32'h13; return;
        end
      end
      $fatal(1,"Program watchdog");
    endtask
  endclass

  class rv_monitor;
    virtual rv_if vif;
    mailbox #(rv_observation) outbox;
    function new(virtual rv_if vif, mailbox #(rv_observation) outbox);
      this.vif=vif; this.outbox=outbox;
    endfunction
    task run();
      forever begin
        rv_observation o;
        @(posedge vif.clk);
        if(vif.reset || !vif.valid) continue;
        o=new;
        o.instr=vif.instr; o.pc=vif.pc;
        o.address=vif.aluresult; o.store_data=vif.writedata; o.load_data=vif.readdata;
        o.memwrite=vif.memwrite; o.regwrite=vif.regwrite_debug; o.writeback=vif.result_debug;
        #1; // Observe register and PC nonblocking assignments after they settle.
        o.next_pc=vif.pc;
        foreach(o.regs[i]) o.regs[i]=vif.regs[i];
        outbox.put(o);
      end
    endtask
  endclass

  class rv_reference_model;
    bit [31:0] regs[32];
    byte unsigned memory[MEM_SIZE];
    bit [31:0] pc;
    operation_t op;
    bit [31:0] a,b,result,address;
    int signed imm;
    int rd,rs1,rs2;
    bit branch_taken, regwrite, memwrite;
    function new();
      reset();
      foreach(memory[i]) memory[i]=8'(i ^ (i>>4) ^ 8'ha5);
    endfunction
    function void reset(); pc=0; foreach(regs[i]) regs[i]=0; endfunction
    function void execute(bit [31:0] ins);
      bit [6:0] opcode;
      bit [2:0] f3;
      bit [31:0] next_pc,raw;
      int count;
      opcode=ins[6:0]; f3=ins[14:12]; rd=int'(ins[11:7]); rs1=int'(ins[19:15]); rs2=int'(ins[24:20]);
      a=regs[rs1]; b=regs[rs2]; result=0; address=0; imm=0;
      branch_taken=0; regwrite=1; memwrite=0; next_pc=pc+4;
      case(opcode)
        7'h33,7'h13: begin
          if(opcode==7'h13) begin
            imm=$signed(ins[31:20]); b=32'(imm);
          end
          case(f3)
            0: begin
              if(opcode==7'h33 && ins[30]) begin op=SUB; result=a-b; end
              else begin op=(opcode==7'h13 ? ADDI:ADD); result=a+b; end
            end
            1: begin op=(opcode==7'h13 ? SLLI:SLL); result=a<<b[4:0]; end
            2: begin op=(opcode==7'h13 ? SLTI:SLT); result=32'($signed(a)<$signed(b)); end
            3: begin op=(opcode==7'h13 ? SLTIU:SLTU); result=32'(a<b); end
            4: begin op=(opcode==7'h13 ? XORI:XOR_OP); result=a^b; end
            5: begin
              if(ins[30]) begin op=(opcode==7'h13 ? SRAI:SRA); result=$signed(a)>>>b[4:0]; end
              else begin op=(opcode==7'h13 ? SRLI:SRL); result=a>>b[4:0]; end
            end
            6: begin op=(opcode==7'h13 ? ORI:OR_OP); result=a|b; end
            7: begin op=(opcode==7'h13 ? ANDI:AND_OP); result=a&b; end
          endcase
        end
        7'h03,7'h23: begin
          if(opcode==7'h03) imm=$signed(ins[31:20]);
          else imm=$signed({ins[31:25],ins[11:7]});
          address=a+32'(imm);
          count=(f3 inside {0,4}) ? 1:((f3 inside {1,5}) ? 2:4);
          assert(address<=MEM_SIZE-count) else $fatal(1,"Reference memory range");
          assert((address % count)==0) else $fatal(1,"Misaligned generated access");
          if(opcode==7'h23) begin
            memwrite=1; regwrite=0;
            case(f3) 0:op=SB; 1:op=SH; 2:op=SW; default:$fatal(1,"Illegal store"); endcase
            for(int j=0;j<count;j++) memory[address+j]=b[j*8+:8];
          end else begin
            raw=0;
            for(int j=0;j<count;j++) raw[j*8+:8]=memory[address+j];
            case(f3)
              0:begin op=LB; result={{24{raw[7]}},raw[7:0]}; end
              1:begin op=LH; result={{16{raw[15]}},raw[15:0]}; end
              2:begin op=LW; result=raw; end
              4:begin op=LBU; result=raw; end
              5:begin op=LHU; result=raw; end
              default:$fatal(1,"Illegal load");
            endcase
          end
        end
        7'h63: begin
          regwrite=0; imm=$signed({ins[31],ins[7],ins[30:25],ins[11:8],1'b0});
          case(f3)
            0:begin op=BEQ; branch_taken=a==b; end
            1:begin op=BNE; branch_taken=a!=b; end
            4:begin op=BLT; branch_taken=$signed(a)<$signed(b); end
            5:begin op=BGE; branch_taken=$signed(a)>=$signed(b); end
            6:begin op=BLTU; branch_taken=a<b; end
            7:begin op=BGEU; branch_taken=a>=b; end
            default:$fatal(1,"Illegal branch");
          endcase
          if(branch_taken) next_pc=pc+32'(imm);
        end
        7'h37:begin op=LUI; result={ins[31:12],12'b0}; end
        7'h17:begin op=AUIPC; result=pc+{ins[31:12],12'b0}; end
        7'h6f:begin
          op=JAL; imm=$signed({ins[31],ins[19:12],ins[20],ins[30:21],1'b0});
          result=pc+4; next_pc=pc+32'(imm);
        end
        7'h67:begin
          op=JALR; imm=$signed(ins[31:20]); result=pc+4; next_pc=(a+32'(imm))&32'hfffffffe;
        end
        7'h0b:begin op=MULX; result=a*b; end
        default:$fatal(1,"Unsupported instruction %h",ins);
      endcase
      if(regwrite && rd!=0) regs[rd]=result;
      regs[0]=0; pc=next_pc;
    endfunction
  endclass

  class rv_coverage;
    bit op_hit[OP_COUNT], rs1_hit[32], rs2_hit[32], rd_hit[32];
    bit branch_hit[24], load_hit[13], store_hit[7], shift_hit[192];
    bit operand_a_hit[6],operand_b_hit[6],imm_hit[3];
    int samples=0;
`ifdef ENABLE_COVERGROUPS
    covergroup cg with function sample(int op,int rs1,int rs2,int rd,
      bit use1,bit use2,bit wr,int branch_bin,int load_bin,int store_bin,
      int shift_amount,int ac,int bc,int immediate_class);
      option.per_instance=1;
      cp_op: coverpoint op {bins supported[]={[0:37]};}
      cp_rs1: coverpoint rs1 iff(use1) {bins registers[]={[0:31]};}
      cp_rs2: coverpoint rs2 iff(use2) {bins registers[]={[0:31]};}
      cp_rd: coverpoint rd iff(wr) {bins registers[]={[0:31]};}
      cp_branch: coverpoint branch_bin iff(branch_bin>=0) {bins subtype_outcome_direction[]={[0:23]};}
      cp_load: coverpoint load_bin iff(load_bin>=0) {bins type_lane[]={[0:12]};}
      cp_store: coverpoint store_bin iff(store_bin>=0) {bins type_lane[]={[0:6]};}
      cp_shift: coverpoint shift_amount iff(shift_amount>=0) {bins operation_amount[]={[0:191]};}
      cp_a: coverpoint ac iff(use1) {bins values[]={[0:5]};}
      cp_b: coverpoint bc iff(use2) {bins values[]={[0:5]};}
      cp_imm: coverpoint immediate_class iff(immediate_class>=0) {bins signs[]={[0:2]};}
    endgroup
`endif
    function new();
`ifdef ENABLE_COVERGROUPS
      cg=new;
`endif
    endfunction
    function int value_class(bit [31:0] value);
      case(value)
        0:return 0; 1:return 1; 32'hffffffff:return 2;
        32'h80000000:return 3; 32'h7fffffff:return 4; default:return 5;
      endcase
    endfunction
    function void sample(rv_reference_model m);
      int bb=-1,lb=-1,sb=-1,sh=-1,ic=-1;
      int ac,bc;
      op_hit[int'(m.op)]=1; samples++;
      ac=value_class(m.a); bc=value_class(m.b);
      if(uses_rs1(m.op)) begin rs1_hit[m.rs1]=1; operand_a_hit[ac]=1; end
      if(uses_rs2(m.op)) begin rs2_hit[m.rs2]=1; operand_b_hit[bc]=1; end
      if(writes_rd(m.op)) rd_hit[m.rd]=1;
      if(is_branch(m.op)) begin
        bb=(int'(m.op)-int'(BEQ))*4+int'(m.branch_taken)*2+int'(m.imm<0);
        branch_hit[bb]=1;
      end
      case(m.op)
        LB:lb=int'(m.address[1:0]); LBU:lb=4+int'(m.address[1:0]);
        LH:lb=8+int'(m.address[1]); LHU:lb=10+int'(m.address[1]); LW:lb=12;
        default:;
      endcase
      if(lb>=0) load_hit[lb]=1;
      case(m.op)
        SB:sb=int'(m.address[1:0]); SH:sb=4+int'(m.address[1]); SW:sb=6;
        default:;
      endcase
      if(sb>=0) store_hit[sb]=1;
      if(is_shift(m.op)) begin
        case(m.op)
          SLL:sh=0; SRL:sh=1; SRA:sh=2;
          SLLI:sh=3; SRLI:sh=4; SRAI:sh=5;
          default:sh=0;
        endcase
        sh=sh*32+int'(m.b[4:0]); shift_hit[sh]=1;
      end
      if(m.op inside {[ADDI:ANDI]} || is_load(m.op) || is_store(m.op) || is_branch(m.op) || m.op inside {JAL,JALR}) begin
        ic=(m.imm==0 ? 0:(m.imm>0 ? 1:2)); imm_hit[ic]=1;
      end
`ifdef ENABLE_COVERGROUPS
      cg.sample(int'(m.op),m.rs1,m.rs2,m.rd,uses_rs1(m.op),uses_rs2(m.op),
        writes_rd(m.op),bb,lb,sb,sh,ac,bc,ic);
`endif
    endfunction
    function void report();
      int hit=0,total=0;
      real pct;
      foreach(op_hit[i]) begin total++; hit+=int'(op_hit[i]); if(!op_hit[i]) $display("HOLE operation %0d",i); end
      foreach(rs1_hit[i]) begin total++; hit+=int'(rs1_hit[i]); end
      foreach(rs2_hit[i]) begin total++; hit+=int'(rs2_hit[i]); end
      foreach(rd_hit[i]) begin total++; hit+=int'(rd_hit[i]); end
      foreach(branch_hit[i]) begin total++; hit+=int'(branch_hit[i]); end
      foreach(load_hit[i]) begin total++; hit+=int'(load_hit[i]); end
      foreach(store_hit[i]) begin total++; hit+=int'(store_hit[i]); end
      foreach(shift_hit[i]) begin total++; hit+=int'(shift_hit[i]); end
      foreach(operand_a_hit[i]) begin total++; hit+=int'(operand_a_hit[i]); end
      foreach(operand_b_hit[i]) begin total++; hit+=int'(operand_b_hit[i]); end
      foreach(imm_hit[i]) begin total++; hit+=int'(imm_hit[i]); end
      pct=100.0*real'(hit)/real'(total);
      $display("FUNCTIONAL COVERAGE %0d/%0d = %0.2f%% (%0d checked instructions)",hit,total,pct,samples);
`ifdef ENABLE_COVERGROUPS
      $display("NATIVE COVERGROUP %0.2f%%",cg.get_inst_coverage());
      assert(cg.get_inst_coverage()>92.0) else $fatal(1,"Native coverage below target");
`endif
      assert(pct>92.0) else $fatal(1,"Functional coverage below target");
      foreach(op_hit[i]) assert(op_hit[i]) else $fatal(1,"Missing operation %0d",i);
    endfunction
  endclass

  class rv_scoreboard;
    mailbox #(rv_observation) inbox;
    mailbox #(bit) ack;
    rv_reference_model model;
    rv_coverage coverage;
    int checked=0;
    function new(mailbox #(rv_observation) inbox,mailbox #(bit) ack,rv_coverage coverage);
      this.inbox=inbox; this.ack=ack; this.coverage=coverage; model=new;
    endfunction
    task run();
      forever begin
        rv_observation o;
        inbox.get(o);
        assert(o.pc===model.pc) else $fatal(1,"PC before instr=%h actual=%h expected=%h",o.instr,o.pc,model.pc);
        model.execute(o.instr);
        assert(o.memwrite===model.memwrite) else $fatal(1,"Memory write enable instr=%h",o.instr);
        assert(o.regwrite===model.regwrite) else $fatal(1,"Register write enable instr=%h",o.instr);
        if(model.regwrite)
          assert(o.writeback===model.result) else $fatal(1,"Writeback %s pc=%h actual=%h expected=%h",model.op.name(),o.pc,o.writeback,model.result);
        if(is_load(model.op) || is_store(model.op))
          assert(o.address===model.address) else $fatal(1,"Address actual=%h expected=%h",o.address,model.address);
        if(is_load(model.op))
          assert(o.load_data===model.result) else $fatal(1,"Load response mismatch");
        if(is_store(model.op))
          assert(o.store_data===model.b) else $fatal(1,"Store data mismatch");
        assert(o.next_pc===model.pc) else $fatal(1,"Next PC %s actual=%h expected=%h",model.op.name(),o.next_pc,model.pc);
        foreach(o.regs[i])
          assert(o.regs[i]===model.regs[i]) else $fatal(1,"%s pc=%h x%0d actual=%h expected=%h",model.op.name(),o.pc,i,o.regs[i],model.regs[i]);
        coverage.sample(model); checked++; ack.put(1);
      end
    endtask
  endclass

  class rv_agent;
    rv_generator generator;
    rv_driver driver;
    rv_monitor monitor;
    mailbox #(rv_transaction) stimulus;
    mailbox #(rv_observation) observations;
    mailbox #(bit) ack;
    function new(virtual rv_if vif);
      stimulus=new; observations=new; ack=new;
      generator=new(stimulus); driver=new(vif,stimulus,ack); monitor=new(vif,observations);
    endfunction
  endclass

  class rv_environment;
    rv_agent agent;
    rv_scoreboard scoreboard;
    rv_coverage coverage;
    function new(virtual rv_if vif);
      agent=new(vif); coverage=new; scoreboard=new(agent.observations,agent.ack,coverage);
    endfunction
    task run(int random_count);
      agent.driver.reset_dut(); scoreboard.model.reset();
      fork
        agent.monitor.run();
        scoreboard.run();
      join_none
      fork
        agent.generator.run(random_count);
        agent.driver.run();
      join
      // A second reset verifies restart after a populated register file.
      agent.driver.reset_dut(); scoreboard.model.reset();
      agent.driver.run_program();
      assert(scoreboard.checked==agent.driver.driven) else $fatal(1,"Dropped observation");
      coverage.report();
      $display("PASS: %0d instructions checked, including PC-fetched loop program",scoreboard.checked);
    endtask
  endclass
  class rv_test;
    rv_environment env;
    function new(virtual rv_if vif); env=new(vif); endfunction
    task run(int random_count); env.run(random_count); endtask
  endclass
endpackage

module tb_rv_layered;
  import rv_tb_pkg::*;
  bit clk=0;
  always #5 clk=~clk;
  rv_if bus(clk);
  rv_test test;
  rv32i_single dut(
    .clk(clk),.reset(bus.reset),.pc(bus.pc),.instr(bus.instr),
    .memwrite(bus.memwrite),.memfunct3(bus.memfunct3),.aluresult(bus.aluresult),
    .writedata(bus.writedata),.readdata(bus.readdata)
  );
  for(genvar g=0;g<32;g++) begin: debug_registers
    assign bus.regs[g]=dut.u_datapath.u_register_file.register[g];
  end
  assign bus.nextpc_debug=dut.u_datapath.pcnext;
  assign bus.regwrite_debug=dut.regwrite;
  assign bus.result_debug=dut.u_datapath.result;
  initial begin
    int random_count=500;
    void'($value$plusargs("RANDOM_COUNT=%d",random_count));
    if($test$plusargs("vcd")) begin $dumpfile("rv_layered.vcd"); $dumpvars(0,tb_rv_layered); end
    test=new(bus); test.run(random_count); $finish;
  end
  initial begin #1000000; $fatal(1,"Global simulation watchdog"); end
endmodule
