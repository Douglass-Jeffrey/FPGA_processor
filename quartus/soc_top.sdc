# soc_top.sdc  Timing constraints

# 50 MHz clock, too fast for unpipelined cpu
create_clock -name CLOCK_50 -period 20.000 [get_ports CLOCK_50]

# cpu_clk, use conservative 2^19 division for med clock
create_generated_clock -name cpu_clk -source [get_ports CLOCK_50] \
    -divide_by 524288 [get_registers {cpu_clk}]
derive_clock_uncertainty

# dont care about human response time i/o
set_false_path -from [get_ports {SW[*] KEY[*]}] -to [all_registers]
set_false_path -from * -to [get_ports {LEDR[*] LEDG[*]}]

# no timing critical paths between derived clk and main clk
set_clock_groups -asynchronous -group {CLOCK_50} -group {cpu_clk}
