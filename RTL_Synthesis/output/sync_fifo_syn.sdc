# ####################################################################

#  Created by Genus(TM) Synthesis Solution 21.14-s082_1 on Thu Mar 05 23:38:21 IST 2026

# ####################################################################

set sdc_version 2.0

set_units -capacitance 1000fF
set_units -time 1000ps

# Set the current design
current_design sync_fifo

create_clock -name "clk" -period 4.0 -waveform {0.0 2.0} [get_ports clk]
set_clock_transition 0.1 [get_clocks clk]
set_load -pin_load 0.1 [get_ports {rdata[7]}]
set_load -pin_load 0.1 [get_ports {rdata[6]}]
set_load -pin_load 0.1 [get_ports {rdata[5]}]
set_load -pin_load 0.1 [get_ports {rdata[4]}]
set_load -pin_load 0.1 [get_ports {rdata[3]}]
set_load -pin_load 0.1 [get_ports {rdata[2]}]
set_load -pin_load 0.1 [get_ports {rdata[1]}]
set_load -pin_load 0.1 [get_ports {rdata[0]}]
set_load -pin_load 0.1 [get_ports full]
set_load -pin_load 0.1 [get_ports empty]
set_false_path -from [get_ports rst] -to [list \
  [get_cells {rdata_reg[0]}]  \
  [get_cells {rdata_reg[6]}]  \
  [get_cells {rdata_reg[7]}]  \
  [get_cells {rdata_reg[1]}]  \
  [get_cells {rdata_reg[2]}]  \
  [get_cells {rdata_reg[3]}]  \
  [get_cells {rdata_reg[4]}]  \
  [get_cells {rdata_reg[5]}]  \
  [get_cells {mem_reg[11][3]}]  \
  [get_cells {mem_reg[10][1]}]  \
  [get_cells {mem_reg[8][1]}]  \
  [get_cells {mem_reg[8][0]}]  \
  [get_cells {mem_reg[8][2]}]  \
  [get_cells {mem_reg[8][3]}]  \
  [get_cells {mem_reg[8][5]}]  \
  [get_cells {mem_reg[8][6]}]  \
  [get_cells {mem_reg[8][4]}]  \
  [get_cells {mem_reg[8][7]}]  \
  [get_cells {mem_reg[11][7]}]  \
  [get_cells {mem_reg[10][7]}]  \
  [get_cells {mem_reg[11][0]}]  \
  [get_cells {mem_reg[11][1]}]  \
  [get_cells {mem_reg[11][2]}]  \
  [get_cells {mem_reg[10][5]}]  \
  [get_cells {mem_reg[10][6]}]  \
  [get_cells {mem_reg[11][5]}]  \
  [get_cells {mem_reg[11][6]}]  \
  [get_cells {mem_reg[9][0]}]  \
  [get_cells {mem_reg[9][1]}]  \
  [get_cells {mem_reg[9][2]}]  \
  [get_cells {mem_reg[9][3]}]  \
  [get_cells {mem_reg[9][4]}]  \
  [get_cells {mem_reg[9][5]}]  \
  [get_cells {mem_reg[9][6]}]  \
  [get_cells {mem_reg[9][7]}]  \
  [get_cells {mem_reg[10][0]}]  \
  [get_cells {mem_reg[10][2]}]  \
  [get_cells {mem_reg[10][3]}]  \
  [get_cells {mem_reg[10][4]}]  \
  [get_cells {mem_reg[11][4]}]  \
  [get_cells {mem_reg[2][6]}]  \
  [get_cells {mem_reg[1][3]}]  \
  [get_cells {mem_reg[5][7]}]  \
  [get_cells {mem_reg[1][7]}]  \
  [get_cells {mem_reg[1][2]}]  \
  [get_cells {mem_reg[4][3]}]  \
  [get_cells {mem_reg[0][2]}]  \
  [get_cells {mem_reg[0][0]}]  \
  [get_cells {mem_reg[0][3]}]  \
  [get_cells {mem_reg[0][1]}]  \
  [get_cells {mem_reg[0][5]}]  \
  [get_cells {mem_reg[0][4]}]  \
  [get_cells {mem_reg[0][6]}]  \
  [get_cells {mem_reg[12][0]}]  \
  [get_cells {mem_reg[12][1]}]  \
  [get_cells {mem_reg[12][2]}]  \
  [get_cells {mem_reg[12][3]}]  \
  [get_cells {mem_reg[12][4]}]  \
  [get_cells {mem_reg[12][5]}]  \
  [get_cells {mem_reg[12][6]}]  \
  [get_cells {mem_reg[4][6]}]  \
  [get_cells {mem_reg[4][7]}]  \
  [get_cells {mem_reg[4][5]}]  \
  [get_cells {mem_reg[12][7]}]  \
  [get_cells {mem_reg[0][7]}]  \
  [get_cells {mem_reg[3][1]}]  \
  [get_cells {mem_reg[4][1]}]  \
  [get_cells {mem_reg[4][0]}]  \
  [get_cells {mem_reg[4][2]}]  \
  [get_cells {mem_reg[4][4]}]  \
  [get_cells {mem_reg[1][5]}]  \
  [get_cells {mem_reg[1][6]}]  \
  [get_cells {mem_reg[1][0]}]  \
  [get_cells {mem_reg[1][1]}]  \
  [get_cells {mem_reg[3][5]}]  \
  [get_cells {mem_reg[6][3]}]  \
  [get_cells {mem_reg[2][0]}]  \
  [get_cells {mem_reg[2][1]}]  \
  [get_cells {mem_reg[2][2]}]  \
  [get_cells {mem_reg[2][3]}]  \
  [get_cells {mem_reg[2][4]}]  \
  [get_cells {mem_reg[2][5]}]  \
  [get_cells {mem_reg[6][6]}]  \
  [get_cells {mem_reg[1][4]}]  \
  [get_cells {mem_reg[2][7]}]  \
  [get_cells {mem_reg[5][0]}]  \
  [get_cells {mem_reg[5][1]}]  \
  [get_cells {mem_reg[13][2]}]  \
  [get_cells {mem_reg[13][3]}]  \
  [get_cells {mem_reg[6][0]}]  \
  [get_cells {mem_reg[13][5]}]  \
  [get_cells {mem_reg[6][1]}]  \
  [get_cells {mem_reg[13][6]}]  \
  [get_cells {mem_reg[13][7]}]  \
  [get_cells {mem_reg[14][0]}]  \
  [get_cells {mem_reg[14][1]}]  \
  [get_cells {mem_reg[14][3]}]  \
  [get_cells {mem_reg[6][4]}]  \
  [get_cells {mem_reg[14][4]}]  \
  [get_cells {mem_reg[6][5]}]  \
  [get_cells {mem_reg[14][5]}]  \
  [get_cells {mem_reg[14][6]}]  \
  [get_cells {mem_reg[14][7]}]  \
  [get_cells {mem_reg[6][7]}]  \
  [get_cells {mem_reg[5][2]}]  \
  [get_cells {mem_reg[3][2]}]  \
  [get_cells {mem_reg[3][3]}]  \
  [get_cells {mem_reg[3][4]}]  \
  [get_cells {mem_reg[6][2]}]  \
  [get_cells {mem_reg[3][6]}]  \
  [get_cells {mem_reg[3][7]}]  \
  [get_cells {mem_reg[14][2]}]  \
  [get_cells {mem_reg[13][4]}]  \
  [get_cells {mem_reg[3][0]}]  \
  [get_cells {mem_reg[5][3]}]  \
  [get_cells {mem_reg[5][4]}]  \
  [get_cells {mem_reg[5][5]}]  \
  [get_cells {mem_reg[5][6]}]  \
  [get_cells {mem_reg[13][0]}]  \
  [get_cells {mem_reg[13][1]}]  \
  [get_cells {mem_reg[7][5]}]  \
  [get_cells {mem_reg[7][0]}]  \
  [get_cells {mem_reg[7][1]}]  \
  [get_cells {mem_reg[7][2]}]  \
  [get_cells {mem_reg[7][3]}]  \
  [get_cells {mem_reg[7][6]}]  \
  [get_cells {mem_reg[7][7]}]  \
  [get_cells {mem_reg[7][4]}]  \
  [get_cells {mem_reg[15][0]}]  \
  [get_cells {mem_reg[15][2]}]  \
  [get_cells {mem_reg[15][4]}]  \
  [get_cells {mem_reg[15][5]}]  \
  [get_cells {mem_reg[15][7]}]  \
  [get_cells {mem_reg[15][3]}]  \
  [get_cells {mem_reg[15][1]}]  \
  [get_cells {mem_reg[15][6]}]  \
  [get_cells {rd_ptr_reg[4]}]  \
  [get_cells {wr_ptr_reg[4]}]  \
  [get_cells {wr_ptr_reg[1]}]  \
  [get_cells {rd_ptr_reg[0]}]  \
  [get_cells {wr_ptr_reg[0]}]  \
  [get_cells {rd_ptr_reg[3]}]  \
  [get_cells {wr_ptr_reg[3]}]  \
  [get_cells {wr_ptr_reg[2]}]  \
  [get_cells {rd_ptr_reg[2]}]  \
  [get_cells {rd_ptr_reg[1]}] ]
