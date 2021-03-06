# Project F: FPGA Ad Astra - Create Vivado Project
# (C)2020 Will Green, open source hardware released under the MIT License
# Learn more at https://projectf.io

puts "INFO: Project F - FPGA Ad Astra Project Creation Script"

# If the FPGA board/part isn't set use Arty
if {! [info exists fpga_part]} {
    set fpga_part "xc7a35ticsg324-1L"
}
if {! [info exists board_name]} {
    set board_name "arty"
}

# Set the project name
set _xil_proj_name_ "fpga-ad-astra"

# Set the reference directories for source file relative paths
set origin_dir "./../.."

# Set the directory path for the project
set orig_proj_dir "[file normalize "${origin_dir}/xc7/vivado"]"

# Create Vivado project
create_project ${_xil_proj_name_} ${orig_proj_dir} -part ${fpga_part}

#
# Design sources
#

if {[string equal [get_filesets -quiet sources_1] ""]} {
  create_fileset -srcset sources_1
}
set fs_design_obj [get_filesets sources_1]

# Top design sources (not used in simulation)
set top_sources [list \
  [file normalize "${origin_dir}/xc7/top_greet.sv"] \
  [file normalize "${origin_dir}/xc7/top_hello_en.sv"] \
  [file normalize "${origin_dir}/xc7/top_hello_jp.sv"] \
  [file normalize "${origin_dir}/xc7/top_lfsr.sv"] \
  [file normalize "${origin_dir}/xc7/top_starfields.sv"] \
]
add_files -norecurse -fileset $fs_design_obj $top_sources
set design_top_obj [get_files -of_objects [get_filesets sources_1]]
set_property -name "used_in_simulation" -value "0" -objects $design_top_obj

# Set top module for design sources
set_property -name "top" -value "top_lfsr" -objects $fs_design_obj
set_property -name "top_auto_set" -value "0" -objects $fs_design_obj

# Design sources (used in simulation)
set design_sources [list \
  [file normalize "${origin_dir}/display_timings.sv"] \
  [file normalize "${origin_dir}/lfsr.sv"] \
  [file normalize "${origin_dir}/sprite.sv"] \
  [file normalize "${origin_dir}/starfield.sv"] \
  [file normalize "${origin_dir}/xc7/clock_gen.sv"] \
  [file normalize "${origin_dir}/xc7/rom_sync.sv"] \
]
add_files -norecurse -fileset $fs_design_obj $design_sources

# Memory design sources
set mem_design_sources [list \
  [file normalize "${origin_dir}/font_unscii_8x8_latin_uc.mem"] \
  [file normalize "${origin_dir}/font_unscii_16x16_hiragana.mem"] \
  [file normalize "${origin_dir}/greets.mem"] \
]
add_files -norecurse -fileset $fs_design_obj $mem_design_sources
set design_mem_obj [get_files -of_objects [get_filesets sources_1] [list "*mem"]]
set_property -name "file_type" -value "Memory File" -objects $design_mem_obj

#
# Simulation Sources
#

# Create 'sim_1' fileset (if not found)
if {[string equal [get_filesets -quiet sim_1] ""]} {
  create_fileset -simset sim_1
}
set fs_sim_obj [get_filesets sim_1]

# Generic simulation sources
set sim_sources [list \
  [file normalize "${origin_dir}/xc7/lfsr_tb.sv"] \
  [file normalize "${origin_dir}/xc7/starfield_tb.sv"] \
  [file normalize "${origin_dir}/xc7/sprite_tb.sv"] \
]
add_files -norecurse -fileset $fs_sim_obj $sim_sources

# Set 'sim_1' fileset properties
set_property -name "top" -value "lfsr_tb" -objects $fs_sim_obj
set_property -name "top_lib" -value "xil_defaultlib" -objects $fs_sim_obj

#
# Constraints
#

# Create 'constrs_1' fileset (if not found)
if {[string equal [get_filesets -quiet constrs_1] ""]} {
  create_fileset -constrset constrs_1
}
set fs_constr_obj [get_filesets constrs_1]

set constr_sources [list \
  [file normalize "$origin_dir/xc7/${board_name}.xdc"] \
]
add_files -norecurse -fileset $fs_constr_obj $constr_sources
set constr_file_obj [get_files -of_objects [get_filesets constrs_1]]
set_property -name "file_type" -value "XDC" -objects $constr_file_obj

#
# Done
#

puts "INFO: Project created:${_xil_proj_name_}"
