# ==============================================================
#  Genus Synthesis + SAIF Power Flow (Clean Version)
# ==============================================================

# ---- 1. Setup ----
set DESIGN_NAME "sync_fifo"
set DESIGN_DIR "/home/Mtech2413/simvision/sync_fifo/sync_fifo_synthesis"
set RTL_FILE   "$DESIGN_DIR/sync_fifo.sv"
set SAIF_DIR   "/home/Mtech2413/simvision/sync_fifo/saif"

set LIB_DIR    "/home/install/FOUNDRY/digital/45nm"
set REPORT_DIR "$DESIGN_DIR/reports"
set OUTPUT_DIR "$DESIGN_DIR/output"
set CONSTRAINTS "/home/Mtech2413/simvision/sync_fifo/sync_fifo_synthesis/sync_fifo.sdc"

file mkdir $REPORT_DIR
file mkdir $OUTPUT_DIR

# ---- 2. Library ----
set_db lib_search_path [list $LIB_DIR]

# ⚠️ Use ONLY one corner for academic project
read_lib "$LIB_DIR/LIBS/lib/max/slow.lib"

read_physical -lef "$LIB_DIR/LIBS/lef/gsclib045.fixed.lef"

# ---- 3. Read RTL (SystemVerilog mode) ----
#set_db hdl_sva_enable false
read_hdl -sv $RTL_FILE
elaborate $DESIGN_NAME
check_design -unresolved

# ---- 4. Constraints ----
if {[file exists $CONSTRAINTS]} {
    read_sdc $CONSTRAINTS
} else {
    puts "No SDC found"
}

# ---- 5. Synthesis ----
syn_gen
syn_map
syn_opt

# ---- 6. Enable Power ----
#set_db power_analysis_mode time_based
#set_db power_enable_analysis true
set_db power_unit uW

# ---- 7. SAIF Power Per Test ----
foreach saif_file {
    fifo_wr_test.saif
    fifo_wr_then_rd_test.saif
    fifo_wr_rd_test.saif
    fifo_wr_rd_parallel_test.saif
} {

    puts "=============================================="
    puts "Running Power Analysis for $saif_file"
    puts "=============================================="

    read_saif "$SAIF_DIR/$saif_file" \
              -instance sync_fifo \
              -verbose

    report_power  > "$REPORT_DIR/power_$saif_file.rpt"
    report_activity > "$REPORT_DIR/activity_$saif_file.rpt"
}

# ---- 8. Write Out Results ----
write_hdl > "$OUTPUT_DIR/${DESIGN_NAME}_syn.v"
write_sdc > "$OUTPUT_DIR/${DESIGN_NAME}_syn.sdc"
write_sdf > "$OUTPUT_DIR/${DESIGN_NAME}_syn.sdf"

# ---- 9. Generate Reports ----
report_area   > "$REPORT_DIR/${DESIGN_NAME}_area.rpt"
report_power  > "$REPORT_DIR/${DESIGN_NAME}_power.rpt"
report_timing > "$REPORT_DIR/${DESIGN_NAME}_timing.rpt"
report_qor > "$REPORT_DIR/${DESIGN_NAME}_qor.rpt"
puts "FLOW COMPLETED SUCCESSFULLY"

# --------10. gui show--------------------------
gui_show
#run command
# genus -lic_startup_options Joules_RTL_Power -files "/home/Mtech2413/simvision/sync_fifo/sync_fifo_synthesis/sync_fifo_setup.tcl"