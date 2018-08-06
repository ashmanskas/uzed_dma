SIM ?= ius
VERILOG_SOURCES = \
  $(PWD)/tb.v \
  ../src/ip/wja_bus_lite/wja_bus_lite.v \
  ../src/hdl/myverilog.v \
  ../src/hdl/busio.v
# EXTRA_ARGS = \
#   -cdslib cds.lib \
#   +incdir+$(FW)
TOPLEVEL=tb
TOPLEVEL_LANG ?= verilog
MODULE=tb
include $(COCOTB)/makefiles/Makefile.inc
include $(COCOTB)/makefiles/Makefile.sim
