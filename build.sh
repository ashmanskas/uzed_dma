#! /bin/bash
. clean.sh
. /cad/Xilinx/Vivado/2017.2/settings64.sh
export LM_LICENSE_FILE=1700@head
time vivado -mode batch -source foobar.tcl
. /opt/Xilinx/14.7/ISE_DS/settings64.sh
promgen -b -w -p bin -data_width 32 -u 0 \
  project/project.runs/impl_1/bd_wrapper.bit -o uzed_dma.bin

