SIM ?= ius
VERILOG_SOURCES = \
  $(PWD)/tb.v \
  ../src/ip/wja_bus_lite/wja_bus_lite.v \
  ../src/hdl/myverilog.v \
  ../src/hdl/busio.v
EXTRA_ARGS = \
  +incdir+../src/hdl/
TOPLEVEL=tb
TOPLEVEL_LANG ?= verilog
MODULE=tb
include $(COCOTB)/makefiles/Makefile.inc
include $(COCOTB)/makefiles/Makefile.sim
