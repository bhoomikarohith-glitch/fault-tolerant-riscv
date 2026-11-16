Yosys synthesis of uploaded fault-tolerant-riscv RTL
Top: rv32i_single. Includes controller, datapath, register file, Booth multiplier and compressor tree. Instruction/data memories and memory ECC are outside this core top and excluded.
Tool: YoWASP Yosys 0.71. Generic Boolean synthesis, synth -noabc; no cell library, physical layout, area in um^2 or timing results. 19,155 generic primitive cells including 1,056 register bits. Hierarchy retained; multiplier upper bits may remain inside hierarchy even though ALU consumes only 32 bits. Counts are specific to this flow, not an optimized flattened ASIC estimate.
check -assert passed before and after synthesis. This is structural validation, not proof of instruction execution or multiplier arithmetic correctness. No functional simulation or equivalence proof was run.
Compatibility copies inline rv_pkg localparams at import sites and replace signed'(A) with $signed(A); original uploaded sources were not modified. These are frontend compatibility transformations; no functional fixes intended.
run.ys reproduces the synthesis from the parent directory containing synthesis/. Install yowasp-yosys first.
core_netlist.v: generic gate-level hierarchical netlist.
core_synth.json: post-synthesis machine-readable netlist.
core_rtl.json: optimized word-level intermediate before gate lowering.
datapath.svg/png: word-level hierarchy view (before gate lowering).
pc_gates.svg/png: actual post-synthesis primitive view of the 32-bit PC register.
statistics.txt and synthesis.log: tool reports and structural checks.
