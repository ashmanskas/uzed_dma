set dir [pwd]
create_project project $dir/project -part xc7z020clg400-1 -force
set_property board_part em.avnet.com:microzed_7020:part0:1.1 [current_project]
ipx::infer_core -vendor user.org -library user -taxonomy /UserIP \
    -root_dir $dir/ip_repo/wja_axis $dir/src/ip/wja_axis
ipx::edit_ip_in_project -upgrade true -name edit_ip_project \
    -directory $dir/project/proj.tmp $dir/ip_repo/wja_axis/component.xml
ipx::current_core $dir/ip_repo/wja_axis/component.xml
set_property core_revision 2 [ipx::current_core]
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]
# ipx::archive_core $dir/ip_repo/wja_axis_1.0.zip [ipx::current_core]
close_project -delete
# set_property  ip_repo_paths  $dir/src/ip/wja_axis [current_project]
update_ip_catalog
ipx::infer_core -vendor user.org -library user -taxonomy /UserIP \
    -root_dir $dir/ip_repo/wja_bus_lite $dir/src/ip/wja_bus_lite
ipx::edit_ip_in_project -upgrade true -name edit_ip_project \
    -directory $dir/project/proj.tmp $dir/ip_repo/wja_bus_lite/component.xml
ipx::current_core $dir/ip_repo/wja_bus_lite/component.xml
set_property core_revision 2 [ipx::current_core]
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]
ipx::check_integrity -quiet [ipx::current_core]
# ipx::archive_core $dir/ip_repo/wja_bus_lite_1.0.zip [ipx::current_core]
close_project -delete
# set_property  ip_repo_paths  [list $dir/src/ip/wja_bus_lite $dir/src/ip/wja_axis] [current_project]
set_property ip_repo_paths $dir/ip_repo [current_project]
ipx::unload_core $dir/ip_repo/wja_bus_lite/component.xml
ipx::unload_core $dir/ip_repo/wja_axis/component.xml
update_ip_catalog

# ----------------------------------------------------------------------

create_bd_design bd
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 \
    processing_system7_0
endgroup
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXED_IO, DDR" apply_board_preset "1" \
                 Master "Disable" Slave "Disable" }  \
    [get_bd_cells processing_system7_0]
startgroup
set_property -dict [list CONFIG.PCW_USE_M_AXI_GP0 {1} \
                        CONFIG.PCW_USE_S_AXI_GP0 {0} \
                        CONFIG.PCW_USE_S_AXI_HP0 {1}] \
    [get_bd_cells processing_system7_0]
endgroup
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_0
endgroup
startgroup
set_property -dict [list CONFIG.c_include_sg {0} \
                        CONFIG.c_include_mm2s {0} \
                        CONFIG.c_include_s2mm {1} \
                        CONFIG.c_sg_include_stscntrl_strm {0}] \
    [get_bd_cells axi_dma_0]
endgroup
apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
    -config {Master "/axi_dma_0/M_AXI_S2MM" intc_ip "Auto" \
                 Clk_xbar "Auto" Clk_master "Auto" Clk_slave "Auto" }  \
    [get_bd_intf_pins processing_system7_0/S_AXI_HP0]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
    -config {Master "/processing_system7_0/M_AXI_GP0" \
                 intc_ip "New AXI Interconnect" Clk_xbar "Auto" \
                 Clk_master "Auto" Clk_slave "Auto" }  \
    [get_bd_intf_pins axi_dma_0/S_AXI_LITE]
regenerate_bd_layout

startgroup
create_bd_cell -type ip -vlnv user.org:user:wja_axis:1.0 wja_axis_0
endgroup
connect_bd_intf_net [get_bd_intf_pins wja_axis_0/m00_axis] \
    [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM]
apply_bd_automation -rule xilinx.com:bd_rule:clkrst \
    -config {Clk "/processing_system7_0/FCLK_CLK0 (100 MHz)" }  \
    [get_bd_pins wja_axis_0/m00_axis_aclk]
startgroup
create_bd_cell -type ip -vlnv user.org:user:wja_bus_lite:1.0 wja_bus_lite_0
endgroup
apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
    -config {Master "/processing_system7_0/M_AXI_GP0" \
                 intc_ip "/ps7_0_axi_periph" Clk_xbar "Auto" \
                 Clk_master "Auto" Clk_slave "Auto" }  \
    [get_bd_intf_pins wja_bus_lite_0/s00_axi]
regenerate_bd_layout
validate_bd_design
save_bd_design
make_wrapper -top \
    -files [get_files $dir/project/project.srcs/sources_1/bd/bd/bd.bd]
add_files -norecurse \
    $dir/project/project.srcs/sources_1/bd/bd/hdl/bd_wrapper.v
add_files -norecurse \
    $dir/src/hdl/top.v
update_compile_order -fileset sources_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
