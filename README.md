The increasing demand for high-performance and low-power integrated circuits has significantly accelerated the development of Application Specific Integrated Circuits (ASICs). Modern semiconductor industries require efficient RTL-to-GDSII implementation methodologies capable of meeting timing, power, area, and manufacturability constraints at advanced technology nodes. This thesis presents the complete implementation of an ASIC physical design flow from Register Transfer Level (RTL) to GDSII using Cadence EDA tools at 45nm technology.

The implemented flow includes RTL synthesis using Cadence Genus, Logic Equivalence Checking (LEC), floorplanning, power planning, placement, Clock Tree Synthesis (CTS), routing, Static Timing Analysis (STA), parasitic extraction, and physical verification using Design Rule Check (DRC) and Layout Versus Schematic (LVS). Timing closure techniques were applied to resolve setup, hold, maximum transition, and maximum capacitance violations.

The design was implemented using industry-standard physical design methodologies and optimized for timing, congestion, and power integrity. Cadence Innovus was used for backend implementation, while PVS and Quantus/QRC tools were used for signoff verification and parasitic extraction. The final layout successfully passed physical verification checks and generated a valid GDSII file for fabrication readiness.

This work provides practical exposure to modern ASIC physical design methodologies and demonstrates complete backend implementation and signoff flow suitable for industrial semiconductor applications.

---


# ASIC DESIGN FLOW OVERVIEW

## 1.1 ASIC Design Flow

ASIC design flow consists of frontend and backend stages.

### Frontend Flow

1. Specification
2. RTL Design
3. Functional Verification
4. Synthesis
5. Formal Verification

### Backend Flow

1. Floorplanning
2. Power Planning
3. Placement
4. CTS
5. Routing
6. Timing Closure
7. Physical Verification
8. GDSII Generation

## 1.2 RTL-to-GDSII Flow

The RTL-to-GDSII flow converts behavioral HDL description into manufacturable mask layout.

### Inputs to Backend Flow

* Synthesized Netlist (.v)
* Constraints File (.sdc)
* LEF Files
* Liberty Files (.lib)
* Technology Files
* TLU+ Files

### Outputs

* Routed Netlist
* SPEF File
* Timing Reports
* DRC/LVS Reports
* Final GDSII

## 1.3 Technology Node

The design was implemented using 45nm CMOS technology.

Advantages of 45nm technology:

* Reduced area
* Lower power consumption
* Higher switching speed
* Increased integration density

Challenges:

* Signal integrity issues
* Crosstalk
* IR drop
* Leakage power
* Routing congestion

---

# SYNTHESIS USING CADENCE GENUS

## 2.1 Introduction to Synthesis

Synthesis converts RTL code into gate-level netlist using standard cell libraries.

## 2.2 Inputs to Synthesis

### RTL Files

Behavioral Verilog code.

### Library Files

45nm standard cell libraries.

### SDC Constraints

Timing constraints including:

* Clock definitions
* Input delays
* Output delays
* Clock uncertainty
* Load constraints

## 2.3 Synthesis Flow

The synthesis process includes:

1. Elaboration
2. Generic optimization
3. Technology mapping
4. Timing optimization
5. Area optimization

## 2.4 Synthesis Constraints

Typical synthesis constraints:

```tcl
create_clock -name clk -period 10 [get_ports clk]
set_input_delay 1.0 -clock clk [all_inputs]
set_output_delay 1.0 -clock clk [all_outputs]
```

## 2.5 Synthesis Reports

Generated reports include:

* Timing report
* Area report
* Power report
* Constraint violation report

## 2.6 Synthesis Optimization

Optimization techniques:

* Buffer insertion
* Logic restructuring
* Cell sizing
* Timing-driven mapping

## 2.7 Outputs of Synthesis

Generated files:

* Gate-level netlist
* SDC file
* Timing reports
* Power reports

---

# LOGIC EQUIVALENCE CHECKING

## 3.1 Introduction to LEC

Logic Equivalence Check verifies that synthesized netlist is functionally equivalent to RTL.

## 3.2 Importance of LEC

LEC ensures:

* No functionality change during synthesis
* Optimization correctness
* Safe implementation flow

## 3.3 LEC Flow

The following comparisons were performed:

1. RTL vs Synthesized Netlist
2. Synthesized Netlist vs Routed Netlist

## 3.4 Conformal LEC

Cadence Conformal was used for equivalence checking.

Typical commands:

```tcl
read design rtl.v
read design netlist.v
match
verify
```

## 3.5 LEC Results

The verification completed successfully with no mismatches.

---


# FLOORPLANNING AND POWER PLANNING

## 4.1 Floorplanning

Floorplanning defines:

* Die size
* Core size
* Aspect ratio
* Utilization
* Macro placement
* IO placement

## 4.2 Core Utilization

Core utilization affects:

* Congestion
* Timing
* Routing quality

Higher utilization may cause:

* Congestion
* Routing overflow
* Timing degradation

## 4.3 Macro Placement

Macro placement guidelines:

* Avoid crisscross routing
* Maintain sufficient channel spacing
* Place macros near related logic
* Apply halo margins

## 4.4 Power Planning

Power planning ensures reliable power distribution.

Implemented structures:

* Power rings
* Power stripes
* Power mesh

## 4.5 Power Integrity

Power planning reduces:

* IR drop
* Electromigration
* Voltage fluctuations

