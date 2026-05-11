############################################################
# DESIGN script
############################################################


############################################################
# PAUSE FUNCTION FOR STEP-BY-STEP EXECUTION
############################################################

proc pause_step {msg} {
    puts ""
    puts "=================================================="
    puts "PAUSE: $msg"
    puts "Type 'c' and press ENTER to continue..."
    puts "=================================================="
    flush stdout
    gets stdin
}

############################################################
# CREATE UNIQUE RUN DIRECTORY
############################################################

set design_name sync_fifo
set run_time [clock format [clock seconds] -format "%Y%m%d_%H%M%S"]

set run_dir "runs/${design_name}_${run_time}"

file mkdir $run_dir
cd $run_dir
file mkdir checkDesign
file mkdir reports
file mkdir reports/qrc
file mkdir reports/init
file mkdir reports/floorplan
file mkdir reports/pdn
file mkdir reports/preCTS
file mkdir reports/postCTS
file mkdir reports/postRoute
file mkdir reports/signalintegrity   
file mkdir reports/finalclean
file mkdir reports/gds

puts "Running design in directory: $run_dir"
pause_step "run_dir creation completed. Inspect run_dir."

set init_verilog "/home/Mtech2413/rtl_to_gds/fifo_synthesis/output/sync_fifo_syn.v"

# GOLDEN NETLIST (FROM GENUS)
set golden_netlist $init_verilog
puts "Golden Netlist: $golden_netlist"

set init_lef_file {
 /home/install/FOUNDRY/digital/45nm/LIBS/lef/gsclib045.fixed.lef
 "/home/install/FOUNDRY/digital/45nm/LIBS/lef/pdkIO.lef"
}
set init_mmmc_file "/home/Mtech2413/rtl_to_gds/fifo_innovus/mmmc.tcl"

set init_top_cell "sync_fifo"


set init_pwr_net VDD
set init_gnd_net VSS

############################################################
# INITIALIZE DESIGN
############################################################

setDesignMode -process 45

init_design


set_db metric_enable true

set_db metric_capture_design_image true
set_db metric_capture_timing_paths 100
set_db metric_capture_tns_histogram true

report_lib_cells              > reports/init/all_cells.rpt
#report_lib_cells *BUF*        > reports/init/buffers.rpt
#report_lib_cells *INV*        > reports/init/inverters.rpt
#report_lib_cells *CLK*        > reports/init/clock_cells.rpt
#report_lib_cells *TIE*        > reports/init/tie_cells.rpt
#report_lib_cells *FILL*       > reports/init/filler_cells.rpt
#report_lib_cells *TAP*        > reports/init/tap_cells.rpt
#report_lib_cells *END*        > reports/init/endcap_cells.rpt

setAnalysisMode -analysisType onChipVariation

set_analysis_view -setup setup_view -hold hold_view

report_analysis_views   > reports/init/analysisview.rpt
report_clocks		> reports/init/clocks.rpt
report_case_analysis	> reports/init/caseanalysis.rpt
checkDesign -all        > reports/init/checkdesign.rpt

############################################################
# FLOORPLAN
############################################################

# Better utilization + smaller margins

setFPlanMode \
  -snapCoreGrid placement \
  -snapDieGrid placement \
  -snapIoGrid placement \
  -snap_all_corners_to_grid true

floorPlan -site CoreSite -r 1.0 0.60 40 40 40 40

# IO placement

loadIoFile "/home/Mtech2413/simvision/sync_fifo/sync_fifo_innovus/pads.io"

# Improve fanout
setOptMode -fixFanoutLoad true

assignIoPins

# Check available IO filler cells
#get_lib_cells *IOFILL*

#addIoFiller \
# -cell {IOFILL1 IOFILL2 IOFILL5 IOFILL10} \
# -prefix IOFILL



# Validate floorplan
checkFPlan 


# Reports
#checkIo 	      		> reports/floorplan/io_check.rpt
#report_utilization    		> reports/floorplan/utilization.rpt
#report_design_area    		> reports/floorplan/area.rpt
#reportPlaceStatus     		> reports/floorplan/place_status.rpt
report_qor 			-out_file > reports/floorplan/qor.html
reportCongestion -hotspot 	> reports/floorplan/congestion.rpt 
get_snap_grid_info -type placement -pitch_x
get_snap_grid_info -type placement -pitch_y
get_snap_grid_info -type placement -origin

pause_step "Floorplan + IO fixed"

############################################################
# POWER PLANNING
############################################################

globalNetConnect VDD -type pgpin -pin VDD -all
globalNetConnect VSS -type pgpin -pin VSS -all
applyGlobalNets

