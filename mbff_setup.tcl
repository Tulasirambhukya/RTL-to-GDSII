# ==============================================================
# Cadence Genus Common UI Setup File for multivdd_sram.v
# ==============================================================

# ---- 1. Design & Directory Setup ----
set DESIGN_NAME "SBFF_FIFO_GRAY_90NM"
set DESIGN_DIR "/home/Mtech2413/verilog/multibit_fifo/"
set RTL_DIR     "$DESIGN_DIR"
set LIB_DIR     "/home/install/FOUNDRY/digital/90nm/dig/lib/"
set PHY_DIR    "/home/install/FOUNDRY/digital/90nm/dig/lef/"
#set LIB_DIR     "/home/install/FOUNDRY/digital/45nm/"
#set PHY_DIR    "/home/install/FOUNDRY/digital/45nm/"
#set DFT_DIR "/home/Mtech2413/verilog/multi_vdd_sram/multi_vdd_sram_dft.tcl"
set REPORT_DIR  "$DESIGN_DIR/reports"
set OUTPUT_DIR  "$DESIGN_DIR/output"
set CONSTRAINTS "/home/Mtech2413/verilog/multibit_fifo/mbff_sdc.sdc"
#set CPF_FILE  "/home/Mtech2413/verilog/multi_vdd_sram/multi_vdd_sram.cpf"

# Create directories if they don't exist
file mkdir $REPORT_DIR
file mkdir $OUTPUT_DIR

# ---- 2. Library Setup ----
# Set library search path (Common UI uses set_db)
set_db lib_search_path [list "$LIB_DIR" "$PHY_DIR"]


# Read standard cell libraries (timing models)
read_lib  "$LIB_DIR/fast.lib \
 	   $LIB_DIR/slow.lib \
           $LIB_DIR/typical.lib"


read_physical -lef "$PHY_DIR/gsclib090_tech.lef \
                    $PHY_DIR/gsclib090_macro.lef \
                    $PHY_DIR/gsclib090_translated_ref.lef \
                    $PHY_DIR/gsclib090_translated.lef"




# Read standard cell libraries (timing models) 45NM
#read_lib  "$LIB_DIR/LIBS/lib/min/MEM2_512X32_slow.lib \
# 	   $LIB_DIR/LIBS/lib/min/fast.lib \
#	   $LIB_DIR/LIBS/lib/max/MEM2_512X32_slow.lib"
#	   $LIB_DIR/LIBS/lib/max/slow.lib\
#	   $LIB_DIR/dig/lib/fast.lib\
#	   $LIB_DIR/dig/lib/slow.lib\
#	   $LIB_DIR/dig/lib/typical.lib"
           


#read_physical -lef "$PHY_DIR/LIBS/lef/MEM2_512X32.lef\
#		    $PHY_DIR/LIBS/lef/gsclib045.fixed.lef\
#		    $PHY_DIR/LIBS/lef/gsclib045.fixed2.lef\
#		    $PHY_DIR/dig/lef/gsclib045_tech.lef\
#		    $PHY_DIR/dig/lef/gsclib045_macro.lef"
# ---- 3. Read HDL ----
read_hdl "$RTL_DIR/multibit_fifo.v"

# =============================================
# Multi-VDD SAFE LP CLOCK-GATING (GENUS LP FLOW)
# =============================================
# ============================================================
# INTEGRATED CLOCK GATING (ICG) – GENUS
# ============================================================

# ------------------------------------------------------
# Integrated Clock Gating (ICG) – Supported Genus Flow
# ------------------------------------------------------

# Enable clock gating
 set_db lp_insert_clock_gating true



# Enable automatic enable inference
 set_db lp_clock_gating_infer_enable true

# Hierarchical and domain-safe
set_db lp_clock_gating_hierarchical true
set_db lp_clock_gating_exceptions_aware true


# ---- 4. Elaborate the design ----
elaborate
check_design -unresolved

# ---- MBFF controls (ADD HERE) ----
 #set_db opt_allow_multi_bit_on_flop_with_sdc true
 #set_db opt_multi_bit_flop_opt mergeOnly
 #set_db opt_multi_bit_flop_merge_timing_effort high
 #set_db multibit_cells_from_different_busses true

# ---- NOW enable clock gating ----
 #set_db lp_insert_clock_gating true
  #set_db lp_clock_gating_infer_enable true
# set_db lp_clock_gating_hierarchical true
# set_db lp_clock_gating_exceptions_aware true

# ---- 5. Apply Constraints ----
if {[file exists $CONSTRAINTS]} {
    puts "Reading constraints from $CONSTRAINTS"
    read_sdc $CONSTRAINTS
} else {
    puts "No SDC file found — skipping constraint reading"
}

# ---- 4.1 Read SAIF Switching Activity ----
set SAIF_FILE "/home/Mtech2413/verilog/multibit_fifo/16X8_mbff.saif"

if {[file exists $SAIF_FILE]} {
    puts "Reading SAIF file for switching activity: $SAIF_FILE"
    # Correct syntax for Cadence Genus
    read_saif -instance uut $SAIF_FILE
   
} else {
    puts "No SAIF file found — skipping activity annotation"
}



# ---- 6. Synthesis Options ----


# ---- 7. Synthesis Flow ----
syn_gen
syn_map
syn_opt

set_db power_unit uW

# ---- 8. Write Out Results ----
write_hdl > "$OUTPUT_DIR/${DESIGN_NAME}_syn.v"
write_sdc > "$OUTPUT_DIR/${DESIGN_NAME}_syn.sdc"
write_sdf > "$OUTPUT_DIR/${DESIGN_NAME}_syn.sdf"

# ---- 9. Generate Reports ----
report_area   > "$REPORT_DIR/${DESIGN_NAME}_area.rpt"
report_power  > "$REPORT_DIR/${DESIGN_NAME}_power.rpt"
report_timing > "$REPORT_DIR/${DESIGN_NAME}_timing.rpt"
report_qor > "$REPORT_DIR/${DESIGN_NAME}_qor.rpt"
report_activity > "$REPORT_DIR/${DESIGN_NAME}_activity.rpt"
report_clock_gating -summary

# ---- 10. Exit ----
gui_show
#run command
# genus -lic_startup_options Joules_RTL_Power -files "/home/Mtech2413/verilog/multibit_fifo/mbff_setup.tcl"