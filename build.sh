#! /bin/bash
. clean.sh
. /cad/Xilinx/Vivado/2017.2/settings64.sh
export LM_LICENSE_FILE=1700@head
python src/hdl/fw_timestamp.py
time vivado -mode batch -source foobar.tcl
. promgen.sh


