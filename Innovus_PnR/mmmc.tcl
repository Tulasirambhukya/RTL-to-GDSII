############################################################
# MMMC SETUP (WITH CAP TABLE) ✅
############################################################

# Library Sets
create_library_set -name slow_lib \
  -timing { /home/install/FOUNDRY/digital/45nm/LIBS/lib/max/slow.lib }

create_library_set -name fast_lib \
  -timing { /home/install/FOUNDRY/digital/45nm/LIBS/lib/min/fast.lib }

create_rc_corner -name rc_worst \
  -qx_tech_file /home/install/FOUNDRY/digital/45nm/LIBS/qx/qrcTechFile \
  -postRoute_cap {1.1 1.1 1.1} \
  -postRoute_res {1.1 1.1 1.1} \
  -postRoute_clkcap {1.1 1.1 1.1} \
  -postRoute_clkres {1.1 1.1 1.1}

create_rc_corner -name rc_best \
  -qx_tech_file /home/install/FOUNDRY/digital/45nm/LIBS/qx/qrcTechFile \
  -postRoute_cap {0.9 0.9 0.9} \
  -postRoute_res {0.9 0.9 0.9} \
  -postRoute_clkcap {0.9 0.9 0.9} \
  -postRoute_clkres {0.9 0.9 0.9}


# Delay Corners
create_delay_corner -name slow_delay \
  -library_set slow_lib \
  -rc_corner rc_worst

create_delay_corner -name fast_delay \
  -library_set fast_lib \
  -rc_corner rc_best

# Constraint Mode
create_constraint_mode -name func \
  -sdc_files { /home/Mtech2413/rtl_to_gds/fifo_synthesis/output/sync_fifo_syn.sdc }

# Analysis Views
create_analysis_view -name setup_view \
  -constraint_mode func \
  -delay_corner slow_delay

create_analysis_view -name hold_view \
  -constraint_mode func \
  -delay_corner fast_delay

# Apply Views
set_analysis_view -setup setup_view -hold hold_view
