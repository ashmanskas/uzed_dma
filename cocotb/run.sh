export PATH=/cad/INCISIVE152-lnx/tools/bin:$PATH
export COCOTB=/home/ashmansk/l/code/cocotb
# export XILINX=/opt/Xilinx/14.7/ISE_DS/ISE
export ARCH=x86_64
export COCOTB_ANSI_OUTPUT=0
export COCOTB_REDUCED_LOG_FMT=1
if [ -e sim_build ]; then /bin/rm -rf sim_build; fi
export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libstdc++.so.6
make SIM=ius
