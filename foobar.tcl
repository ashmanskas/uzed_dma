set dir [pwd]
create_project proj $dir/proj -part xc7z020clg400-1
set_property board_part em.avnet.com:microzed_7020:part0:1.1 [current_project]
ipx::infer_core -vendor user.org -library user -taxonomy /UserIP $dir/src/ip/wja_axis
ipx::edit_ip_in_project -upgrade true -name edit_ip_project -directory $dir/proj/proj.tmp $dir/src/ip/wja_axis/component.xml
ipx::current_core $dir/src/ip/wja_axis/component.xml
update_compile_order -fileset sources_1
set_property core_revision 2 [ipx::current_core]
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]
ipx::archive_core $dir/ip_repo/wja_axis_1.0.zip [ipx::current_core]
close_project -delete
# set_property  ip_repo_paths  $dir/src/ip/wja_axis [current_project]
update_ip_catalog
ipx::infer_core -vendor user.org -library user -taxonomy /UserIP $dir/src/ip/wja_bus_lite
ipx::edit_ip_in_project -upgrade true -name edit_ip_project -directory $dir/proj/proj.tmp $dir/src/ip/wja_bus_lite/component.xml
ipx::current_core $dir/src/ip/wja_bus_lite/component.xml
update_compile_order -fileset sources_1
set_property core_revision 2 [ipx::current_core]
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]
ipx::check_integrity -quiet [ipx::current_core]
ipx::archive_core $dir/ip_repo/wja_bus_lite_1.0.zip [ipx::current_core]
close_project -delete
# set_property  ip_repo_paths  [list $dir/src/ip/wja_bus_lite $dir/src/ip/wja_axis] [current_project]
set_property ip_repo_paths $dir/ip_repo [current_project]
update_ip_catalog
ipx::unload_core $dir/src/ip/wja_bus_lite/component.xml
ipx::unload_core $dir/src/ip/wja_axis/component.xml
