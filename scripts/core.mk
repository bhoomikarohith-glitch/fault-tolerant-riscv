# =============================================================================
# core.mk  -  Build and test rules for the core                      (row 20)
# -----------------------------------------------------------------------------
# Included by the top-level Makefile, so every target runs as  make <target>
# from the repository root.
#
#   make test        run every test (4 programs + 40 riscv-tests), print a summary
#   make sim         run rv32i_smoke.S only
#   make sim PROG=fibonacci PASS_VAL=6765
#                    run software/tests/<PROG>.S, expecting signature PASS_VAL
#   make sim VCD=1   also save cpu_top_tb.vcd for GTKWave
#   make sim-mem MEM=prog.mem SIG_ADDR=100 PASS_VAL=25
#                    run a ready-made .mem file
#   make ecc-test    unit test of the SECDED encoder
#   make clean       delete everything that was built
#
# MAKE BASICS (used below)
#   .RECIPEPREFIX = >         command lines start with '>' instead of a tab
#                              (so copy-pasting can't break them)
#   target: prerequisites      "to build target, first build prerequisites"
#   > command                  how to build it
#   %                          wildcard in a pattern rule (%.mem matches foo.mem)
#   $@  the target   $<  the first prerequisite   $*  what % matched
#   VAR ?= x                   default value, overridable: make sim PROG=foo
#   | dir                      "order-only": the directory must exist first
# =============================================================================

# Command lines below start with '>' instead of a tab.
.RECIPEPREFIX = >

# ------------------------------------------------------------------ settings
# (Comments sit on their own lines: in make, text before a # on the same
#  line becomes part of the value, trailing spaces included.)

# program for `make sim`
PROG     ?= rv32i_smoke
# all generated files go here
BUILD    := build
# RISC-V toolchain prefix (gcc, objcopy, objdump)
CROSS    ?= riscv64-unknown-elf-
# target: 32-bit base integer ISA only
ARCH     := -march=rv32i -mabi=ilp32
# signature address 0xFFC, written in decimal
SIG_ADDR ?= 4092
# expected signature for `make sim`
PASS_VAL ?= 1

