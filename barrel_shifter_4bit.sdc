# =============================================================================
# SDC Constraints for 8-bit FSM Processor
# Technology : 90nm (slow.lib corner)
# Clock      : 50 MHz => period 20 ns
# =============================================================================

# Primary clock
create_clock -name clk -period 20.0 [get_ports clk]
set_clock_uncertainty 0.5 [get_clocks clk]
set_clock_transition  0.2 [get_clocks clk]

# Input / Output delays (25% of clock period)
set_input_delay  5.0 -clock clk [get_ports {reset test_mode}]
set_output_delay 5.0 -clock clk [get_ports {A_out PC_out halted_out}]

# DFT ports: false paths during functional timing analysis
set_false_path -from [get_ports scan_en]
set_false_path -from [get_ports scan_in]
set_false_path -to   [get_ports scan_out]

# Drive / load environment
set_driving_cell -lib_cell INVX1 -pin ZN [get_ports {clk reset test_mode scan_en scan_in}]
set_load 0.05 [all_outputs]

# Max transition / fanout
set_max_transition 0.5 [current_design]
set_max_fanout     20  [current_design]


