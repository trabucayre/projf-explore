set top    [lindex $argv 0]
set constr [lindex $argv 1]

read_xdc $constr
read_edif $top.edif
link_design -part xc7s15ftgb196-1 -top $top
opt_design
place_design
route_design
report_utilization
report_timing
write_bitstream -force $top.bit
