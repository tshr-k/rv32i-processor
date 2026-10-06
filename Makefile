SIM = icarus
TOPLEVEL_LANG = verilog
SIM_BUILD = build/

VERILOG_SOURCES = \
	$(CURDIR)/rtl/pkg/rv32i_pkg.sv \
	$(CURDIR)/rtl/pkg/alu_pkg.sv \
	$(CURDIR)/rtl/core/alu.sv

COCOTB_TOPLEVEL = alu
COCOTB_TEST_MODULES = tb.alu_tb

WAVES = 1

include $(shell cocotb-config --makefiles)/Makefile.sim