# Every RTL file. The package goes first because other files import it.
PKG := rtl/common/rv_pkg.sv
RTL := $(PKG) \
       $(filter-out $(PKG),$(wildcard rtl/common/*.sv)) \
       $(wildcard rtl/core/*.sv) \
       $(wildcard rtl/memory/*.sv) \
       rtl/cpu_top.sv
TB  := tb/system/cpu_top_tb.sv

# Icarus Verilog in SystemVerilog-2012 mode, all warnings except timescale.
IVERILOG := iverilog -g2012 -Wall -Wno-timescale

# +vcd makes the testbench save a waveform (only when VCD=1 is given).
VVP_FLAGS := $(if $(VCD),+vcd,)

# ---------------------------------------------------------------- test lists
# Our own programs, as name:expected-signature.
PROGRAMS := rv32i_smoke:1 array_sum:64 fibonacci:6765 bubble_sort:8111

# Official riscv-tests, pinned to one commit so results never change under us.
# Left out: fence_i (needs the Zifencei extension) and ma_data (misaligned
# accesses); this core supports neither.
RVT_DIR    := third_party/riscv-tests
RVT_URL    := https://github.com/riscv-software-src/riscv-tests.git
RVT_COMMIT := 3df703cd52d5f0d8224e3c50bf03c6cb70efff98
RVT_ENV    := verification/riscv-tests-env
RVT_TESTS  := add addi and andi auipc beq bge bgeu blt bltu bne jal jalr \
              lb lbu ld_st lh lhu lui lw or ori sb sh simple sll slli slt \
              slti sltiu sltu sra srai srl srli st_ld sub sw xor xori

# The .mem files `make test` needs, e.g. build/fibonacci.mem, build/rv32ui-add.mem
PROG_MEMS := $(foreach p,$(PROGRAMS),$(BUILD)/$(firstword $(subst :, ,$(p))).mem)
RVT_MEMS  := $(foreach t,$(RVT_TESTS),$(BUILD)/rv32ui-$(t).mem)

# Make these variables visible to scripts/run_tests.sh.
export RTL TB IVERILOG

# Targets that are names of actions, not files.
.PHONY: sim sim-mem test ecc-test clean

$(BUILD):
>mkdir -p $(BUILD)

# ------------------------------------------------- our programs: .S -> .elf
# Assemble and link with code starting at address 0, no C library.
$(BUILD)/%.elf: software/tests/%.S | $(BUILD)
>$(CROSS)gcc $(ARCH) -nostdlib -nostartfiles -Wl,-Ttext=0 -o $@ $<

# ------------------------------------------------ riscv-tests: download once
# The first time, clone the repository and check out the pinned commit.
$(RVT_DIR)/isa/rv32ui/add.S:
>mkdir -p third_party
>git clone -q $(RVT_URL) $(RVT_DIR)
>git -C $(RVT_DIR) checkout -q $(RVT_COMMIT)

# ------------------------------------------------- riscv-tests: .S -> .elf
# -I adds include folders: our riscv_test.h, and the suite's test_macros.h.
# -T uses our linker script (everything from address 0).
$(BUILD)/rv32ui-%.elf: $(RVT_DIR)/isa/rv32ui/add.S $(RVT_ENV)/riscv_test.h $(RVT_ENV)/link.ld | $(BUILD)
>$(CROSS)gcc $(ARCH) -static -nostdlib -nostartfiles -Wl,--no-warn-rwx-segments \
>    -I$(RVT_ENV) -I$(RVT_DIR)/isa/macros/scalar -T$(RVT_ENV)/link.ld \
>    -o $@ $(RVT_DIR)/isa/rv32ui/$*.S

# --------------------------------------------- .elf -> .bin -> .mem (shared)
# objcopy strips the ELF wrapper, leaving the raw bytes of the program.
$(BUILD)/%.bin: $(BUILD)/%.elf
>$(CROSS)objcopy -O binary $< $@

# bin2mem.py turns raw bytes into one hex word per line, for $readmemh.
$(BUILD)/%.mem: $(BUILD)/%.bin
>python3 scripts/bin2mem.py $< $@

# Disassembly listing: handy for matching a failing PC to an instruction.
$(BUILD)/%.dis: $(BUILD)/%.elf
>$(CROSS)objdump -d $< > $@

# Keep intermediate files instead of deleting them after the build.
.SECONDARY:

# ----------------------------------------------------------- run one program
# -s cpu_top_tb      top module of the simulation
# -Pmodule.PARAM=x   override a testbench parameter from the command line
# vvp runs the compiled simulation; -n stops it waiting for input at the end.
sim: $(BUILD)/$(PROG).mem $(BUILD)/$(PROG).dis
>$(IVERILOG) -o $(BUILD)/sim.vvp -s cpu_top_tb \
>    -Pcpu_top_tb.MEM_FILE=\"$(BUILD)/$(PROG).mem\" \
>    -Pcpu_top_tb.SIG_ADDR=$(SIG_ADDR) -Pcpu_top_tb.PASS_VAL=$(PASS_VAL) \
>    $(RTL) $(TB)
>vvp -n $(BUILD)/sim.vvp $(VVP_FLAGS)

# Same, for a .mem file you already have (e.g. the textbook test program).
sim-mem: | $(BUILD)
>$(IVERILOG) -o $(BUILD)/sim.vvp -s cpu_top_tb \
>    -Pcpu_top_tb.MEM_FILE=\"$(MEM)\" \
>    -Pcpu_top_tb.SIG_ADDR=$(SIG_ADDR) -Pcpu_top_tb.PASS_VAL=$(PASS_VAL) \
>    $(RTL) $(TB)
>vvp -n $(BUILD)/sim.vvp $(VVP_FLAGS)

# --------------------------------------------------------------- run them all
# Build every .mem first, then hand the list to run_tests.sh.
# riscv-tests get ":data" so their image is also loaded into data memory.
test: $(PROG_MEMS) $(RVT_MEMS)
>bash scripts/run_tests.sh $(BUILD) $(PROGRAMS) \
>    $(foreach t,$(RVT_TESTS),rv32ui-$(t):1:data)

# --------------------------------------------------------------- ECC encoder
ecc-test: | $(BUILD)
>$(IVERILOG) -o $(BUILD)/ecc.vvp -s secded_enc_tb \
>    rtl/ecc/secded_enc.sv tb/unit/secded_enc_tb.sv
>vvp -n $(BUILD)/ecc.vvp

clean:
>rm -rf $(BUILD) cpu_top_tb.vcd
