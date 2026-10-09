# Usage:
#   make ARCH=single_cycle|pipeline   integration test (tb/<ARCH>/<ARCH>_top_tb.py)
#   make TEST=<module>                unit test for one module (tb/<dir>/<module>_tb.py)
#   make TEST=<module> PARAMS="P=V"   unit test with top-level parameter overrides (space-separated)
#   make clean                        remove all build output
SIM = verilator
TOPLEVEL_LANG = verilog
export PYTHONPATH := $(CURDIR)/tb:$(PYTHONPATH)

PKG_SOURCES = \
	$(CURDIR)/rtl/pkg/rv32i_pkg.sv \
	$(CURDIR)/rtl/pkg/alu_pkg.sv \
	$(CURDIR)/rtl/pkg/lsu_pkg.sv \
	$(CURDIR)/rtl/pkg/controller_pkg.sv

ifdef TEST  # Unit test: <module> must match exactly one rtl/*/<module>.sv
	ifdef ARCH
        $(error Pass either TEST or ARCH, not both)
	endif
	TEST_SOURCES = $(wildcard $(CURDIR)/rtl/*/$(TEST).sv)
	ifneq ($(words $(TEST_SOURCES)),1)
        $(error TEST=$(TEST) must match exactly one rtl/*/$(TEST).sv, found: $(or $(TEST_SOURCES),none))
	endif
	TEST_DIR = $(notdir $(patsubst %/,%,$(dir $(TEST_SOURCES))))

	# One build directory per module and parameter set, so switching between them always rebuilds
	SIM_BUILD = build/unit/$(TEST)$(subst $() ,,$(addprefix _,$(PARAMS)))
	COMPILE_ARGS += $(addprefix -G,$(PARAMS))
	VERILOG_SOURCES = $(PKG_SOURCES) $(TEST_SOURCES)
	COCOTB_TOPLEVEL = $(TEST)
	COCOTB_TEST_MODULES = tb.$(TEST_DIR).$(TEST)_tb
else ifdef ARCH  # Architecture-specific integration test
	SIM_BUILD = build/$(ARCH)
	VERILOG_SOURCES = $(PKG_SOURCES) $(wildcard $(CURDIR)/rtl/common/*.sv) $(wildcard $(CURDIR)/rtl/$(ARCH)/*.sv)
	COCOTB_TOPLEVEL = $(ARCH)_top
	COCOTB_TEST_MODULES = tb.$(ARCH).$(ARCH)_top_tb
else ifeq ($(MAKECMDGOALS),clean)
	SIM_BUILD = build
else
    $(error ARCH or TEST is required, for example: make ARCH=single_cycle, or make TEST=alu)
endif

EXTRA_ARGS += --trace --trace-fst --trace-structs

include $(shell cocotb-config --makefiles)/Makefile.sim
