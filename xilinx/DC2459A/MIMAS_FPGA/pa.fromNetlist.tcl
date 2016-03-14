
# PlanAhead Launch Script for Post-Synthesis pin planning, created by Project Navigator

create_project -name DC2459A -dir "C:/Projects/FPGA_scketchbook/xilinx/DC2459A/MIMAS_FPGA/planAhead_run_1" -part xc6slx9tqg144-3
set_property design_mode GateLvl [get_property srcset [current_run -impl]]
set_property edif_top_file "C:/Projects/FPGA_scketchbook/xilinx/DC2459A/MIMAS_FPGA/top_level.ngc" [ get_property srcset [ current_run ] ]
add_files -norecurse { {C:/Projects/FPGA_scketchbook/xilinx/DC2459A/MIMAS_FPGA} {ipcore_dir} }
add_files [list {ipcore_dir/dds.ncf}] -fileset [get_property constrset [current_run]]
set_param project.pinAheadLayout  yes
set_property target_constrs_file "top_level.ucf" [current_fileset -constrset]
add_files [list {top_level.ucf}] -fileset [get_property constrset [current_run]]
link_design