## 4.6 Floorplan Results

The floorplan achieved:

* Proper utilization
* Reduced congestion
* Efficient routing resources

---

# PLACEMENT AND OPTIMIZATION

## 5.1 Placement

Placement assigns locations to standard cells.

Types:

* Global placement
* Detailed placement

## 5.2 Placement Objectives

* Minimize wirelength
* Reduce congestion
* Improve timing
* Reduce power

## 5.3 Placement Optimization

Optimization includes:

* Cell spreading
* Buffer insertion
* Cell resizing
* Congestion reduction

## 5.4 Timing Violations

Common violations:

* Setup violations
* Hold violations
* Max transition violations
* Max capacitance violations

## 5.5 Congestion Analysis

Congestion hotspots were identified and optimized.

Methods used:

* Cell spreading
* Placement refinement
* Density optimization

## 5.6 Placement Results

Placement achieved:

* Legalized standard cells
* Reduced congestion
* Improved timing

---

# CLOCK TREE SYNTHESIS

## 6.1 Introduction to CTS

Clock Tree Synthesis distributes clock signals across sequential elements.

## 6.2 CTS Objectives

* Minimize skew
* Reduce insertion delay
* Improve timing
* Balance clock paths

## 6.3 Clock Tree Components

* Buffers
* Inverters
* Clock nets

## 6.4 CTS Optimization

Optimization includes:

* Clock balancing
* Buffer insertion
* Useful skew optimization

## 6.5 Post-CTS Analysis

Post-CTS checks:

* Clock skew
* Insertion delay
* Setup timing
* Hold timing

## 6.6 CTS Results

The CTS stage achieved:

* Balanced clock network
* Reduced skew
* Improved timing closure

---

# ROUTING AND POST-ROUTE OPTIMIZATION

## 7.1 Routing

Routing creates physical interconnections between cells.

Types:

* Global routing
* Detailed routing

## 7.2 Routing Objectives

* Complete connectivity
* Minimize DRC violations
* Reduce wirelength
* Improve timing

## 7.3 Routing Challenges

* Congestion
* Crosstalk
* Antenna violations
* Timing degradation

## 7.4 Post-Route Optimization

Optimization techniques:

* Buffer insertion
* Net shielding
* Timing ECO
* Wire optimization

## 7.5 Signal Integrity

Signal integrity issues include:

* Crosstalk
* Noise
* Delay variation

## 7.6 Routing Results

Routing successfully completed with:

* Full connectivity
* Reduced violations
* Improved timing

---

# STATIC TIMING ANALYSIS

## 8.1 Introduction to STA

Static Timing Analysis verifies timing without simulation vectors.

## 8.2 Timing Checks

### Setup Check

Ensures data arrives before active clock edge.

### Hold Check

Ensures data remains stable after clock edge.

## 8.3 Timing Paths

Types:

* Input to register
* Register to register
* Register to output
* Input to output

## 8.4 Timing Violations

Common violations:

* Setup violations
* Hold violations
* Transition violations
* Capacitance violations

## 8.5 Timing Closure

Techniques used:

* Cell upsizing
* Buffer insertion
* Net optimization
* Placement refinement

## 8.6 STA Reports

Generated reports:

* Setup timing report
* Hold timing report
* Clock report
* Path analysis report

## 8.7 Timing Results

Final timing reports showed positive slack after optimization.

---

# PHYSICAL VERIFICATION AND SIGNOFF

## 9.1 Introduction

Physical verification ensures manufacturability of layout.

## 9.2 Design Rule Check (DRC)

DRC verifies:

* Minimum spacing
* Minimum width
* Via spacing
* Metal density

## 9.3 Layout Versus Schematic (LVS)

LVS checks:

* Connectivity matching
* Netlist consistency
* Device matching

## 9.4 Parasitic Extraction

Quantus/QRC extracts:

* Resistance
* Capacitance
* Coupling effects

## 9.5 Signoff Tools

Used tools:

* PVS
* Quantus/QRC

## 9.6 Signoff Results

Results achieved:

* DRC clean layout
* LVS matched design
* Successful parasitic extraction

---


# GDSII GENERATION

## 10.1 GDSII

GDSII is the final layout database used for fabrication.

## 10.2 Tapeout Preparation

Before tapeout:

* Timing closure completed
* DRC/LVS passed
* Final verification completed

## 10.3 GDSII Export

Final routed layout was exported to GDSII format.

---

# RESULTS AND DISCUSSION

## 11.1 Implementation Results

The design was successfully implemented at 45nm technology.

## 11.2 Timing Results

Achieved:

* Positive setup slack
* Positive hold slack
* Reduced transition violations
* Reduced capacitance violations

## 11.3 Area Results

Area optimization reduced overall core utilization while maintaining timing closure.

## 11.4 Power Results

Power optimization techniques reduced:

* Dynamic power
* Leakage power

## 11.5 Physical Verification Results

Final layout passed:

* DRC
* LVS
* Timing signoff

## 11.6 Discussion

The implemented flow demonstrates complete backend ASIC implementation methodology used in semiconductor industries.

The project provided practical exposure to:

* Industry EDA tools
* Timing closure
* Congestion analysis
* Physical verification
* Signoff methodology



```
### Bhukya Tulasi Ram
### Mtech VLSI AND EMBEDDED SYSTEM DESIGN
### MANIT
