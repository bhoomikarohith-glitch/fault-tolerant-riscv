# =============================================================================
# Makefile  -  Top-level entry point                                 (row 20)
# -----------------------------------------------------------------------------
# All the rules live in scripts/core.mk; this file just pulls them in, so you
# can type  make test  from the repository root.
#
#   make test      run every test and print a summary
#   make sim       run one program (options listed in scripts/core.mk)
#   make ecc-test  unit test of the ECC encoder
#   make clean     delete everything that was built
# =============================================================================

include scripts/core.mk