set_clock_gating_check -hold 0.05 -setup 0.1 
set_input_delay -clock [get_clocks clk] -add_delay -max 0.8 [get_ports rst]
set_input_delay -clock [get_clocks clk] -add_delay -max 0.8 [get_ports wr_en]
set_input_delay -clock [get_clocks clk] -add_delay -max 0.8 [get_ports rd_en]
set_input_delay -clock [get_clocks clk] -add_delay -max 0.8 [get_ports {wdata[7]}]
set_input_delay -clock [get_clocks clk] -add_delay -max 0.8 [get_ports {wdata[6]}]
set_input_delay -clock [get_clocks clk] -add_delay -max 0.8 [get_ports {wdata[5]}]
set_input_delay -clock [get_clocks clk] -add_delay -max 0.8 [get_ports {wdata[4]}]
set_input_delay -clock [get_clocks clk] -add_delay -max 0.8 [get_ports {wdata[3]}]
set_input_delay -clock [get_clocks clk] -add_delay -max 0.8 [get_ports {wdata[2]}]
set_input_delay -clock [get_clocks clk] -add_delay -max 0.8 [get_ports {wdata[1]}]
set_input_delay -clock [get_clocks clk] -add_delay -max 0.8 [get_ports {wdata[0]}]
set_input_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports rst]
set_input_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports wr_en]
set_input_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports rd_en]
set_input_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports {wdata[7]}]
set_input_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports {wdata[6]}]
set_input_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports {wdata[5]}]
set_input_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports {wdata[4]}]
set_input_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports {wdata[3]}]
set_input_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports {wdata[2]}]
set_input_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports {wdata[1]}]
set_input_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports {wdata[0]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 0.8 [get_ports {rdata[7]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 0.8 [get_ports {rdata[6]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 0.8 [get_ports {rdata[5]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 0.8 [get_ports {rdata[4]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 0.8 [get_ports {rdata[3]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 0.8 [get_ports {rdata[2]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 0.8 [get_ports {rdata[1]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 0.8 [get_ports {rdata[0]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 0.8 [get_ports full]
set_output_delay -clock [get_clocks clk] -add_delay -max 0.8 [get_ports empty]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports {rdata[7]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports {rdata[6]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports {rdata[5]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports {rdata[4]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports {rdata[3]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports {rdata[2]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports {rdata[1]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports {rdata[0]}]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports full]
set_output_delay -clock [get_clocks clk] -add_delay -min 0.2 [get_ports empty]
set_input_transition 0.1 [get_ports rst]
set_input_transition 0.1 [get_ports wr_en]
set_input_transition 0.1 [get_ports rd_en]
set_input_transition 0.1 [get_ports {wdata[7]}]
set_input_transition 0.1 [get_ports {wdata[6]}]
set_input_transition 0.1 [get_ports {wdata[5]}]
set_input_transition 0.1 [get_ports {wdata[4]}]
set_input_transition 0.1 [get_ports {wdata[3]}]
set_input_transition 0.1 [get_ports {wdata[2]}]
set_input_transition 0.1 [get_ports {wdata[1]}]
set_input_transition 0.1 [get_ports {wdata[0]}]
set_clock_uncertainty -setup 0.05 [get_clocks clk]
set_clock_uncertainty -hold 0.05 [get_clocks clk]
