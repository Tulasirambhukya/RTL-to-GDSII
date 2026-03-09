############################################################
# MMMC SETUP (Without RC Corner)
############################################################

# 1️⃣ Library Sets
create_library_set -name slow_lib \
  -timing { /home/install/FOUNDRY/digital/45nm/LIBS/lib/max/slow.lib }

create_library_set -name fast_lib \
  -timing { /home/install/FOUNDRY/digital/45nm/LIBS/lib/min/fast.lib }

# 2️⃣ Delay Corners (Library Only)
create_delay_corner -name slow_delay \
  -library_set slow_lib

create_delay_corner -name fast_delay \
  -library_set fast_lib

# 3️⃣ Constraint Mode
create_constraint_mode -name func \
  -sdc_files { /home/Mtech2413/simvision/sync_fifo/sync_fifo_synthesis/output/sync_fifo_syn.sdc }

# 4️⃣ Analysis Views
create_analysis_view -name setup_view \
  -constraint_mode func \
  -delay_corner slow_delay

create_analysis_view -name hold_view \
  -constraint_mode func \
  -delay_corner fast_delay

# 5️⃣ Apply Views
set_analysis_view -setup setup_view -hold hold_view