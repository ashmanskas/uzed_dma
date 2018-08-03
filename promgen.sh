#! /bin/bash
. /opt/Xilinx/14.7/ISE_DS/settings64.sh
promgen -b -w -p bin -data_width 32 -u 0 \
  project/project.runs/impl_1/top.bit -o uzed_dma.bin
/bin/rm uzed_dma.prm uzed_dma.cfi

