SIM = icarus
TOPLEVEL_LANG = verilog
SIM_BUILD = build/
export PYTHONPATH := $(CURDIR)/tb:$(PYTHONPATH)

ifndef TEST
$(error TEST is required, for example: make TEST=alu)
endif

COMMON_SOURCES = \
	$(CURDIR)/rtl/pkg/rv32i_pkg.sv \
	$(CURDIR)/rtl/pkg/alu_pkg.sv \
	$(CURDIR)/rtl/pkg/controller_pkg.sv \
	$(CURDIR)/rtl/pkg/lsu_pkg.sv

CORE_SOURCE = $(CURDIR)/rtl/core/$(TEST).sv
MEMORY_SOURCE = $(CURDIR)/rtl/memory/$(TEST).sv

ifneq ($(wildcard $(CORE_SOURCE)),)
VERILOG_SOURCES = $(COMMON_SOURCES) $(CORE_SOURCE)
else
VERILOG_SOURCES = $(COMMON_SOURCES) $(MEMORY_SOURCE)
endif

COCOTB_TOPLEVEL = $(TEST)
COCOTB_TEST_MODULES = tb.$(TEST)_tb

WAVES = 1

include $(shell cocotb-config --makefiles)/Makefile.sim
