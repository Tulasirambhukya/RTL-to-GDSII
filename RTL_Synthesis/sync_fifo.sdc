############################################################
# FIFO SDC FILE
# Frequency : 200 MHz
# Period    : 5 ns
############################################################

##############################
# 1. Clock Definition
##############################
create_clock -name clk \
             -period 4.000 \
             -waveform {0.000 2.00} \
             [get_ports clk]

# Clock Uncertainty (setup + hold margin)
set_clock_uncertainty 0.05 [get_clocks clk]

# Clock transition (input slew assumption)
set_clock_transition 0.10 [get_clocks clk]


##############################
# 2. Input Constraints
##############################

# Remove clock from input list
set data_inputs [remove_from_collection [all_inputs] [get_ports clk]]

# Apply input delay relative to clock
set_input_delay -max 0.8 -clock clk $data_inputs
set_input_delay -min 0.2 -clock clk $data_inputs

# Input transition assumption
set_input_transition 0.10 $data_inputs


##############################
# 3. Output Constraints
##############################

set_output_delay -max 0.8 -clock clk [all_outputs]
set_output_delay -min 0.2 -clock clk [all_outputs]

# Output load (typical small SoC assumption)
set_load 0.10 [all_outputs]


##############################
# 4. Clock Gating Checks
##############################
set_clock_gating_check -setup 0.10
set_clock_gating_check -hold  0.05


##############################
# 5. Design Rule Constraints
##############################

# Limit excessive fanout
set_max_fanout 16 [sync_fifo_Sv_45nm]


##############################
# 6. Asynchronous Reset Handling
##############################

# Declare reset as false path
set_false_path -from [get_ports rst] -to [all_registers]

############################################################
# End of SDC
############################################################