# Ring (reduced width)
addRing \
 -nets {VDD VSS} \
 -type core_rings \
 -follow core \
 -layer {top Metal9 bottom Metal9 left Metal8 right Metal8} \
 -width 3 \
 -spacing 2 \
 -offset 2

# Vertical stripes (less dense)
addStripe \
 -nets {VDD VSS} \
 -layer Metal6 \
 -direction vertical \
 -width 1.5 \
 -spacing 2 \
 -set_to_set_distance 70

# Horizontal stripes (less dense)
addStripe \
 -nets {VDD VSS} \
 -layer Metal5 \
 -direction horizontal \
 -width 1.5 \
 -spacing 2 \
 -set_to_set_distance 70

# Routing power
sroute \
 -nets {VDD VSS} \
 -connect {corePin blockPin padPin} \
 -allowLayerChange 1 \
 -allowJogging 1

# Reports
#report_power_plan  > reports/pdn/powerplan.rpt
verifyConnectivity -type all > reports/pdn/connectivity.rpt
verify_drc > reports/pdn/drc.rpt
redirect reports/pdn/congestion.rpt {
    reportCongestion
}

pause_step "pdn build."


############################################################
# AUTO DETECT TAPCELL AND ENDCAP
############################################################

# Try to find tap cell automatically
set tap_cells [get_lib_cells *TAP*]

if {[llength $tap_cells] > 0} {
    set tapcell [lindex $tap_cells 0]
    puts "Using tapcell: $tapcell"
    addWellTap -cell $tapcell -checkerBoard
} else {
    puts "WARNING: No TAP cell found in library. Skipping addWellTap."
}

# Try to find endcap cell automatically
set endcap_cells [get_lib_cells *END*]

if {[llength $endcap_cells] > 0} {
    set endcapcell [lindex $endcap_cells 0]
    puts "Using endcap cell: $endcapcell"
    addEndCap -cell $endcapcell
} else {
    puts "WARNING: No ENDCAP cell found in library. Skipping addEndCap."
}
pause_step "Endcap cell and walltap cell placed."


############################################################
# HIGH FANOUT NET SYNTHESIS
############################################################

# Enable fanout optimization
setOptMode -fixFanoutLoad true

# Buffer high-fanout control nets
#bufferTreeSynthesis \
 # -nets {rst wr_en rd_en} \
  #-bufList {BUFX4 BUFX8 BUFX12}


############################################################
# PLACEMENT
############################################################

setPlaceMode -timingDriven true
setPlaceMode -place_global_uniform_density false
setPlaceMode -congEffort high

placeDesign
optDesign -preCTS

# Increase optimization effort
setOptMode -effort high

# Focus critical path
group_path -name CRIT -from [get_ports rd_en]


# WRITE PRE-CTS NETLIST
saveNetlist netlist/preCTS/sync_fifo_preCTS.v

puts "Pre-CTS netlist written"

# Basic sanity check
checkDesign -netlist  > reports/preCTS/check_netlist.rpt

checkPlace
addTieHiLo -cell "TIEHI TIELO"


report_timing 				> reports/preCTS/timing.rpt
reportCongestion -hotspot 		> reports/preCTS/congestion.rpt
report_density 				> reports/preCTS/density.rpt
report_drc   				> reports/preCTS/drc.rpt

report_qor  -out_file reports/preCTS/qor.html
pause_step "standard cell placement done."

############################################################
# CTS (CCOPT)
############################################################

set_analysis_view -setup setup_view -hold hold_view

set_ccopt_property target_skew 0.03
set_ccopt_property max_fanout 20
set_ccopt_property target_max_trans 0.08
#set_ccopt_property route_type leaf_route
ccopt_design

#pause_step "ccopt set with skew of 0.03, and max_fanout of 20."

# Re-enable analysis view after CTS
set_analysis_view -setup setup_view -hold hold_view

#update_timing
# Post-CTS optimization (HIGH effort)

setOptMode -effort high

# Fix transition violations
setOptMode -fixTran true

# Fix capacitance violations
setOptMode -fixCap true

# Fix fanout violations
setOptMode -fixFanoutLoad true

# Optional but recommended
setOptMode -setupTargetSlack 0.05

# Run optimization
optDesign -postCTS

# WRITE POST-CTS NETLIST
saveNetlist netlist/postCTS/sync_fifo_postCTS.v

puts "Post-CTS netlist written"

checkDesign -netlist

