#=============================================================================
# Genus Synthesis + DFT Insertion Script
# Design : barrel_shifter_4bit
# Tool   : Cadence Genus Synthesis Solution
# Library: 90nm  (slow.lib)
#
# Steps performed:
#   1.  Library setup
#   2.  RTL read & elaborate
#   3.  SDC constraints
#   4.  Pre-synthesis DFT definitions
#   5.  Synthesis  (generic → map → opt)
#   6.  Pre-DFT reports & netlist export
#   7.  DFT rule check
#   8.  Scan-FF replacement & chain stitching
#   9.  Post-DFT optimisation
#  10.  Post-DFT reports & netlist/ATPG-file export
#=============================================================================

puts "============================================================"
puts "  Genus Synthesis + DFT  :  barrel_shifter_4bit"
puts "  Technology : 90nm"
puts "============================================================"

#-----------------------------------------------------------------------------
# Step 1 : Library Setup
#-----------------------------------------------------------------------------
set_db init_lib_search_path /home/install/FOUNDRY/digital/90nm/dig/lib/
set_db library                slow.lib

#-----------------------------------------------------------------------------
# Step 2 : Read RTL
#-----------------------------------------------------------------------------
puts "\n>>> Reading RTL..."
read_hdl ./barrel_shifter_4bit.v

#-----------------------------------------------------------------------------
# Step 3 : Elaborate
#-----------------------------------------------------------------------------
puts "\n>>> Elaborating..."
elaborate barrel_shifter_4bit

# Flag any unresolved references immediately
check_design -unresolved

#-----------------------------------------------------------------------------
# Step 4 : Read SDC Constraints
#-----------------------------------------------------------------------------
puts "\n>>> Reading SDC..."
read_sdc ./barrel_shifter_4bit.sdc

#-----------------------------------------------------------------------------
# Step 5 : Power Goals
#-----------------------------------------------------------------------------
set_max_leakage_power 0.0
set_max_dynamic_power 0.0

#-----------------------------------------------------------------------------
# Step 5b : Pre-Synthesis DFT Definitions
#           Must be done BEFORE syn_generic so Genus maps DFFs → Scan-FFs
#-----------------------------------------------------------------------------
# Use muxed-scan style (most common; compatible with Modus FULLSCAN mode)
set_db dft_scan_style muxed_scan

# Prefix added to all DFT-generated cell/net names
set_db dft_prefix DFT_

# Identify the scan-enable port
define_dft shift_enable \
           -name   scan_en_sig \
           -active high \
           scan_en

# Identify the functional clock as the test clock for ATPG
# period in ps  →  10 ns functional  /  20 ns test (half-speed)
define_dft test_clock \
           -name   clk_test \
           -period 20000 \
           clk

#-----------------------------------------------------------------------------
# Step 6 : Synthesise – Generic
#-----------------------------------------------------------------------------
puts "\n>>> Synthesising to generic gates..."
set_db syn_generic_effort high
syn_generic

#-----------------------------------------------------------------------------
# Step 7 : Synthesise – Technology Map
#-----------------------------------------------------------------------------
puts "\n>>> Mapping to 90nm library..."
set_db syn_map_effort high
syn_map

#-----------------------------------------------------------------------------
# Step 8 : Incremental Optimisation
#-----------------------------------------------------------------------------
puts "\n>>> Running incremental optimisation..."
set_db syn_opt_effort high
syn_opt

#-----------------------------------------------------------------------------
# Step 9 : Pre-DFT Reports
#-----------------------------------------------------------------------------
puts "\n>>> Writing pre-DFT reports..."
report timing > ./barrel_shifter_4bit_pre_dft_timing.rpt
report area   > ./barrel_shifter_4bit_pre_dft_area.rpt
report power  > ./barrel_shifter_4bit_pre_dft_power.rpt
report gates  > ./barrel_shifter_4bit_pre_dft_gates.rpt

#-----------------------------------------------------------------------------
# Step 10 : Pre-DFT Netlist
#-----------------------------------------------------------------------------
puts "\n>>> Writing pre-DFT netlist..."
write_hdl > ./barrel_shifter_4bit_pre_dft.v
write_sdc > ./barrel_shifter_4bit_pre_dft.sdc

#-----------------------------------------------------------------------------
# Step 11 : DFT Rule Check
#           Fix any violations reported here before proceeding.
#-----------------------------------------------------------------------------
puts "\n>>> Checking DFT rules..."
check_dft_rules > ./barrel_shifter_4bit_dft_rules.rpt

#-----------------------------------------------------------------------------
# Step 12 : Replace FFs with Scan-FFs & Stitch the Chain
#           Design has 8 FFs (4 in stage1, 4 in data_out).
#           All 8 become scan-FFs forming a single chain:
#               scan_in → [FF0..FF7] → scan_out
#-----------------------------------------------------------------------------
puts "\n>>> Replacing flip-flops with scan flip-flops..."
replace_scan

puts "\n>>> Stitching scan chain..."
# -non_shared_output  ensures scan_out is driven solely by the chain tail
define_scan_chain \
    -name           chain1 \
    -sdi            scan_in \
    -sdo            scan_out \
    -non_shared_output

connect_scan_chains

#-----------------------------------------------------------------------------
# Step 13 : Post-DFT Incremental Optimisation
#-----------------------------------------------------------------------------
puts "\n>>> Post-DFT incremental optimisation..."
syn_opt -incr

#-----------------------------------------------------------------------------
# Step 14 : Post-DFT Reports
#-----------------------------------------------------------------------------
puts "\n>>> Writing post-DFT reports..."
report timing    > ./barrel_shifter_4bit_post_dft_timing.rpt
report area      > ./barrel_shifter_4bit_post_dft_area.rpt
report power     > ./barrel_shifter_4bit_post_dft_power.rpt
report gates     > ./barrel_shifter_4bit_post_dft_gates.rpt
report dft_setup > ./barrel_shifter_4bit_dft_setup.rpt
report dft_chains > ./barrel_shifter_4bit_scan_chains.rpt
check_dft_rules  > ./barrel_shifter_4bit_post_dft_rules.rpt

#-----------------------------------------------------------------------------
# Step 15 : Post-DFT Netlist, SDC, SDF, SCANDEF
#-----------------------------------------------------------------------------
puts "\n>>> Writing post-DFT netlist and constraint files..."
write_hdl     > ./barrel_shifter_4bit_post_dft.v
write_sdf     > ./barrel_shifter_4bit_post_dft.sdf
write_sdc     > ./barrel_shifter_4bit_post_dft.sdc
write_scandef > ./barrel_shifter_4bit.scandef

#-----------------------------------------------------------------------------
# Step 16 : Write DFT/ATPG input files for Modus
#           Generates: *.pinassign  *.modedef  (used by run_modus_atpg.tcl)
#-----------------------------------------------------------------------------
puts "\n>>> Writing DFT protocol files for Modus ATPG..."
write_dft_atpg \
    -library ./barrel_shifter_4bit_post_dft.v \
    -directory ./

puts "\n============================================================"
puts "  Genus DFT Complete!  barrel_shifter_4bit"
puts ""
puts "  KEY OUTPUT FILES:"
puts "    barrel_shifter_4bit_post_dft.v    <- post-DFT netlist (Modus input)"
puts "    barrel_shifter_4bit.scandef        <- scan chain definition"
puts "    *.pinassign / *.modedef            <- Modus ATPG protocol files"
puts "    barrel_shifter_4bit_scan_chains.rpt"
puts "============================================================"

# Uncomment to open the schematic viewer
# gui_show