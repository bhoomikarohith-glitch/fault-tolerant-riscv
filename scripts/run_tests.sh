#!/usr/bin/env bash
# =============================================================================
# run_tests.sh  -  Run a list of test programs and print a summary   (row 20)
# -----------------------------------------------------------------------------
# Called by `make test`. For each test it compiles the simulation with that
# program's settings, runs it, and reads the PASS / FAIL line the testbench
# prints. At the end it prints totals, and exits with status 1 if anything
# failed (so CI shows a red cross).
#
# Usage: scripts/run_tests.sh BUILD_DIR TEST...
#   TEST = name:expected        program loaded into instruction memory only
#   TEST = name:expected:data   also loaded into data memory (riscv-tests keep
#                               their test data next to the code)
#
# IVERILOG, RTL and TB come from the environment (exported by core.mk).
# =============================================================================

set -u          # stop if a variable is used before being set (catches typos)

build=$1        # first argument: the build folder
shift           # drop it; "$@" is now just the list of tests

passed=0
failed=0
failures=()     # bash array of failing test names

for spec in "$@"; do

    # Split "name:expected:data" at the colons into three variables.
    IFS=: read -r name expected data <<< "$spec"

    mem="$build/$name.mem"
    datafile=""
    [ "${data:-}" = "data" ] && datafile="$mem"   # load data memory too?

    # Compile the simulation for this test. The \" make the file names
    # reach Verilog as quoted strings. Compiler output goes to a log file.
    if ! $IVERILOG -o "$build/$name.vvp" -s cpu_top_tb \
            -Pcpu_top_tb.MEM_FILE=\""$mem"\" \
            -Pcpu_top_tb.DATA_FILE=\""$datafile"\" \
            -Pcpu_top_tb.PASS_VAL="$expected" \
            $RTL $TB > "$build/$name.compile.log" 2>&1; then
        result="FAIL: does not compile (see $build/$name.compile.log)"
    else
        # Run it and keep only the first line starting with PASS or FAIL.
        result=$(vvp -n "$build/$name.vvp" 2>&1 | grep -E '^(PASS|FAIL)' | head -1)
        [ -z "$result" ] && result="FAIL: no result printed"
    fi

    # Count and print the outcome.
    if [[ "$result" == PASS* ]]; then
        passed=$((passed + 1))
        printf '  PASS  %s\n' "$name"
    else
        failed=$((failed + 1))
        failures+=("$name")
        printf '  FAIL  %s  -> %s\n' "$name" "$result"
    fi
done

# ---------------------------------------------------------------- summary
echo
echo "  $passed passed, $failed failed, $((passed + failed)) total"
if [ "$failed" -ne 0 ]; then
    echo "  Failed: ${failures[*]}"
    echo "  riscv-tests failures store (case << 1) | 1: divide (signature - 1) by 2"
    echo "  to get the failing TEST_CASE number in the test's .S file."
    exit 1      # non-zero exit = failure, for make and CI
fi
