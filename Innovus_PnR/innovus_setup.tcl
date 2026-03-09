############################################################
# DESIGN SETUP
############################################################



file mkdir reports
file mkdir reports/preCTS
file mkdir reports/postCTS
file mkdir reports/postRoute
file mkdir reports/gds

set init_verilog "/home/Mtech2413/simvision/sync_fifo/sync_fifo_synthesis/output/sync_fifo_syn.v"

set init_lef_file {
 /home/install/FOUNDRY/digital/45nm/LIBS/lef/gsclib045.fixed.lef
 
}
set init_mmmc_file "/home/Mtech2413/simvision/sync_fifo/sync_fifo_innovus/mmmc.tcl"

set init_top_cell "sync_fifo"


set init_pwr_net VDD
set init_gnd_net VSS

############################################################
# INITIALIZE DESIGN
############################################################

setDesignMode -process 45

init_design

checkDesign -all
report_analysis_views

############################################################
# RC CORNER CHECK
############################################################

#report_rc_corner
#report_qrc_tech

############################################################
# FLOORPLAN
############################################################

floorPlan -site CoreSite \
 -r 1.0 0.70 20 20 20 20

############################################################
# POWER PLANNING
############################################################

globalNetConnect VDD -type pgpin -pin VDD -all
globalNetConnect VSS -type pgpin -pin VSS -all
applyGlobalNets

addRing \
 -nets {VDD VSS} \
 -type core_rings \
 -follow core \
 -layer {top Metal9 bottom Metal9 left Metal8 right Metal8} \
 -width 5 \
 -spacing 2 \
 -offset 3

addStripe \
 -nets {VDD VSS} \
 -layer Metal6 \
 -direction vertical \
 -width 2 \
 -spacing 2 \
 -set_to_set_distance 40

addStripe \
 -nets {VDD VSS} \
 -layer Metal5 \
 -direction horizontal \
 -width 2 \
 -spacing 2 \
 -set_to_set_distance 40

sroute -nets {VDD VSS} -connect corePin

############################################################
# WELL TAPS + ENDCAPS (CRITICAL FOR 45nm)
############################################################

#addWellTap -cell WELLTAP -checkerBoard
#addEndCap

############################################################
# PLACEMENT
############################################################

placeDesign
optDesign -preCTS

addTieHiLo

report_timing > reports/preCTS/timing.rpt
report_area   > reports/preCTS/area.rpt

############################################################
# CTS (CCOPT)
############################################################

set_analysis_view -setup setup_view -hold hold_view

set_ccopt_property target_skew 0.05

ccopt_design

# Re-enable analysis view after CTS
set_analysis_view -setup setup_view -hold hold_view

#update_timing


optDesign -postCTS

report_clock_tree > reports/postCTS/cts.rpt
report_timing     > reports/postCTS/timing.rpt

############################################################
# ROUTING
############################################################

setNanoRouteMode -drouteFixAntenna true
setNanoRouteMode -routeWithTimingDriven true
setNanoRouteMode -routeWithSiDriven true

routeDesign

############################################################
# TRUE QRC EXTRACTION
############################################################

setExtractRCMode -engine postRoute

setDelayCalMode -SIAware false
extractRC

rcOut -spef reports/sync_fifo.spef

setAnalysisMode -analysisType onChipVariation

optDesign -postRoute -setup -hold

############################################################
# FINAL CLEANUP
############################################################

addFiller -cell {FILL1 FILL2 FILL4 FILL8 FILL16}

ecoRoute

verifyConnectivity
verify_drc

############################################################
# REPORTS
############################################################

report_timing      > reports/postRoute/timing.rpt
report_power       > reports/postRoute/power.rpt
report_area        > reports/postRoute/area.rpt
reportCongestion  > reports/postRoute/congestion.rpt
verify_drc         > reports/postRoute/drc.rpt

saveDesign reports/fifo_final.enc

streamOut reports/gds/sync_fifo.gds \
-mapFile /home/Mtech2413/streamOut.map \
-libName WORK \
-structureName sync_fifo \
-mode ALL
-input

puts "GDS generation completed"
puts "Flow completed successfully with QRC-based RC extraction."