report_clock_tree 			> reports/postCTS/cts.rpt
report_timing     			> reports/postCTS/timing.rpt
#report_constraints 			> reports/postCTS/constraints.rpt
report_qor 				-out_file reports/postCTS/qor.html
report_timing				> reports/postCTS/timing.rpt
timeDesign -postCTS -setup -outDir reports/postCTS
timeDesign -postCTS -hold -outDir reports/postCTS
pause_step "CTS done."


############################################################
# ROUTING
############################################################
setDelayCalMode -siAware true


setNanoRouteMode -drouteFixAntenna true

setNanoRouteMode -routeWithTimingDriven true

setNanoRouteMode -routeWithSiDriven true

routeDesign

pause_step "routing of design done."


############################################################
# 🔥 FIXED POST-ROUTE OPTIMIZATION (CRITICAL)
############################################################

# Improve transition/cap/fanout fixing
setOptMode -fixTran true
setOptMode -fixCap true
setOptMode -fixFanoutLoad true

# Step 1: Fix DRVs (transition, cap, etc.)
optDesign -postRoute -drv

# Step 2: Fix setup first
optDesign -postRoute -setup

# Step 3: Allow setup tradeoff for better hold fixing
setOptMode -fixHoldAllowSetupTnsDegrade true


# Optional but recommended
setOptMode -holdTargetSlack 0.05

# Step 4: Fix hold (MAIN FIX)
optDesign -postRoute -hold




report_timing      		> reports/postRoute/timing.rpt
report_power       		> reports/postRoute/power.rpt
report_area        		> reports/postRoute/area.rpt
report_qor 		        -out_file reports/postRoute/qor.html
reportCongestion -hotspot  	> reports/postRoute/congestion.rpt
#report_antenna			> reports/postRoute/antenna.rpt
report_noise			> reports/postRoute/noise.rpt
#set_si_mode -enable_delay_report true
#set_si_mode -separate_delta_delay_on_data true
# Timing with SI
#timeDesign -postRoute -setup  -outDir reports/postRoute
#timeDesign -postRoute -hold   -outDir reports/postRoute
#
#timeDesign -postRoute -signoff -outDir reports/postRoute
#report_timing -si               > reports/postRoute/timing_si.rpt
pause_step "post_routing of design done."


############################################################
# TRUE QRC EXTRACTION
############################################################

setExtractRCMode -engine postRoute -effortLevel signoff


extractRC

rcOut -spef reports/sync_fifo.spef

setAnalysisMode -analysisType onChipVariation


pause_step "qrc extraction done postroute."

############################################################
#  REMOVE UNSUPPORTED COMMAND (WAS CRASHING YOUR FLOW)
############################################################

#analyze_power_grid		> reports/postRoute/power_grid_analysis.rpt
#report_power_grid   		> reports/postRoute/ir_drop.rpt
#report_net -rc            	> reports/qrc/rc.rpt
#report_power_integrity  	> reports/postRoute/powerintegrity.rpt


############################################################
# WRITE FINAL INNOVUS NETLIST
############################################################

saveNetlist netlist/postRoute/sync_fifo_postRoute.v

puts "Final Innovus netlist written"

checkDesign -netlist

pause_step "final innovus netlist generated."


############################################################
# FINAL CLEANUP
############################################################

addFiller -cell {FILL1 FILL2 FILL4 FILL8 FILL16}

ecoRoute

#pause_step "eco of design done."

set lec_script "netlist/run_lec.tcl"

set fp [open $lec_script "w"]

puts $fp "read design -golden $golden_netlist"
puts $fp "read design -revised netlist/postRoute/sync_fifo_postRoute.v"
puts $fp "set system mode lec"
puts $fp "add compare point -all"
puts $fp "compare"
puts $fp "report verification"

close $fp

puts "LEC script generated at: $lec_script"


pause_step "final cleanup done."

############################################################
# REPORTS
############################################################

report_density 			> reports/signalintegrity/density.rpt
reportCongestion -hotspot  	> reports/signalintegrity/congestion.rpt
verify_drc         		> reports/finalclean/drc.rpt
verifyConnectivity		> reports/finalclean/connectivity.rpt
verifyProcessAntenna 		> reports/finalclean/antenna_final.rpt
report_qor 			 -out_file reports/finalclean/qor_final.html



############################################################
# gdsII final
############################################################

saveDesign reports/fifo_final.enc

streamOut reports/gds/sync_fifo.gds \
-mapFile /home/Mtech2413/streamOut.map \
-libName WORK \
-structureName sync_fifo \
-mode ALL

puts "GDS generation completed"
puts "Flow completed successfully with QRC-based RC extraction."

puts "GDS generation completed"
puts "Flow completed successfully with QRC-based RC extraction."
