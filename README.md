# 🚀 VLSI Backend Design Flow using Cadence Tools (RTL → GDSII)

## 📌 Project Overview

This repository demonstrates a complete RTL to GDSII ASIC design flow using  vivado and Cadence EDA tools on a 45nm technology node. The project implements an FIFO design and covers all stages including RTL verification, synthesis, floorplanning, placement, clock tree considerations, routing, power planning, and signoff checks.

The objective is to gain hands-on experience with ASIC physical design, timing analysis, and power delivery network implementation.

---

## 🎯 Key Highlights

* End-to-end physical design flow implementation
* Constraint-driven synthesis and timing optimization
* Power Delivery Network (PDN) design with rings and stripes
* IO pad integration and chip-level floorplanning
* Static Timing Analysis using MMMC setup
* DRC verification and routing optimization

---

## 🛠 Tools Used

* VIVADO  — RTL simulation and Functional simulation.
* Cadence Genus — Logic synthesis
* Cadence Innovus — Physical design (PnR, PDN, routing)
* TSMC 45nm Technology Library

---

## 📂 Project Directory Structure

```
rtl/            → Verilog RTL and testbench
constraints/    → SDC files
tcl/            → Automation scripts
lib/            → Technology libraries
lef_files/      → LEF and IO pad definitions
genus/          → Synthesis outputs
innovus/        → Physical design setup
reports/        → Timing, power, DRC reports
```

---

##  Design Flow

### 1️ RTL Development and Verification

RTL is written in Verilog and verified in Vivado simulator using a task-based testbench to ensure functional correctness under different operating scenarios. The RTL source file and testbench are added to a Vivado project, simulation sources are compiled, and behavioral simulation is run to validate the design functionality.
The design implements a 16×8 synchronous FIFO using a register-based memory array and binary read/write pointers. The RTL is written in Verilog and simulated in Vivado to verify correct data transfer, pointer updates, and status flag behavior under various read and write conditions.

The FIFO uses binary pointers with an extra MSB to detect wrap-around and generate accurate FULL and EMPTY flags. Write operations occur when wr_en is asserted and the FIFO is not full, while read operations occur when rd_en is asserted and the FIFO is not empty. The memory array stores data words, and the read data is registered to ensure stable output timing.

The FULL condition is detected when the next write pointer equals the read pointer with the MSB inverted, indicating the buffer is full. The EMPTY condition occurs when write and read pointers are equal, indicating no data is available.

After functional verification in Vivado using a task-based testbench, switching activity is captured through SAIF generation to enable realistic power analysis in downstream synthesis tools.
``
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 25.02.2026 00:28:47
// Design Name: 
// Module Name: fifo
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module fifo(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        wr_en,
    input  wire        rd_en,
    input  wire [7:0]  wdata,
    output reg  [7:0]  rdata,
    output wire        full,
    output wire        empty
);

    localparam DEPTH = 16;
    localparam ADDR  = 4;

    // Memory
    reg [7:0] mem [0:DEPTH-1];

    // Pointers (ADDR+1 bits for wrap detection)
    reg [ADDR:0] wr_ptr;
    reg [ADDR:0] rd_ptr;

    // Status registers
    reg full_r, empty_r;

    assign full  = full_r;
    assign empty = empty_r;

    // Fire conditions
    wire wr_fire = wr_en && !full_r;
    wire rd_fire = rd_en && !empty_r;

    // Address extraction
    wire [ADDR-1:0] wr_addr = wr_ptr[ADDR-1:0];
    wire [ADDR-1:0] rd_addr = rd_ptr[ADDR-1:0];

    //--------------------------------------------------
    // WRITE LOGIC
    //--------------------------------------------------
    always @(posedge clk) begin
        if (wr_fire)
            mem[wr_addr] <= wdata;
    end

    //--------------------------------------------------
    // READ LOGIC
    //--------------------------------------------------
    always @(posedge clk) begin
        if (rd_fire)
            rdata <= mem[rd_addr];
    end

    //--------------------------------------------------
    // POINTER UPDATE
    //--------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            wr_ptr <= 0;
        else if (wr_fire)
            wr_ptr <= wr_ptr + 1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_ptr <= 0;
        else if (rd_fire)
            rd_ptr <= rd_ptr + 1;
    end

    //--------------------------------------------------
    // FLAG LOGIC
    //--------------------------------------------------
    wire [ADDR:0] wr_ptr_next = wr_ptr + wr_fire;

    // FULL: next write catches read with MSB flipped
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            full_r <= 1'b0;
        else
            full_r <= (wr_ptr_next == {~rd_ptr[ADDR], rd_ptr[ADDR-1:0]});
    end

    // EMPTY: pointers equal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            empty_r <= 1'b1;
        else
            empty_r <= (wr_ptr == rd_ptr);
    end

endmodule
```

A task-based Verilog testbench is developed in Vivado to verify the functionality of the 16×8 synchronous FIFO under different operating conditions. The testbench instantiates the FIFO DUT and generates a periodic clock along with an active-low reset sequence to initialize the design.

Reusable tasks such as fifo_write, fifo_read, fill_fifo, drain_fifo, and fifo_rw are created to simplify stimulus generation and improve readability. These tasks allow systematic verification of scenarios including partial writes and reads, full condition detection, empty condition detection, overflow attempts, underflow attempts, pointer wrap-around behavior, and simultaneous read/write operations.

During simulation, signal activity is monitored using $monitor to observe data flow and status flags in real time. After functional verification, the same simulation is used to generate a SAIF file capturing switching activity across the DUT hierarchy, which is later used for accurate power estimation during synthesis.
the test bench is as follows.

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 25.02.2026 00:29:17
// Design Name: 
// Module Name: tb_fifo
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_fifo;
  parameter DW = 8;

  reg clk;
  reg rst_n;
  reg wr_en;
  reg rd_en;
  reg [DW-1:0] wdata;

  wire [DW-1:0] rdata;
  wire full;
  wire empty;

  // DUT
  fifo dut (
    .clk(clk),
    .rst_n(rst_n),
    .wr_en(wr_en),
    .rd_en(rd_en),
    .wdata(wdata),
    .rdata(rdata),
    .full(full),
    .empty(empty)
  );

  // Clock
  initial clk = 0;
  always #5 clk = ~clk;

  //--------------------------------------------------
  // RESET
  //--------------------------------------------------
  task reset_fifo;
  begin
    rst_n = 0;
    wr_en = 0;
    rd_en = 0;
    wdata = 0;
    repeat(3) @(posedge clk);
    rst_n = 1;
    @(posedge clk);
    $display("Reset done");
  end
  endtask

  //--------------------------------------------------
  // WRITE
  //--------------------------------------------------
  task write_fifo(input [DW-1:0] data);
  begin
    @(posedge clk);
    if (!full) begin
      wr_en = 1;
      wdata = data;
      $display("WRITE %h at time %0t", data, $time);
    end
    @(posedge clk);
    wr_en = 0;
  end
  endtask

  //--------------------------------------------------
  // READ
  //--------------------------------------------------
  task read_fifo;
  begin
    @(posedge clk);
    if (!empty) begin
      rd_en = 1;
    end
    @(posedge clk);
    rd_en = 0;
    $display("READ -> %h at time %0t", rdata, $time);
  end
  endtask

  //--------------------------------------------------
  // MAIN TEST
  //--------------------------------------------------
  initial begin
    $display("===== FIFO DEBUG START =====");

    reset_fifo;

    // Write pattern
    write_fifo(8'h11);
    write_fifo(8'h22);
    write_fifo(8'h33);

    // Read back
    read_fifo;
    read_fifo;
    read_fifo;

    // Fill FIFO
    repeat(16) write_fifo($random);

    // Drain FIFO
    repeat(16) read_fifo;

    $display("===== TEST DONE =====");
    #50;
    $finish;
  end

  //--------------------------------------------------
  // Monitor
  //--------------------------------------------------
  initial begin
    $monitor("T=%0t wr=%b rd=%b wdata=%h rdata=%h full=%b empty=%b",
              $time, wr_en, rd_en, wdata, rdata, full, empty);
  end

endmodule

➡️ After successful verification.
<img width="1580" height="813" alt="Screenshot 2026-02-25 003525" src="https://github.com/user-attachments/assets/69e09362-f341-4035-b9a3-2e2d725256d4" />


## What is a SAIF file 

A SAIF (Switching Activity Interchange Format) file is a file that records the switching activity of signals in a digital design during simulation. It captures information such as how often signals toggle, how long they stay at logic 0 or 1, and transition probabilities. EDA tools use this activity data to calculate realistic dynamic power consumption because power depends heavily on switching behavior.

## Why SAIF is needed 

SAIF is important because dynamic power in CMOS circuits is proportional to switching activity. Without SAIF, tools assume default toggle rates, which can lead to inaccurate power estimation. By using real simulation activity, designers can estimate power more accurately, optimize clock gating, identify high-power blocks, and make informed decisions for low-power design. It is especially critical in battery-powered and high-performance chips where power budgets are strict.

## What information SAIF contains

A SAIF file includes signal names, toggle counts, time spent at logic high and low, switching probabilities, and hierarchical mapping of modules. This information allows synthesis and power analysis tools to compute switching power at gate or net level.

## How we generate SAIF

SAIF is generated during functional or gate-level simulation using simulators like VCS, Xcelium, or ModelSim. Typically, SAIF dumping commands are added in the testbench, which records activity while running realistic workloads. After simulation completes, the SAIF file is exported for use in power analysis.

This ensures power numbers reflect real operation instead of assumptions.
In the Vivado TCL console, the following commands are used:

open_saif rtl_fifo.saif — Creates a new SAIF file to store switching activity.

log_saif [get_objects /tb_fifo/dut/*] — Records switching activity of all signals inside the DUT hierarchy.

run all — Runs the simulation to capture signal transitions.

close_saif — Finalizes and saves the SAIF file.

The wildcard * ensures that all internal signals of the DUT are monitored. The generated SAIF file is later used in synthesis or power analysis tools to estimate dynamic power based on real switching activity.the path to get the saif is is as mention below.

C:\Users\user_name\fifo_16x8\fifo_16x8.sim\sim_1\behav\xsim

 the generated saif file for the above design, that we use for the SAIF based power analysis.
 
(SAIFILE
   (SAIFVERSION "2.0")
   (DIRECTION "backward")
   (DESIGN )
   (DATE "Tue Jan 20 11:02:00 2026")
   (VENDOR "Xilinx, Inc")
   (PROGRAM_NAME "Vivado Simulator")
   (VERSION "2020.2")
   (DIVIDER /)
   (TIMESCALE  1 ps)
   (DURATION  1475000)
   (INSTANCE  tb_fifo_16x8
      (INSTANCE  dut
         (NET 
            (clk (T0 740000) (T1 735000) (TX 0) (TZ 0) (TB 0) (TC 295))
            (rst_n (T0 25000) (T1 1450000) (TX 0) (TZ 0) (TB 0) (TC 1))
            (wr_en (T0 1145000) (T1 330000) (TX 0) (TZ 0) (TB 0) (TC 66))
            (rd_en (T0 1145000) (T1 330000) (TX 0) (TZ 0) (TB 0) (TC 66))
            (wdata\[0\] (T0 1305000) (T1 170000) (TX 0) (TZ 0) (TB 0) (TC 34))
            (wdata\[1\] (T0 1295000) (T1 180000) (TX 0) (TZ 0) (TB 0) (TC 36))
            (wdata\[2\] (T0 1325000) (T1 150000) (TX 0) (TZ 0) (TB 0) (TC 30))
            (wdata\[3\] (T0 1305000) (T1 170000) (TX 0) (TZ 0) (TB 0) (TC 34))
            (wdata\[4\] (T0 1455000) (T1 20000) (TX 0) (TZ 0) (TB 0) (TC 4))
            (wdata\[5\] (T0 1445000) (T1 30000) (TX 0) (TZ 0) (TB 0) (TC 6))
            (wdata\[6\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (wdata\[7\] (T0 1455000) (T1 20000) (TX 0) (TZ 0) (TB 0) (TC 4))
            (rdata\[0\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (rdata\[1\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (rdata\[2\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (rdata\[3\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (rdata\[4\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (rdata\[5\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (rdata\[6\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (rdata\[7\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (full (T0 1365000) (T1 110000) (TX 0) (TZ 0) (TB 0) (TC 4))
            (empty (T0 1330000) (T1 145000) (TX 0) (TZ 0) (TB 0) (TC 4))
            (mem\[15\]\[0\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[15\]\[1\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[15\]\[2\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[15\]\[3\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[15\]\[4\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[15\]\[5\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[15\]\[6\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[15\]\[7\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[14\]\[0\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[14\]\[1\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[14\]\[2\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[14\]\[3\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[14\]\[4\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[14\]\[5\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[14\]\[6\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[14\]\[7\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[13\]\[0\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[13\]\[1\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[13\]\[2\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[13\]\[3\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[13\]\[4\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[13\]\[5\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[13\]\[6\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[13\]\[7\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[12\]\[0\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[12\]\[1\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[12\]\[2\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[12\]\[3\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[12\]\[4\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[12\]\[5\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[12\]\[6\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[12\]\[7\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[11\]\[0\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[11\]\[1\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[11\]\[2\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[11\]\[3\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[11\]\[4\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[11\]\[5\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[11\]\[6\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[11\]\[7\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[10\]\[0\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[10\]\[1\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[10\]\[2\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[10\]\[3\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[10\]\[4\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[10\]\[5\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[10\]\[6\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[10\]\[7\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[9\]\[0\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[9\]\[1\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[9\]\[2\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[9\]\[3\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[9\]\[4\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[9\]\[5\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[9\]\[6\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[9\]\[7\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[8\]\[0\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[8\]\[1\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[8\]\[2\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[8\]\[3\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[8\]\[4\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[8\]\[5\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[8\]\[6\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[8\]\[7\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[7\]\[0\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[7\]\[1\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[7\]\[2\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[7\]\[3\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[7\]\[4\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[7\]\[5\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[7\]\[6\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[7\]\[7\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[6\]\[0\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[6\]\[1\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[6\]\[2\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[6\]\[3\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[6\]\[4\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[6\]\[5\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[6\]\[6\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[6\]\[7\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[5\]\[0\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[5\]\[1\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[5\]\[2\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[5\]\[3\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[5\]\[4\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[5\]\[5\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[5\]\[6\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[5\]\[7\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[4\]\[0\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[4\]\[1\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[4\]\[2\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[4\]\[3\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[4\]\[4\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[4\]\[5\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[4\]\[6\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[4\]\[7\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[3\]\[0\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[3\]\[1\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[3\]\[2\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[3\]\[3\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[3\]\[4\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[3\]\[5\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[3\]\[6\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[3\]\[7\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[2\]\[0\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[2\]\[1\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[2\]\[2\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[2\]\[3\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[2\]\[4\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[2\]\[5\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[2\]\[6\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[2\]\[7\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[1\]\[0\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[1\]\[1\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[1\]\[2\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[1\]\[3\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[1\]\[4\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[1\]\[5\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[1\]\[6\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[1\]\[7\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[0\]\[0\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[0\]\[1\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[0\]\[2\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[0\]\[3\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[0\]\[4\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[0\]\[5\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[0\]\[6\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (mem\[0\]\[7\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (wr_bin\[0\] (T0 395000) (T1 1080000) (TX 0) (TZ 0) (TB 0) (TC 33))
            (wr_bin\[1\] (T0 1135000) (T1 340000) (TX 0) (TZ 0) (TB 0) (TC 16))
            (wr_bin\[2\] (T0 1155000) (T1 320000) (TX 0) (TZ 0) (TB 0) (TC 8))
            (wr_bin\[3\] (T0 1155000) (T1 320000) (TX 0) (TZ 0) (TB 0) (TC 4))
            (wr_bin\[4\] (T0 755000) (T1 720000) (TX 0) (TZ 0) (TB 0) (TC 2))
            (wr_gray\[0\] (T0 375000) (T1 1100000) (TX 0) (TZ 0) (TB 0) (TC 17))
            (wr_gray\[1\] (T0 1135000) (T1 340000) (TX 0) (TZ 0) (TB 0) (TC 8))
            (wr_gray\[2\] (T0 1155000) (T1 320000) (TX 0) (TZ 0) (TB 0) (TC 4))
            (wr_gray\[3\] (T0 755000) (T1 720000) (TX 0) (TZ 0) (TB 0) (TC 2))
            (wr_gray\[4\] (T0 755000) (T1 720000) (TX 0) (TZ 0) (TB 0) (TC 2))
            (rd_bin\[0\] (T0 415000) (T1 1060000) (TX 0) (TZ 0) (TB 0) (TC 33))
            (rd_bin\[1\] (T0 1155000) (T1 320000) (TX 0) (TZ 0) (TB 0) (TC 16))
            (rd_bin\[2\] (T0 1155000) (T1 320000) (TX 0) (TZ 0) (TB 0) (TC 8))
            (rd_bin\[3\] (T0 1155000) (T1 320000) (TX 0) (TZ 0) (TB 0) (TC 4))
            (rd_bin\[4\] (T0 805000) (T1 670000) (TX 0) (TZ 0) (TB 0) (TC 2))
            (rd_gray\[0\] (T0 415000) (T1 1060000) (TX 0) (TZ 0) (TB 0) (TC 17))
            (rd_gray\[1\] (T0 1155000) (T1 320000) (TX 0) (TZ 0) (TB 0) (TC 8))
            (rd_gray\[2\] (T0 1155000) (T1 320000) (TX 0) (TZ 0) (TB 0) (TC 4))
            (rd_gray\[3\] (T0 805000) (T1 670000) (TX 0) (TZ 0) (TB 0) (TC 2))
            (rd_gray\[4\] (T0 805000) (T1 670000) (TX 0) (TZ 0) (TB 0) (TC 2))
            (wr_fire (T0 1145000) (T1 330000) (TX 0) (TZ 0) (TB 0) (TC 66))
            (rd_fire (T0 1145000) (T1 330000) (TX 0) (TZ 0) (TB 0) (TC 66))
            (wr_bin_next\[0\] (T0 385000) (T1 1090000) (TX 0) (TZ 0) (TB 0) (TC 66))
            (wr_bin_next\[1\] (T0 1135000) (T1 340000) (TX 0) (TZ 0) (TB 0) (TC 32))
            (wr_bin_next\[2\] (T0 1155000) (T1 320000) (TX 0) (TZ 0) (TB 0) (TC 16))
            (wr_bin_next\[3\] (T0 1155000) (T1 320000) (TX 0) (TZ 0) (TB 0) (TC 8))
            (wr_bin_next\[4\] (T0 755000) (T1 720000) (TX 0) (TZ 0) (TB 0) (TC 4))
            (rd_bin_next\[0\] (T0 405000) (T1 1070000) (TX 0) (TZ 0) (TB 0) (TC 66))
            (rd_bin_next\[1\] (T0 1155000) (T1 320000) (TX 0) (TZ 0) (TB 0) (TC 32))
            (rd_bin_next\[2\] (T0 1155000) (T1 320000) (TX 0) (TZ 0) (TB 0) (TC 16))
            (rd_bin_next\[3\] (T0 1155000) (T1 320000) (TX 0) (TZ 0) (TB 0) (TC 8))
            (rd_bin_next\[4\] (T0 805000) (T1 670000) (TX 0) (TZ 0) (TB 0) (TC 4))
            (wr_gray_next\[0\] (T0 365000) (T1 1110000) (TX 0) (TZ 0) (TB 0) (TC 34))
            (wr_gray_next\[1\] (T0 1135000) (T1 340000) (TX 0) (TZ 0) (TB 0) (TC 16))
            (wr_gray_next\[2\] (T0 1155000) (T1 320000) (TX 0) (TZ 0) (TB 0) (TC 8))
            (wr_gray_next\[3\] (T0 755000) (T1 720000) (TX 0) (TZ 0) (TB 0) (TC 4))
            (wr_gray_next\[4\] (T0 755000) (T1 720000) (TX 0) (TZ 0) (TB 0) (TC 4))
            (rd_gray_next\[0\] (T0 405000) (T1 1070000) (TX 0) (TZ 0) (TB 0) (TC 34))
            (rd_gray_next\[1\] (T0 1155000) (T1 320000) (TX 0) (TZ 0) (TB 0) (TC 16))
            (rd_gray_next\[2\] (T0 1155000) (T1 320000) (TX 0) (TZ 0) (TB 0) (TC 8))
            (rd_gray_next\[3\] (T0 805000) (T1 670000) (TX 0) (TZ 0) (TB 0) (TC 4))
            (rd_gray_next\[4\] (T0 805000) (T1 670000) (TX 0) (TZ 0) (TB 0) (TC 4))
            (wr_addr\[0\] (T0 395000) (T1 1080000) (TX 0) (TZ 0) (TB 0) (TC 33))
            (wr_addr\[1\] (T0 1135000) (T1 340000) (TX 0) (TZ 0) (TB 0) (TC 16))
            (wr_addr\[2\] (T0 1155000) (T1 320000) (TX 0) (TZ 0) (TB 0) (TC 8))
            (wr_addr\[3\] (T0 1155000) (T1 320000) (TX 0) (TZ 0) (TB 0) (TC 4))
            (rd_addr\[0\] (T0 415000) (T1 1060000) (TX 0) (TZ 0) (TB 0) (TC 33))
            (rd_addr\[1\] (T0 1155000) (T1 320000) (TX 0) (TZ 0) (TB 0) (TC 16))
            (rd_addr\[2\] (T0 1155000) (T1 320000) (TX 0) (TZ 0) (TB 0) (TC 8))
            (rd_addr\[3\] (T0 1155000) (T1 320000) (TX 0) (TZ 0) (TB 0) (TC 4))
            (full_r (T0 1365000) (T1 110000) (TX 0) (TZ 0) (TB 0) (TC 4))
            (empty_r (T0 1330000) (T1 145000) (TX 0) (TZ 0) (TB 0) (TC 4))
            (wr_word_en\[0\] (T0 1445000) (T1 30000) (TX 0) (TZ 0) (TB 0) (TC 6))
            (wr_word_en\[1\] (T0 1455000) (T1 20000) (TX 0) (TZ 0) (TB 0) (TC 4))
            (wr_word_en\[2\] (T0 1455000) (T1 20000) (TX 0) (TZ 0) (TB 0) (TC 4))
            (wr_word_en\[3\] (T0 1455000) (T1 20000) (TX 0) (TZ 0) (TB 0) (TC 4))
            (wr_word_en\[4\] (T0 1455000) (T1 20000) (TX 0) (TZ 0) (TB 0) (TC 4))
            (wr_word_en\[5\] (T0 1455000) (T1 20000) (TX 0) (TZ 0) (TB 0) (TC 4))
            (wr_word_en\[6\] (T0 1455000) (T1 20000) (TX 0) (TZ 0) (TB 0) (TC 4))
            (wr_word_en\[7\] (T0 1455000) (T1 20000) (TX 0) (TZ 0) (TB 0) (TC 4))
            (wr_word_en\[8\] (T0 1455000) (T1 20000) (TX 0) (TZ 0) (TB 0) (TC 4))
            (wr_word_en\[9\] (T0 1455000) (T1 20000) (TX 0) (TZ 0) (TB 0) (TC 4))
            (wr_word_en\[10\] (T0 1455000) (T1 20000) (TX 0) (TZ 0) (TB 0) (TC 4))
            (wr_word_en\[11\] (T0 1455000) (T1 20000) (TX 0) (TZ 0) (TB 0) (TC 4))
            (wr_word_en\[12\] (T0 1455000) (T1 20000) (TX 0) (TZ 0) (TB 0) (TC 4))
            (wr_word_en\[13\] (T0 1455000) (T1 20000) (TX 0) (TZ 0) (TB 0) (TC 4))
            (wr_word_en\[14\] (T0 1455000) (T1 20000) (TX 0) (TZ 0) (TB 0) (TC 4))
            (wr_word_en\[15\] (T0 1455000) (T1 20000) (TX 0) (TZ 0) (TB 0) (TC 4))
            (i\[0\] (T0 0) (T1 0) (TX 1475000) (TZ 0) (TB 0) (TC 0))
            (i\[1\] (T0 0) (T1 0) (TX 1475000) (TZ 0) (TB 0) (TC 0))
            (i\[2\] (T0 0) (T1 0) (TX 1475000) (TZ 0) (TB 0) (TC 0))
            (i\[3\] (T0 0) (T1 0) (TX 1475000) (TZ 0) (TB 0) (TC 0))
            (i\[4\] (T0 0) (T1 0) (TX 1475000) (TZ 0) (TB 0) (TC 0))
            (i\[5\] (T0 0) (T1 0) (TX 1475000) (TZ 0) (TB 0) (TC 0))
            (i\[6\] (T0 0) (T1 0) (TX 1475000) (TZ 0) (TB 0) (TC 0))
            (i\[7\] (T0 0) (T1 0) (TX 1475000) (TZ 0) (TB 0) (TC 0))
            (i\[8\] (T0 0) (T1 0) (TX 1475000) (TZ 0) (TB 0) (TC 0))
            (i\[9\] (T0 0) (T1 0) (TX 1475000) (TZ 0) (TB 0) (TC 0))
            (i\[10\] (T0 0) (T1 0) (TX 1475000) (TZ 0) (TB 0) (TC 0))
            (i\[11\] (T0 0) (T1 0) (TX 1475000) (TZ 0) (TB 0) (TC 0))
            (i\[12\] (T0 0) (T1 0) (TX 1475000) (TZ 0) (TB 0) (TC 0))
            (i\[13\] (T0 0) (T1 0) (TX 1475000) (TZ 0) (TB 0) (TC 0))
            (i\[14\] (T0 0) (T1 0) (TX 1475000) (TZ 0) (TB 0) (TC 0))
            (i\[15\] (T0 0) (T1 0) (TX 1475000) (TZ 0) (TB 0) (TC 0))
            (i\[16\] (T0 0) (T1 0) (TX 1475000) (TZ 0) (TB 0) (TC 0))
            (i\[17\] (T0 0) (T1 0) (TX 1475000) (TZ 0) (TB 0) (TC 0))
            (i\[18\] (T0 0) (T1 0) (TX 1475000) (TZ 0) (TB 0) (TC 0))
            (i\[19\] (T0 0) (T1 0) (TX 1475000) (TZ 0) (TB 0) (TC 0))
            (i\[20\] (T0 0) (T1 0) (TX 1475000) (TZ 0) (TB 0) (TC 0))
            (i\[21\] (T0 0) (T1 0) (TX 1475000) (TZ 0) (TB 0) (TC 0))
            (i\[22\] (T0 0) (T1 0) (TX 1475000) (TZ 0) (TB 0) (TC 0))
            (i\[23\] (T0 0) (T1 0) (TX 1475000) (TZ 0) (TB 0) (TC 0))
            (i\[24\] (T0 0) (T1 0) (TX 1475000) (TZ 0) (TB 0) (TC 0))
            (i\[25\] (T0 0) (T1 0) (TX 1475000) (TZ 0) (TB 0) (TC 0))
            (i\[26\] (T0 0) (T1 0) (TX 1475000) (TZ 0) (TB 0) (TC 0))
            (i\[27\] (T0 0) (T1 0) (TX 1475000) (TZ 0) (TB 0) (TC 0))
            (i\[28\] (T0 0) (T1 0) (TX 1475000) (TZ 0) (TB 0) (TC 0))
            (i\[29\] (T0 0) (T1 0) (TX 1475000) (TZ 0) (TB 0) (TC 0))
            (i\[30\] (T0 0) (T1 0) (TX 1475000) (TZ 0) (TB 0) (TC 0))
            (i\[31\] (T0 0) (T1 0) (TX 1475000) (TZ 0) (TB 0) (TC 0))
            (DEPTH\[0\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DEPTH\[1\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DEPTH\[2\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DEPTH\[3\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DEPTH\[4\] (T0 0) (T1 1475000) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DEPTH\[5\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DEPTH\[6\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DEPTH\[7\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DEPTH\[8\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DEPTH\[9\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DEPTH\[10\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DEPTH\[11\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DEPTH\[12\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DEPTH\[13\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DEPTH\[14\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DEPTH\[15\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DEPTH\[16\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DEPTH\[17\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DEPTH\[18\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DEPTH\[19\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DEPTH\[20\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DEPTH\[21\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DEPTH\[22\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DEPTH\[23\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DEPTH\[24\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DEPTH\[25\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DEPTH\[26\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DEPTH\[27\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DEPTH\[28\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DEPTH\[29\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DEPTH\[30\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DEPTH\[31\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DW\[0\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DW\[1\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DW\[2\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DW\[3\] (T0 0) (T1 1475000) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DW\[4\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DW\[5\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DW\[6\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DW\[7\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DW\[8\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DW\[9\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DW\[10\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DW\[11\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DW\[12\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DW\[13\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DW\[14\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DW\[15\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DW\[16\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DW\[17\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DW\[18\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DW\[19\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DW\[20\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DW\[21\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DW\[22\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DW\[23\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DW\[24\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DW\[25\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DW\[26\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DW\[27\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DW\[28\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DW\[29\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DW\[30\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (DW\[31\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (ADDR\[0\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (ADDR\[1\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (ADDR\[2\] (T0 0) (T1 1475000) (TX 0) (TZ 0) (TB 0) (TC 0))
            (ADDR\[3\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (ADDR\[4\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (ADDR\[5\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (ADDR\[6\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (ADDR\[7\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (ADDR\[8\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (ADDR\[9\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (ADDR\[10\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (ADDR\[11\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (ADDR\[12\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (ADDR\[13\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (ADDR\[14\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (ADDR\[15\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (ADDR\[16\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (ADDR\[17\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (ADDR\[18\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (ADDR\[19\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (ADDR\[20\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (ADDR\[21\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (ADDR\[22\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (ADDR\[23\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (ADDR\[24\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (ADDR\[25\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (ADDR\[26\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (ADDR\[27\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (ADDR\[28\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (ADDR\[29\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (ADDR\[30\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
            (ADDR\[31\] (T0 1475000) (T1 0) (TX 0) (TZ 0) (TB 0) (TC 0))
         )
      )
   )
)



## How we use SAIF in tools

In synthesis or power analysis tools like Cadence Genus, the SAIF file is read and mapped to the design hierarchy. The tool uses the recorded switching activity along with capacitance and voltage information to compute dynamic power. Designers can then analyze reports to identify power hotspots and apply optimizations such as clock gating or logic restructuring,power gating other low power methodologies.

##  Practical significance in your flow (RTL → GDS)

In a typical flow:

Simulate design with real workload

Generate SAIF

Read SAIF in Genus for power optimization

Use in Innovus for post-layout power analysis

Verify power meets specification

---

### 2️ Genus Synthesis

Cadene Genus is used to map RTL to standard cells with timing constraints applied via SDC. SAIF based synthesis is done to generate the PPA reports.Cadence Genus is an advanced logic synthesis tool used to convert RTL designs into optimized gate-level implementations while meeting timing, area, power, and testability requirements. It supports modern low-power methodologies such as power gating, multi-supply voltage domains, and clock gating, enabling designers to build energy-efficient ASICs and SoCs. Genus integrates Design for Test (DFT) capabilities to insert scan chains and improve test coverage, ensuring manufacturability and reliability. It also supports constraint-driven optimization, multi-corner multi-mode (MCMM) analysis, and switching activity-based power estimation using SAIF or VCD files. Overall, Genus plays a critical role in achieving low-power, high-performance, and testable digital designs before physical implementation tools like Innovus.

# ==============================================================
# Cadence Genus Common UI Setup File for FIFO.v
# ==============================================================

# ---- 1. Design & Directory Setup ----
set DESIGN_NAME "FIFO_45NM"
set RTL_DIR "/home/Mtech2413/verilog/multibit_fifo/" # this is the design location.
set LIB_DIR     "/home/install/FOUNDRY/digital/45nm/"
set PHY_DIR    "/home/install/FOUNDRY/digital/45nm/"
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

# Read standard cell libraries (timing models) 45NM
read_lib  "$LIB_DIR/LIBS/lib/min/MEM2_512X32_slow.lib \
 	   $LIB_DIR/LIBS/lib/min/fast.lib \
	   $LIB_DIR/LIBS/lib/max/MEM2_512X32_slow.lib"
	   $LIB_DIR/LIBS/lib/max/slow.lib\
	   $LIB_DIR/dig/lib/fast.lib\
	   $LIB_DIR/dig/lib/slow.lib\
	   $LIB_DIR/dig/lib/typical.lib"
           


#read_physical -lef "$PHY_DIR/LIBS/lef/MEM2_512X32.lef\
		    $PHY_DIR/LIBS/lef/gsclib045.fixed.lef\
		    $PHY_DIR/LIBS/lef/gsclib045.fixed2.lef\
		    $PHY_DIR/dig/lef/gsclib045_tech.lef\
		    $PHY_DIR/dig/lef/gsclib045_macro.lef"
# ---- 3. Read HDL ----
read_hdl "$RTL_DIR/multibit_fifo.v"

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
Here we can do cpf,dft,multi_supply voltage and level shifter cell can be added based on over design synthesis.

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

## sdc file design

## What is an SDC file 

An SDC (Synopsys Design Constraints) file is a timing constraint file used in digital design flows to describe the timing environment and requirements of a circuit to EDA tools such as synthesis, place-and-route, and static timing analysis tools. It defines information like clock characteristics, input and output timing relationships, clock uncertainty, transition times, and timing exceptions so that the tools can optimize the design to meet performance goals under realistic operating conditions. Without an SDC file, the tools would assume ideal conditions, which can lead to incorrect timing analysis and unreliable hardware behavior.

## Components of an SDC file 

An SDC file typically contains several key components including clock definitions that specify frequency and waveform, clock properties such as uncertainty and transition to model real clock behavior, input and output delay constraints to represent interactions with external devices, and timing exceptions like false paths or multicycle paths to guide analysis. It may also include environmental constraints such as load, driving strength, and operating conditions. Together, these components provide a complete timing model that allows the design tools to accurately analyze and optimize the circuit.

## Clock creation line explanation 

The line create_clock -name clk -period 10 -waveform {0 5} [get_ports "clk"] creates a primary clock named “clk” on the input port clk with a period of 10 nanoseconds, corresponding to a frequency of 100 MHz. The waveform specification {0 5} indicates that the clock rises at 0 ns and falls at 5 ns, meaning it has a 50% duty cycle. This command informs the tool about the operating speed of the design so that timing paths can be evaluated against the correct clock reference.

## Clock transition lines explanation 

The commands set_clock_transition -rise 0.1 and set_clock_transition -fall 0.1 specify that the rising and falling edges of the clock have a transition (slew) time of 0.1 ns. This models the fact that real clock signals do not switch instantaneously and helps the tool estimate delays more accurately because cell delays depend on input slew. Providing realistic transition values improves timing accuracy and optimization.

## Clock uncertainty line explanation 

The command set_clock_uncertainty 0.01 [get_ports "clk"] introduces a timing margin of 0.01 ns to account for clock jitter, skew, and process variations. By adding uncertainty, the timing analysis becomes slightly pessimistic, ensuring that the design remains robust under real operating conditions where the clock may not arrive perfectly aligned across all registers.

## Input delay lines explanation 

The input delay commands such as set_input_delay -max 1.0 applied to ports like rst_n, wr_en, rd_en, and wdata indicate that signals coming from external circuitry may arrive up to 1 ns after the clock edge. This models the behavior of upstream devices such as external flip-flops or controllers and allows the tool to analyze input timing paths correctly. Without these constraints, the tool would assume that inputs arrive immediately at the clock edge, which is unrealistic.

## Output delay lines explanation 

The output delay commands like set_output_delay -max 1.0 for ports such as rdata, full, and empty specify that downstream devices expect valid output data within 1 ns after the clock edge. This models the timing requirement of external receiving components and ensures that the design meets system-level timing expectations when driving outputs.

## Why SDC constraints are important 

SDC constraints are essential because they allow EDA tools to optimize and verify the design based on real system timing conditions rather than ideal assumptions. Accurate constraints ensure proper setup and hold timing analysis, guide buffer insertion and sizing, and help avoid timing violations after fabrication. Properly written SDC files are critical for achieving timing closure and ensuring reliable silicon performance. 
the sdc script for the fifo design is as follows.

create_clock -name clk -period 10 -waveform {0 5} [get_ports "clk"]
set_clock_transition -rise 0.1 [get_clocks "clk"]
set_clock_transition -fall 0.1 [get_clocks "clk"]
set_clock_uncertainty 0.01 [get_ports "clk"]
set_input_delay -max 1.0 [get_ports "rst_n"] -clock [get_clocks "clk"]
set_input_delay -max 1.0 [get_ports "wr_en"] -clock [get_clocks "clk"]
set_input_delay -max 1.0 [get_ports "rd_en"] -clock [get_clocks "clk"]
set_input_delay -max 1.0 [get_ports "wdata"] -clock [get_clocks "clk"]
set_output_delay -max 1.0 [get_ports "rdata"] -clock [get_clocks "clk"]
set_output_delay -max 1.0 [get_ports "full"] -clock [get_clocks "clk"]
set_output_delay -max 1.0 [get_ports "empty"] -clock [get_clocks "clk"]

## ➡ Next: Result and Reports.
1.netlist:


// Generated by Cadence Genus(TM) Synthesis Solution 21.14-s082_1
// Generated on: Oct 30 2025 14:32:33 IST (Oct 30 2025 09:02:33 UTC)

// Verification Directory fv/sram 

module sram(clk, rst, en, we, re, addr, din, dout);
  input clk, rst, en, we, re;
  input [3:0] addr;
  input [7:0] din;
  output [7:0] dout;
  wire clk, rst, en, we, re;
  wire [3:0] addr;
  wire [7:0] din;
  wire [7:0] dout;
  wire [7:0] \mem[6] ;
  wire [7:0] \mem[4] ;
  wire [7:0] \mem[12] ;
  wire [7:0] \mem[10] ;
  wire [7:0] \mem[8] ;
  wire [7:0] \mem[11] ;
  wire [7:0] \mem[3] ;
  wire [7:0] \mem[15] ;
  wire [7:0] \mem[14] ;
  wire [7:0] \mem[2] ;
  wire [7:0] \mem[9] ;
  wire [7:0] \mem[1] ;
  wire [7:0] \mem[5] ;
  wire [7:0] \mem[7] ;
  wire [7:0] \mem[0] ;
  wire [7:0] \mem[13] ;
  wire UNCONNECTED, UNCONNECTED0, UNCONNECTED1, UNCONNECTED2,
       UNCONNECTED3, UNCONNECTED4, UNCONNECTED5, UNCONNECTED6;
  wire UNCONNECTED7, \dout[0]_446 , \dout[0]_454 , \dout[1]_447 ,
       \dout[2]_448 , \dout[3]_449 , \dout[4]_450 , \dout[5]_451 ;
  wire \dout[6]_452 , \dout[7]_453 , n_0, n_1, n_2, n_3, n_4, n_5;
  wire n_6, n_8, n_9, n_10, n_11, n_16, n_17, n_18;
  wire n_19, n_22, n_25, n_26, n_27, n_28, n_29, n_30;
  wire n_31, n_32, n_33, n_34, n_35, n_36, n_37, n_38;
  wire n_39, n_40, n_41, n_42, n_43, n_44, n_45, n_46;
  wire n_47, n_48, n_49, n_50, n_51, n_52, n_53, n_54;
  wire n_55, n_56, n_57, n_58, n_59, n_60, n_61, n_62;
  wire n_63, n_64, n_65, n_66, n_67, n_68, n_69, n_70;
  wire n_71, n_72, n_73, n_74, n_75, n_76, n_77, n_78;
  wire n_79, n_80, n_81, n_82, n_83, n_84, n_85, n_86;
  wire n_87, n_88, n_89, n_90, n_91, n_92, n_93, n_94;
  wire n_95, n_97, n_98, n_99, n_100, n_101, n_102, n_103;
  wire n_104, n_109, n_110, n_111, n_112, n_113, n_114, n_115;
  wire n_116, n_118, n_119, n_122, n_123, n_125, n_126, n_127;
  wire n_128, n_129, n_130, n_131, n_132, n_133, n_134, n_135;
  wire n_136, n_137, n_138, n_139, n_140, n_141, n_142, n_143;
  wire n_170, n_171, n_172, n_173, n_174, n_175, n_176, n_177;
  wire n_178;
  assign dout[0] = 1'b0;
  assign dout[1] = 1'b0;
  assign dout[2] = 1'b0;
  assign dout[3] = 1'b0;
  assign dout[4] = 1'b0;
  assign dout[5] = 1'b0;
  assign dout[6] = 1'b0;
  assign dout[7] = 1'b0;
  TBUFX1 g189__2398(.A (\dout[5]_451 ), .OE (\dout[0]_454 ), .Y
       (dout[5]));
  TBUFX1 g193__5107(.A (\dout[1]_447 ), .OE (\dout[0]_454 ), .Y
       (dout[1]));
  TBUFX1 g188__6260(.A (\dout[6]_452 ), .OE (\dout[0]_454 ), .Y
       (dout[6]));
  TBUFX1 g187__4319(.A (\dout[7]_453 ), .OE (\dout[0]_454 ), .Y
       (dout[7]));
  TBUFX1 g190__8428(.A (\dout[4]_450 ), .OE (\dout[0]_454 ), .Y
       (dout[4]));
  TBUFX1 g191__5526(.A (\dout[3]_449 ), .OE (\dout[0]_454 ), .Y
       (dout[3]));
  TBUFX1 g192__6783(.A (\dout[2]_448 ), .OE (\dout[0]_454 ), .Y
       (dout[2]));
  TBUFX1 g194__3680(.A (\dout[0]_446 ), .OE (\dout[0]_454 ), .Y
       (dout[0]));
  DFFNSRXL \dout_reg[1]196 (.RN (1'b1), .SN (1'b1), .CKN (clk), .D
       (n_143), .Q (\dout[1]_447 ), .QN (UNCONNECTED));
  DFFNSRXL \dout_reg[5]200 (.RN (1'b1), .SN (1'b1), .CKN (clk), .D
       (n_142), .Q (\dout[5]_451 ), .QN (UNCONNECTED0));
  DFFNSRXL \dout_reg[7]202 (.RN (1'b1), .SN (1'b1), .CKN (clk), .D
       (n_136), .Q (\dout[7]_453 ), .QN (UNCONNECTED1));
  DFFNSRXL \dout_reg[0]195 (.RN (1'b1), .SN (1'b1), .CKN (clk), .D
       (n_138), .Q (\dout[0]_446 ), .QN (UNCONNECTED2));
  DFFNSRXL \dout_reg[6]201 (.RN (1'b1), .SN (1'b1), .CKN (clk), .D
       (n_141), .Q (\dout[6]_452 ), .QN (UNCONNECTED3));
  DFFNSRXL \dout_reg[3]198 (.RN (1'b1), .SN (1'b1), .CKN (clk), .D
       (n_137), .Q (\dout[3]_449 ), .QN (UNCONNECTED4));
  DFFNSRXL \dout_reg[2]197 (.RN (1'b1), .SN (1'b1), .CKN (clk), .D
       (n_139), .Q (\dout[2]_448 ), .QN (UNCONNECTED5));
  DFFNSRXL \dout_reg[4]199 (.RN (1'b1), .SN (1'b1), .CKN (clk), .D
       (n_140), .Q (\dout[4]_450 ), .QN (UNCONNECTED6));
  NAND4XL g4781__1617(.A (n_135), .B (n_18), .C (n_42), .D (n_79), .Y
       (n_143));
  NAND4XL g4775__2802(.A (n_134), .B (n_22), .C (n_65), .D (n_64), .Y
       (n_142));
  NAND4XL g4780__1705(.A (n_128), .B (n_31), .C (n_83), .D (n_88), .Y
       (n_141));
  NAND4XL g4776__5122(.A (n_131), .B (n_25), .C (n_95), .D (n_98), .Y
       (n_140));
  NAND4XL g4774__8246(.A (n_127), .B (n_17), .C (n_100), .D (n_80), .Y
       (n_139));
  NAND4XL g4777__7098(.A (n_132), .B (n_19), .C (n_86), .D (n_90), .Y
       (n_138));
  NAND4XL g4778__6131(.A (n_133), .B (n_33), .C (n_84), .D (n_85), .Y
       (n_137));
  NAND4XL g4779__1881(.A (n_129), .B (n_27), .C (n_82), .D (n_97), .Y
       (n_136));
  AOI211X1 g4784__5115(.A0 (\mem[6] [1]), .A1 (n_74), .B0 (n_76), .C0
       (n_123), .Y (n_135));
  AOI211X1 g4785__7482(.A0 (\mem[4] [5]), .A1 (n_77), .B0 (n_63), .C0
       (n_122), .Y (n_134));
  AOI211X1 g4789__4733(.A0 (\mem[12] [3]), .A1 (n_130), .B0 (n_39), .C0
       (n_111), .Y (n_133));
  AOI211X1 g4782__6161(.A0 (\mem[10] [0]), .A1 (n_126), .B0 (n_37), .C0
       (n_115), .Y (n_132));
  AOI211X1 g4783__9315(.A0 (\mem[12] [4]), .A1 (n_130), .B0 (n_32), .C0
       (n_116), .Y (n_131));
  AOI211X1 g4786__9945(.A0 (\mem[8] [7]), .A1 (n_99), .B0 (n_28), .C0
       (n_114), .Y (n_129));
  AOI211X1 g4787__2883(.A0 (\mem[12] [6]), .A1 (n_130), .B0 (n_29), .C0
       (n_112), .Y (n_128));
  AOI211X1 g4788__2346(.A0 (\mem[10] [2]), .A1 (n_126), .B0 (n_35), .C0
       (n_113), .Y (n_127));
  SDFFRHQX1 \mem_reg[11][2] (.RN (n_125), .CK (clk), .D (\mem[11] [2]),
       .SI (din[2]), .SE (n_170), .Q (\mem[11] [2]));
  SDFFRHQX1 \mem_reg[11][1] (.RN (n_125), .CK (clk), .D (\mem[11] [1]),
       .SI (din[1]), .SE (n_170), .Q (\mem[11] [1]));
  SDFFRHQX1 \mem_reg[11][0] (.RN (n_125), .CK (clk), .D (\mem[11] [0]),
       .SI (din[0]), .SE (n_170), .Q (\mem[11] [0]));
  SDFFRHQX1 \mem_reg[11][3] (.RN (n_125), .CK (clk), .D (\mem[11] [3]),
       .SI (din[3]), .SE (n_170), .Q (\mem[11] [3]));
  SDFFRHQX1 \mem_reg[11][6] (.RN (n_125), .CK (clk), .D (\mem[11] [6]),
       .SI (din[6]), .SE (n_170), .Q (\mem[11] [6]));
  SDFFRHQX1 \mem_reg[11][5] (.RN (n_125), .CK (clk), .D (\mem[11] [5]),
       .SI (din[5]), .SE (n_170), .Q (\mem[11] [5]));
  SDFFRHQX1 \mem_reg[11][4] (.RN (n_125), .CK (clk), .D (\mem[11] [4]),
       .SI (din[4]), .SE (n_170), .Q (\mem[11] [4]));
  SDFFRHQX1 \mem_reg[11][7] (.RN (n_125), .CK (clk), .D (\mem[11] [7]),
       .SI (din[7]), .SE (n_170), .Q (\mem[11] [7]));
  NAND4XL g4791__1666(.A (n_92), .B (n_34), .C (n_36), .D (n_91), .Y
       (n_123));
  NAND4XL g4790__7410(.A (n_81), .B (n_26), .C (n_30), .D (n_93), .Y
       (n_122));
  SDFFRHQX1 \mem_reg[3][0] (.RN (n_125), .CK (clk), .D (\mem[3] [0]),
       .SI (din[0]), .SE (n_173), .Q (\mem[3] [0]));
  SDFFRHQX1 \mem_reg[3][1] (.RN (n_125), .CK (clk), .D (\mem[3] [1]),
       .SI (din[1]), .SE (n_173), .Q (\mem[3] [1]));
  SDFFRHQX1 \mem_reg[3][2] (.RN (n_125), .CK (clk), .D (\mem[3] [2]),
       .SI (din[2]), .SE (n_173), .Q (\mem[3] [2]));
  SDFFRHQX1 \mem_reg[3][3] (.RN (n_125), .CK (clk), .D (\mem[3] [3]),
       .SI (din[3]), .SE (n_173), .Q (\mem[3] [3]));
  SDFFRHQX1 \mem_reg[3][4] (.RN (n_125), .CK (clk), .D (\mem[3] [4]),
       .SI (din[4]), .SE (n_173), .Q (\mem[3] [4]));
  SDFFRHQX1 \mem_reg[3][5] (.RN (n_125), .CK (clk), .D (\mem[3] [5]),
       .SI (din[5]), .SE (n_173), .Q (\mem[3] [5]));
  SDFFRHQX1 \mem_reg[3][6] (.RN (n_125), .CK (clk), .D (\mem[3] [6]),
       .SI (din[6]), .SE (n_173), .Q (\mem[3] [6]));
  SDFFRHQX1 \mem_reg[3][7] (.RN (n_125), .CK (clk), .D (\mem[3] [7]),
       .SI (din[7]), .SE (n_173), .Q (\mem[3] [7]));
  SDFFRHQX1 \mem_reg[6][0] (.RN (n_125), .CK (clk), .D (\mem[6] [0]),
       .SI (din[0]), .SE (n_172), .Q (\mem[6] [0]));
  SDFFRHQX1 \mem_reg[6][1] (.RN (n_125), .CK (clk), .D (\mem[6] [1]),
       .SI (din[1]), .SE (n_172), .Q (\mem[6] [1]));
  SDFFRHQX1 \mem_reg[6][2] (.RN (n_125), .CK (clk), .D (\mem[6] [2]),
       .SI (din[2]), .SE (n_172), .Q (\mem[6] [2]));
  SDFFRHQX1 \mem_reg[6][3] (.RN (n_125), .CK (clk), .D (\mem[6] [3]),
       .SI (din[3]), .SE (n_172), .Q (\mem[6] [3]));
  SDFFRHQX1 \mem_reg[6][4] (.RN (n_125), .CK (clk), .D (\mem[6] [4]),
       .SI (din[4]), .SE (n_172), .Q (\mem[6] [4]));
  SDFFRHQX1 \mem_reg[6][5] (.RN (n_125), .CK (clk), .D (\mem[6] [5]),
       .SI (din[5]), .SE (n_172), .Q (\mem[6] [5]));
  SDFFRHQX1 \mem_reg[6][6] (.RN (n_125), .CK (clk), .D (\mem[6] [6]),
       .SI (din[6]), .SE (n_172), .Q (\mem[6] [6]));
  SDFFRHQX1 \mem_reg[6][7] (.RN (n_125), .CK (clk), .D (\mem[6] [7]),
       .SI (din[7]), .SE (n_172), .Q (\mem[6] [7]));
  SDFFRHQX1 \mem_reg[10][0] (.RN (n_125), .CK (clk), .D (din[0]), .SI
       (\mem[10] [0]), .SE (n_119), .Q (\mem[10] [0]));
  SDFFRHQX1 \mem_reg[10][1] (.RN (n_125), .CK (clk), .D (din[1]), .SI
       (\mem[10] [1]), .SE (n_119), .Q (\mem[10] [1]));
  SDFFRHQX1 \mem_reg[10][2] (.RN (n_125), .CK (clk), .D (din[2]), .SI
       (\mem[10] [2]), .SE (n_119), .Q (\mem[10] [2]));
  SDFFRHQX1 \mem_reg[15][7] (.RN (n_125), .CK (clk), .D (\mem[15] [7]),
       .SI (din[7]), .SE (n_171), .Q (\mem[15] [7]));
  SDFFRHQX1 \mem_reg[10][5] (.RN (n_125), .CK (clk), .D (din[5]), .SI
       (\mem[10] [5]), .SE (n_119), .Q (\mem[10] [5]));
  SDFFRHQX1 \mem_reg[10][6] (.RN (n_125), .CK (clk), .D (din[6]), .SI
       (\mem[10] [6]), .SE (n_119), .Q (\mem[10] [6]));
  SDFFRHQX1 \mem_reg[10][7] (.RN (n_125), .CK (clk), .D (din[7]), .SI
       (\mem[10] [7]), .SE (n_119), .Q (\mem[10] [7]));
  SDFFRHQX1 \mem_reg[10][4] (.RN (n_125), .CK (clk), .D (din[4]), .SI
       (\mem[10] [4]), .SE (n_119), .Q (\mem[10] [4]));
  SDFFRHQX1 \mem_reg[14][0] (.RN (n_125), .CK (clk), .D (din[0]), .SI
       (\mem[14] [0]), .SE (n_118), .Q (\mem[14] [0]));
  SDFFRHQX1 \mem_reg[14][1] (.RN (n_125), .CK (clk), .D (din[1]), .SI
       (\mem[14] [1]), .SE (n_118), .Q (\mem[14] [1]));
  SDFFRHQX1 \mem_reg[14][2] (.RN (n_125), .CK (clk), .D (din[2]), .SI
       (\mem[14] [2]), .SE (n_118), .Q (\mem[14] [2]));
  SDFFRHQX1 \mem_reg[14][3] (.RN (n_125), .CK (clk), .D (din[3]), .SI
       (\mem[14] [3]), .SE (n_118), .Q (\mem[14] [3]));
  SDFFRHQX1 \mem_reg[14][4] (.RN (n_125), .CK (clk), .D (din[4]), .SI
       (\mem[14] [4]), .SE (n_118), .Q (\mem[14] [4]));
  SDFFRHQX1 \mem_reg[14][5] (.RN (n_125), .CK (clk), .D (din[5]), .SI
       (\mem[14] [5]), .SE (n_118), .Q (\mem[14] [5]));
  SDFFRHQX1 \mem_reg[14][6] (.RN (n_125), .CK (clk), .D (din[6]), .SI
       (\mem[14] [6]), .SE (n_118), .Q (\mem[14] [6]));
  SDFFRHQX1 \mem_reg[14][7] (.RN (n_125), .CK (clk), .D (din[7]), .SI
       (\mem[14] [7]), .SE (n_118), .Q (\mem[14] [7]));
  SDFFRHQX1 \mem_reg[15][0] (.RN (n_125), .CK (clk), .D (\mem[15] [0]),
       .SI (din[0]), .SE (n_171), .Q (\mem[15] [0]));
  SDFFRHQX1 \mem_reg[15][1] (.RN (n_125), .CK (clk), .D (\mem[15] [1]),
       .SI (din[1]), .SE (n_171), .Q (\mem[15] [1]));
  SDFFRHQX1 \mem_reg[15][2] (.RN (n_125), .CK (clk), .D (\mem[15] [2]),
       .SI (din[2]), .SE (n_171), .Q (\mem[15] [2]));
  SDFFRHQX1 \mem_reg[15][3] (.RN (n_125), .CK (clk), .D (\mem[15] [3]),
       .SI (din[3]), .SE (n_171), .Q (\mem[15] [3]));
  SDFFRHQX1 \mem_reg[15][4] (.RN (n_125), .CK (clk), .D (\mem[15] [4]),
       .SI (din[4]), .SE (n_171), .Q (\mem[15] [4]));
  SDFFRHQX1 \mem_reg[15][5] (.RN (n_125), .CK (clk), .D (\mem[15] [5]),
       .SI (din[5]), .SE (n_171), .Q (\mem[15] [5]));
  SDFFRHQX1 \mem_reg[15][6] (.RN (n_125), .CK (clk), .D (\mem[15] [6]),
       .SI (din[6]), .SE (n_171), .Q (\mem[15] [6]));
  SDFFRHQX1 \mem_reg[10][3] (.RN (n_125), .CK (clk), .D (din[3]), .SI
       (\mem[10] [3]), .SE (n_119), .Q (\mem[10] [3]));
  NAND4XL g4792__6417(.A (n_70), .B (n_75), .C (n_68), .D (n_73), .Y
       (n_116));
  NAND4XL g4793__5477(.A (n_58), .B (n_55), .C (n_44), .D (n_46), .Y
       (n_115));
  NAND4XL g4794__2398(.A (n_48), .B (n_47), .C (n_54), .D (n_51), .Y
       (n_114));
  NAND4XL g4795__5107(.A (n_52), .B (n_50), .C (n_49), .D (n_45), .Y
       (n_113));
  NAND4XL g4796__6260(.A (n_78), .B (n_57), .C (n_53), .D (n_62), .Y
       (n_112));
  NAND4XL g4797__4319(.A (n_59), .B (n_43), .C (n_60), .D (n_61), .Y
       (n_111));
  SDFFRHQX1 \mem_reg[2][5] (.RN (n_125), .CK (clk), .D (\mem[2] [5]),
       .SI (din[5]), .SE (n_174), .Q (\mem[2] [5]));
  SDFFRHQX1 \mem_reg[9][5] (.RN (n_125), .CK (clk), .D (\mem[9] [5]),
       .SI (din[5]), .SE (n_176), .Q (\mem[9] [5]));
  SDFFRHQX1 \mem_reg[1][3] (.RN (n_125), .CK (clk), .D (din[3]), .SI
       (\mem[1] [3]), .SE (n_110), .Q (\mem[1] [3]));
  SDFFRHQX1 \mem_reg[5][5] (.RN (n_125), .CK (clk), .D (\mem[5] [5]),
       .SI (din[5]), .SE (n_175), .Q (\mem[5] [5]));
  SDFFRHQX1 \mem_reg[1][7] (.RN (n_125), .CK (clk), .D (din[7]), .SI
       (\mem[1] [7]), .SE (n_110), .Q (\mem[1] [7]));
  SDFFRHQX1 \mem_reg[1][6] (.RN (n_125), .CK (clk), .D (din[6]), .SI
       (\mem[1] [6]), .SE (n_110), .Q (\mem[1] [6]));
  SDFFRHQX1 \mem_reg[4][0] (.RN (n_125), .CK (clk), .D (din[0]), .SI
       (\mem[4] [0]), .SE (n_109), .Q (\mem[4] [0]));
  SDFFRHQX1 \mem_reg[4][1] (.RN (n_125), .CK (clk), .D (din[1]), .SI
       (\mem[4] [1]), .SE (n_109), .Q (\mem[4] [1]));
  SDFFRHQX1 \mem_reg[4][2] (.RN (n_125), .CK (clk), .D (din[2]), .SI
       (\mem[4] [2]), .SE (n_109), .Q (\mem[4] [2]));
  SDFFRHQX1 \mem_reg[4][3] (.RN (n_125), .CK (clk), .D (din[3]), .SI
       (\mem[4] [3]), .SE (n_109), .Q (\mem[4] [3]));
  SDFFRHQX1 \mem_reg[4][6] (.RN (n_125), .CK (clk), .D (din[6]), .SI
       (\mem[4] [6]), .SE (n_109), .Q (\mem[4] [6]));
  SDFFRHQX1 \mem_reg[4][7] (.RN (n_125), .CK (clk), .D (din[7]), .SI
       (\mem[4] [7]), .SE (n_109), .Q (\mem[4] [7]));
  SDFFRHQX1 \mem_reg[4][5] (.RN (n_125), .CK (clk), .D (din[5]), .SI
       (\mem[4] [5]), .SE (n_109), .Q (\mem[4] [5]));
  SDFFRHQX1 \mem_reg[1][0] (.RN (n_125), .CK (clk), .D (din[0]), .SI
       (\mem[1] [0]), .SE (n_110), .Q (\mem[1] [0]));
  SDFFRHQX1 \mem_reg[4][4] (.RN (n_125), .CK (clk), .D (din[4]), .SI
       (\mem[4] [4]), .SE (n_109), .Q (\mem[4] [4]));
  SDFFRHQX1 \mem_reg[7][0] (.RN (n_125), .CK (clk), .D (\mem[7] [0]),
       .SI (din[0]), .SE (n_177), .Q (\mem[7] [0]));
  SDFFRHQX1 \mem_reg[7][1] (.RN (n_125), .CK (clk), .D (\mem[7] [1]),
       .SI (din[1]), .SE (n_177), .Q (\mem[7] [1]));
  SDFFRHQX1 \mem_reg[7][2] (.RN (n_125), .CK (clk), .D (\mem[7] [2]),
       .SI (din[2]), .SE (n_177), .Q (\mem[7] [2]));
  SDFFRHQX1 \mem_reg[7][4] (.RN (n_125), .CK (clk), .D (\mem[7] [4]),
       .SI (din[4]), .SE (n_177), .Q (\mem[7] [4]));
  SDFFRHQX1 \mem_reg[7][5] (.RN (n_125), .CK (clk), .D (\mem[7] [5]),
       .SI (din[5]), .SE (n_177), .Q (\mem[7] [5]));
  SDFFRHQX1 \mem_reg[7][6] (.RN (n_125), .CK (clk), .D (\mem[7] [6]),
       .SI (din[6]), .SE (n_177), .Q (\mem[7] [6]));
  SDFFRHQX1 \mem_reg[7][7] (.RN (n_125), .CK (clk), .D (\mem[7] [7]),
       .SI (din[7]), .SE (n_177), .Q (\mem[7] [7]));
  SDFFRHQX1 \mem_reg[5][1] (.RN (n_125), .CK (clk), .D (\mem[5] [1]),
       .SI (din[1]), .SE (n_175), .Q (\mem[5] [1]));
  SDFFRHQX1 \mem_reg[7][3] (.RN (n_125), .CK (clk), .D (\mem[7] [3]),
       .SI (din[3]), .SE (n_177), .Q (\mem[7] [3]));
  SDFFRHQX1 \mem_reg[1][1] (.RN (n_125), .CK (clk), .D (din[1]), .SI
       (\mem[1] [1]), .SE (n_110), .Q (\mem[1] [1]));
  SDFFRHQX1 \mem_reg[1][2] (.RN (n_125), .CK (clk), .D (din[2]), .SI
       (\mem[1] [2]), .SE (n_110), .Q (\mem[1] [2]));
  SDFFRHQX1 \mem_reg[1][4] (.RN (n_125), .CK (clk), .D (din[4]), .SI
       (\mem[1] [4]), .SE (n_110), .Q (\mem[1] [4]));
  SDFFRHQX1 \mem_reg[1][5] (.RN (n_125), .CK (clk), .D (din[5]), .SI
       (\mem[1] [5]), .SE (n_110), .Q (\mem[1] [5]));
  SDFFRHQX1 \mem_reg[5][7] (.RN (n_125), .CK (clk), .D (\mem[5] [7]),
       .SI (din[7]), .SE (n_175), .Q (\mem[5] [7]));
  SDFFRHQX1 \mem_reg[2][1] (.RN (n_125), .CK (clk), .D (\mem[2] [1]),
       .SI (din[1]), .SE (n_174), .Q (\mem[2] [1]));
  SDFFRHQX1 \mem_reg[2][2] (.RN (n_125), .CK (clk), .D (\mem[2] [2]),
       .SI (din[2]), .SE (n_174), .Q (\mem[2] [2]));
  SDFFRHQX1 \mem_reg[2][3] (.RN (n_125), .CK (clk), .D (\mem[2] [3]),
       .SI (din[3]), .SE (n_174), .Q (\mem[2] [3]));
  SDFFRHQX1 \mem_reg[2][4] (.RN (n_125), .CK (clk), .D (\mem[2] [4]),
       .SI (din[4]), .SE (n_174), .Q (\mem[2] [4]));
  SDFFRHQX1 \mem_reg[2][6] (.RN (n_125), .CK (clk), .D (\mem[2] [6]),
       .SI (din[6]), .SE (n_174), .Q (\mem[2] [6]));
  SDFFRHQX1 \mem_reg[2][7] (.RN (n_125), .CK (clk), .D (\mem[2] [7]),
       .SI (din[7]), .SE (n_174), .Q (\mem[2] [7]));
  SDFFRHQX1 \mem_reg[5][0] (.RN (n_125), .CK (clk), .D (\mem[5] [0]),
       .SI (din[0]), .SE (n_175), .Q (\mem[5] [0]));
  SDFFRHQX1 \mem_reg[5][2] (.RN (n_125), .CK (clk), .D (\mem[5] [2]),
       .SI (din[2]), .SE (n_175), .Q (\mem[5] [2]));
  SDFFRHQX1 \mem_reg[5][3] (.RN (n_125), .CK (clk), .D (\mem[5] [3]),
       .SI (din[3]), .SE (n_175), .Q (\mem[5] [3]));
  SDFFRHQX1 \mem_reg[5][4] (.RN (n_125), .CK (clk), .D (\mem[5] [4]),
       .SI (din[4]), .SE (n_175), .Q (\mem[5] [4]));
  SDFFRHQX1 \mem_reg[5][6] (.RN (n_125), .CK (clk), .D (\mem[5] [6]),
       .SI (din[6]), .SE (n_175), .Q (\mem[5] [6]));
  SDFFRHQX1 \mem_reg[2][0] (.RN (n_125), .CK (clk), .D (\mem[2] [0]),
       .SI (din[0]), .SE (n_174), .Q (\mem[2] [0]));
  SDFFRHQX1 \mem_reg[9][1] (.RN (n_125), .CK (clk), .D (\mem[9] [1]),
       .SI (din[1]), .SE (n_176), .Q (\mem[9] [1]));
  SDFFRHQX1 \mem_reg[9][2] (.RN (n_125), .CK (clk), .D (\mem[9] [2]),
       .SI (din[2]), .SE (n_176), .Q (\mem[9] [2]));
  SDFFRHQX1 \mem_reg[9][3] (.RN (n_125), .CK (clk), .D (\mem[9] [3]),
       .SI (din[3]), .SE (n_176), .Q (\mem[9] [3]));
  SDFFRHQX1 \mem_reg[9][4] (.RN (n_125), .CK (clk), .D (\mem[9] [4]),
       .SI (din[4]), .SE (n_176), .Q (\mem[9] [4]));
  SDFFRHQX1 \mem_reg[9][6] (.RN (n_125), .CK (clk), .D (\mem[9] [6]),
       .SI (din[6]), .SE (n_176), .Q (\mem[9] [6]));
  SDFFRHQX1 \mem_reg[9][7] (.RN (n_125), .CK (clk), .D (\mem[9] [7]),
       .SI (din[7]), .SE (n_176), .Q (\mem[9] [7]));
  SDFFRHQX1 \mem_reg[9][0] (.RN (n_125), .CK (clk), .D (\mem[9] [0]),
       .SI (din[0]), .SE (n_176), .Q (\mem[9] [0]));
  SDFFRHQX1 \mem_reg[12][2] (.RN (n_125), .CK (clk), .D (din[2]), .SI
       (\mem[12] [2]), .SE (n_103), .Q (\mem[12] [2]));
  SDFFRHQX1 \mem_reg[0][1] (.RN (n_125), .CK (clk), .D (din[1]), .SI
       (\mem[0] [1]), .SE (n_104), .Q (\mem[0] [1]));
  SDFFRHQX1 \mem_reg[0][4] (.RN (n_125), .CK (clk), .D (din[4]), .SI
       (\mem[0] [4]), .SE (n_104), .Q (\mem[0] [4]));
  SDFFRHQX1 \mem_reg[13][1] (.RN (n_125), .CK (clk), .D (din[1]), .SI
       (\mem[13] [1]), .SE (n_101), .Q (\mem[13] [1]));
  SDFFRHQX1 \mem_reg[12][3] (.RN (n_125), .CK (clk), .D (din[3]), .SI
       (\mem[12] [3]), .SE (n_103), .Q (\mem[12] [3]));
  SDFFRHQX1 \mem_reg[8][7] (.RN (n_125), .CK (clk), .D (din[7]), .SI
       (\mem[8] [7]), .SE (n_102), .Q (\mem[8] [7]));
  SDFFRHQX1 \mem_reg[8][0] (.RN (n_125), .CK (clk), .D (din[0]), .SI
       (\mem[8] [0]), .SE (n_102), .Q (\mem[8] [0]));
  SDFFRHQX1 \mem_reg[8][1] (.RN (n_125), .CK (clk), .D (din[1]), .SI
       (\mem[8] [1]), .SE (n_102), .Q (\mem[8] [1]));
  SDFFRHQX1 \mem_reg[8][2] (.RN (n_125), .CK (clk), .D (din[2]), .SI
       (\mem[8] [2]), .SE (n_102), .Q (\mem[8] [2]));
  SDFFRHQX1 \mem_reg[8][5] (.RN (n_125), .CK (clk), .D (din[5]), .SI
       (\mem[8] [5]), .SE (n_102), .Q (\mem[8] [5]));
  SDFFRHQX1 \mem_reg[8][6] (.RN (n_125), .CK (clk), .D (din[6]), .SI
       (\mem[8] [6]), .SE (n_102), .Q (\mem[8] [6]));
  SDFFRHQX1 \mem_reg[8][4] (.RN (n_125), .CK (clk), .D (din[4]), .SI
       (\mem[8] [4]), .SE (n_102), .Q (\mem[8] [4]));
  SDFFRHQX1 \mem_reg[8][3] (.RN (n_125), .CK (clk), .D (din[3]), .SI
       (\mem[8] [3]), .SE (n_102), .Q (\mem[8] [3]));
  SDFFRHQX1 \mem_reg[12][0] (.RN (n_125), .CK (clk), .D (din[0]), .SI
       (\mem[12] [0]), .SE (n_103), .Q (\mem[12] [0]));
  SDFFRHQX1 \mem_reg[12][1] (.RN (n_125), .CK (clk), .D (din[1]), .SI
       (\mem[12] [1]), .SE (n_103), .Q (\mem[12] [1]));
  SDFFRHQX1 \mem_reg[13][5] (.RN (n_125), .CK (clk), .D (din[5]), .SI
       (\mem[13] [5]), .SE (n_101), .Q (\mem[13] [5]));
  SDFFRHQX1 \mem_reg[0][2] (.RN (n_125), .CK (clk), .D (din[2]), .SI
       (\mem[0] [2]), .SE (n_104), .Q (\mem[0] [2]));
  SDFFRHQX1 \mem_reg[12][7] (.RN (n_125), .CK (clk), .D (din[7]), .SI
       (\mem[12] [7]), .SE (n_103), .Q (\mem[12] [7]));
  SDFFRHQX1 \mem_reg[12][4] (.RN (n_125), .CK (clk), .D (din[4]), .SI
       (\mem[12] [4]), .SE (n_103), .Q (\mem[12] [4]));
  SDFFRHQX1 \mem_reg[0][0] (.RN (n_125), .CK (clk), .D (din[0]), .SI
       (\mem[0] [0]), .SE (n_104), .Q (\mem[0] [0]));
  SDFFRHQX1 \mem_reg[12][5] (.RN (n_125), .CK (clk), .D (din[5]), .SI
       (\mem[12] [5]), .SE (n_103), .Q (\mem[12] [5]));
  SDFFRHQX1 \mem_reg[0][3] (.RN (n_125), .CK (clk), .D (din[3]), .SI
       (\mem[0] [3]), .SE (n_104), .Q (\mem[0] [3]));
  SDFFRHQX1 \mem_reg[0][5] (.RN (n_125), .CK (clk), .D (din[5]), .SI
       (\mem[0] [5]), .SE (n_104), .Q (\mem[0] [5]));
  SDFFRHQX1 \mem_reg[0][6] (.RN (n_125), .CK (clk), .D (din[6]), .SI
       (\mem[0] [6]), .SE (n_104), .Q (\mem[0] [6]));
  SDFFRHQX1 \mem_reg[0][7] (.RN (n_125), .CK (clk), .D (din[7]), .SI
       (\mem[0] [7]), .SE (n_104), .Q (\mem[0] [7]));
  SDFFRHQX1 \mem_reg[13][7] (.RN (n_125), .CK (clk), .D (din[7]), .SI
       (\mem[13] [7]), .SE (n_101), .Q (\mem[13] [7]));
  SDFFRHQX1 \mem_reg[13][0] (.RN (n_125), .CK (clk), .D (din[0]), .SI
       (\mem[13] [0]), .SE (n_101), .Q (\mem[13] [0]));
  SDFFRHQX1 \mem_reg[13][2] (.RN (n_125), .CK (clk), .D (din[2]), .SI
       (\mem[13] [2]), .SE (n_101), .Q (\mem[13] [2]));
  SDFFRHQX1 \mem_reg[13][3] (.RN (n_125), .CK (clk), .D (din[3]), .SI
       (\mem[13] [3]), .SE (n_101), .Q (\mem[13] [3]));
  SDFFRHQX1 \mem_reg[13][4] (.RN (n_125), .CK (clk), .D (din[4]), .SI
       (\mem[13] [4]), .SE (n_101), .Q (\mem[13] [4]));
  SDFFRHQX1 \mem_reg[13][6] (.RN (n_125), .CK (clk), .D (din[6]), .SI
       (\mem[13] [6]), .SE (n_101), .Q (\mem[13] [6]));
  SDFFRHQX1 \mem_reg[12][6] (.RN (n_125), .CK (clk), .D (din[6]), .SI
       (\mem[12] [6]), .SE (n_103), .Q (\mem[12] [6]));
  AOI22X1 g4934__8428(.A0 (\mem[8] [2]), .A1 (n_99), .B0 (\mem[11]
       [2]), .B1 (n_94), .Y (n_100));
  AOI22X1 g4928__5526(.A0 (\mem[14] [4]), .A1 (n_178), .B0 (\mem[13]
       [4]), .B1 (n_87), .Y (n_98));
  AOI22X1 g4929__6783(.A0 (\mem[9] [7]), .A1 (n_38), .B0 (\mem[14]
       [7]), .B1 (n_178), .Y (n_97));
  AOI22X1 g4930__3680(.A0 (\mem[10] [4]), .A1 (n_126), .B0 (\mem[11]
       [4]), .B1 (n_94), .Y (n_95));
  AOI22X1 g4926__1617(.A0 (\mem[10] [5]), .A1 (n_126), .B0 (\mem[11]
       [5]), .B1 (n_94), .Y (n_93));
  AOI22X1 g4945__2802(.A0 (\mem[14] [1]), .A1 (n_178), .B0 (\mem[15]
       [1]), .B1 (n_89), .Y (n_92));
  AOI22X1 g4949__1705(.A0 (\mem[10] [1]), .A1 (n_126), .B0 (\mem[11]
       [1]), .B1 (n_94), .Y (n_91));
  AOI22X1 g4950__5122(.A0 (\mem[14] [0]), .A1 (n_178), .B0 (\mem[15]
       [0]), .B1 (n_89), .Y (n_90));
  AOI22X1 g4976__8246(.A0 (\mem[14] [6]), .A1 (n_178), .B0 (\mem[13]
       [6]), .B1 (n_87), .Y (n_88));
  AOI22X1 g4964__7098(.A0 (\mem[8] [0]), .A1 (n_99), .B0 (\mem[11]
       [0]), .B1 (n_94), .Y (n_86));
  AOI22X1 g4970__6131(.A0 (\mem[14] [3]), .A1 (n_178), .B0 (\mem[13]
       [3]), .B1 (n_87), .Y (n_85));
  AOI22X1 g4974__1881(.A0 (\mem[10] [3]), .A1 (n_126), .B0 (\mem[11]
       [3]), .B1 (n_94), .Y (n_84));
  AOI22X1 g4957__5115(.A0 (\mem[10] [6]), .A1 (n_126), .B0 (\mem[11]
       [6]), .B1 (n_94), .Y (n_83));
  AOI22X1 g4978__7482(.A0 (\mem[10] [7]), .A1 (n_126), .B0 (\mem[11]
       [7]), .B1 (n_94), .Y (n_82));
  AOI22X1 g4981__4733(.A0 (\mem[14] [5]), .A1 (n_178), .B0 (\mem[15]
       [5]), .B1 (n_89), .Y (n_81));
  AOI22X1 g4956__6161(.A0 (\mem[14] [2]), .A1 (n_178), .B0 (\mem[15]
       [2]), .B1 (n_89), .Y (n_80));
  AOI22X1 g4927__9945(.A0 (\mem[2] [1]), .A1 (n_72), .B0 (\mem[3] [1]),
       .B1 (n_71), .Y (n_79));
  AOI22X1 g4931__2883(.A0 (\mem[4] [6]), .A1 (n_77), .B0 (\mem[5] [6]),
       .B1 (n_69), .Y (n_78));
  AO22X1 g4932__2346(.A0 (\mem[0] [1]), .A1 (n_67), .B0 (\mem[1] [1]),
       .B1 (n_66), .Y (n_76));
  AOI22X1 g4936__1666(.A0 (\mem[6] [4]), .A1 (n_74), .B0 (\mem[7] [4]),
       .B1 (n_56), .Y (n_75));
  AOI22X1 g4937__7410(.A0 (\mem[2] [4]), .A1 (n_72), .B0 (\mem[3] [4]),
       .B1 (n_71), .Y (n_73));
  AOI22X1 g4939__6417(.A0 (\mem[4] [4]), .A1 (n_77), .B0 (\mem[5] [4]),
       .B1 (n_69), .Y (n_70));
  AOI22X1 g4940__5477(.A0 (\mem[0] [4]), .A1 (n_67), .B0 (\mem[1] [4]),
       .B1 (n_66), .Y (n_68));
  AOI22X1 g4943__2398(.A0 (\mem[6] [5]), .A1 (n_74), .B0 (\mem[5] [5]),
       .B1 (n_69), .Y (n_65));
  AOI22X1 g4944__5107(.A0 (\mem[2] [5]), .A1 (n_72), .B0 (\mem[3] [5]),
       .B1 (n_71), .Y (n_64));
  AO22X1 g4946__6260(.A0 (\mem[0] [5]), .A1 (n_67), .B0 (\mem[1] [5]),
       .B1 (n_66), .Y (n_63));
  AOI22X1 g4947__4319(.A0 (\mem[2] [6]), .A1 (n_72), .B0 (\mem[3] [6]),
       .B1 (n_71), .Y (n_62));
  AOI22X1 g4952__8428(.A0 (\mem[2] [3]), .A1 (n_72), .B0 (\mem[3] [3]),
       .B1 (n_71), .Y (n_61));
  AOI22X1 g4953__5526(.A0 (\mem[0] [3]), .A1 (n_67), .B0 (\mem[1] [3]),
       .B1 (n_66), .Y (n_60));
  AOI22X1 g4954__6783(.A0 (\mem[4] [3]), .A1 (n_77), .B0 (\mem[5] [3]),
       .B1 (n_69), .Y (n_59));
  AOI22X1 g4958__3680(.A0 (\mem[4] [0]), .A1 (n_77), .B0 (\mem[5] [0]),
       .B1 (n_69), .Y (n_58));
  AOI22X1 g4960__1617(.A0 (\mem[6] [6]), .A1 (n_74), .B0 (\mem[7] [6]),
       .B1 (n_56), .Y (n_57));
  AOI22X1 g4961__2802(.A0 (\mem[6] [0]), .A1 (n_74), .B0 (\mem[7] [0]),
       .B1 (n_56), .Y (n_55));
  AOI22X1 g4973__1705(.A0 (\mem[0] [7]), .A1 (n_67), .B0 (\mem[1] [7]),
       .B1 (n_66), .Y (n_54));
  AOI22X1 g4963__5122(.A0 (\mem[0] [6]), .A1 (n_67), .B0 (\mem[1] [6]),
       .B1 (n_66), .Y (n_53));
  AOI22X1 g4965__8246(.A0 (\mem[4] [2]), .A1 (n_77), .B0 (\mem[5] [2]),
       .B1 (n_69), .Y (n_52));
  AOI22X1 g4966__7098(.A0 (\mem[2] [7]), .A1 (n_72), .B0 (\mem[3] [7]),
       .B1 (n_71), .Y (n_51));
  AOI22X1 g4967__6131(.A0 (\mem[6] [2]), .A1 (n_74), .B0 (\mem[7] [2]),
       .B1 (n_56), .Y (n_50));
  AOI22X1 g4969__1881(.A0 (\mem[0] [2]), .A1 (n_67), .B0 (\mem[1] [2]),
       .B1 (n_66), .Y (n_49));
  AOI22X1 g4971__5115(.A0 (\mem[4] [7]), .A1 (n_77), .B0 (\mem[5] [7]),
       .B1 (n_69), .Y (n_48));
  AOI22X1 g4972__7482(.A0 (\mem[6] [7]), .A1 (n_74), .B0 (\mem[7] [7]),
       .B1 (n_56), .Y (n_47));
  AOI22X1 g4975__4733(.A0 (\mem[2] [0]), .A1 (n_72), .B0 (\mem[3] [0]),
       .B1 (n_71), .Y (n_46));
  AOI22X1 g4962__6161(.A0 (\mem[2] [2]), .A1 (n_72), .B0 (\mem[3] [2]),
       .B1 (n_71), .Y (n_45));
  AOI22X1 g4977__9315(.A0 (\mem[0] [0]), .A1 (n_67), .B0 (\mem[1] [0]),
       .B1 (n_66), .Y (n_44));
  AOI22X1 g4979__9945(.A0 (\mem[6] [3]), .A1 (n_74), .B0 (\mem[7] [3]),
       .B1 (n_56), .Y (n_43));
  AOI22X1 g4980__2883(.A0 (\mem[4] [1]), .A1 (n_77), .B0 (\mem[7] [1]),
       .B1 (n_56), .Y (n_42));
  NAND2XL g4995__1666(.A (n_178), .B (n_40), .Y (n_118));
  NAND2XL g4991__7410(.A (n_126), .B (n_40), .Y (n_119));
  AO22X1 g4948__2398(.A0 (\mem[8] [3]), .A1 (n_99), .B0 (\mem[9] [3]),
       .B1 (n_38), .Y (n_39));
  AO22X1 g4935__5107(.A0 (\mem[12] [0]), .A1 (n_130), .B0 (\mem[13]
       [0]), .B1 (n_87), .Y (n_37));
  AOI22X1 g4938__6260(.A0 (\mem[12] [1]), .A1 (n_130), .B0 (\mem[13]
       [1]), .B1 (n_87), .Y (n_36));
  AO22X1 g4941__4319(.A0 (\mem[12] [2]), .A1 (n_130), .B0 (\mem[13]
       [2]), .B1 (n_87), .Y (n_35));
  AOI22X1 g4942__8428(.A0 (\mem[8] [1]), .A1 (n_99), .B0 (\mem[9] [1]),
       .B1 (n_38), .Y (n_34));
  NAND2XL g4983__5526(.A (n_89), .B (\mem[15] [3]), .Y (n_33));
  AO22X1 g4933__6783(.A0 (\mem[8] [4]), .A1 (n_99), .B0 (\mem[9] [4]),
       .B1 (n_38), .Y (n_32));
  NAND2XL g4985__1705(.A (n_89), .B (\mem[15] [6]), .Y (n_31));
  AOI22X1 g4955__5122(.A0 (\mem[12] [5]), .A1 (n_130), .B0 (\mem[13]
       [5]), .B1 (n_87), .Y (n_30));
  AO22X1 g4959__8246(.A0 (\mem[8] [6]), .A1 (n_99), .B0 (\mem[9] [6]),
       .B1 (n_38), .Y (n_29));
  AO22X1 g4968__7098(.A0 (\mem[12] [7]), .A1 (n_130), .B0 (\mem[13]
       [7]), .B1 (n_87), .Y (n_28));
  NAND2XL g4982__6131(.A (n_89), .B (\mem[15] [7]), .Y (n_27));
  AOI22X1 g4951__1881(.A0 (\mem[8] [5]), .A1 (n_99), .B0 (\mem[9] [5]),
       .B1 (n_38), .Y (n_26));
  NAND2XL g4986__5115(.A (n_89), .B (\mem[15] [4]), .Y (n_25));
  NAND2XL g4998__7482(.A (n_66), .B (n_40), .Y (n_110));
  NAND2XL g4988__6161(.A (n_77), .B (n_40), .Y (n_109));
  NAND2XL g4984__9315(.A (n_56), .B (\mem[7] [5]), .Y (n_22));
  NAND2XL g5022__9945(.A (n_87), .B (n_40), .Y (n_101));
  NAND2XL g4993__2883(.A (n_130), .B (n_40), .Y (n_103));
  NAND2XL g4994__2346(.A (n_67), .B (n_40), .Y (n_104));
  NAND2XL g4992__1666(.A (n_99), .B (n_40), .Y (n_102));
  NAND2XL g5003__7410(.A (n_38), .B (\mem[9] [0]), .Y (n_19));
  NAND2XL g5004__6417(.A (n_69), .B (\mem[5] [1]), .Y (n_18));
  NAND2XL g5002__5477(.A (n_38), .B (\mem[9] [2]), .Y (n_17));
  NOR2BX1 g5010__2398(.AN (addr[0]), .B (n_16), .Y (n_94));
  NOR2XL g5006__5107(.A (addr[0]), .B (n_16), .Y (n_126));
  NOR3X1 g5016__4319(.A (addr[2]), .B (addr[3]), .C (n_9), .Y (n_66));
  NOR3X1 g5018__8428(.A (n_3), .B (addr[3]), .C (n_10), .Y (n_71));
  NOR2XL g5008__5526(.A (addr[1]), .B (n_11), .Y (n_77));
  AND2X1 g5009__6783(.A (addr[0]), .B (n_6), .Y (n_89));
  NOR2XL g5007__3680(.A (n_2), .B (n_11), .Y (n_74));
  NAND2BX1 g5024__1617(.AN (n_10), .B (addr[3]), .Y (n_16));
  NOR3X1 g5015__2802(.A (addr[0]), .B (addr[1]), .C (n_5), .Y (n_99));
  NOR3X1 g5014__1705(.A (addr[0]), .B (addr[1]), .C (n_8), .Y (n_130));
  NOR3BX1 g5017__5122(.AN (n_4), .B (addr[1]), .C (addr[2]), .Y (n_67));
  NOR2XL g5027__8246(.A (n_9), .B (n_8), .Y (n_87));
  NOR2XL g5033__7098(.A (n_1), .B (n_9), .Y (n_69));
  NOR2XL g5034__6131(.A (n_5), .B (n_9), .Y (n_38));
  NOR2BX1 g5026__1881(.AN (n_4), .B (n_10), .Y (n_72));
  NOR3X1 g5013__5115(.A (n_3), .B (n_2), .C (n_1), .Y (n_56));
  DFFNSRXL \dout_reg[0]203 (.RN (1'b1), .SN (1'b1), .CKN (clk), .D
       (n_0), .Q (UNCONNECTED7), .QN (\dout[0]_454 ));
  NOR2XL g5031__7482(.A (n_2), .B (n_8), .Y (n_6));
  NAND2XL g5032__4733(.A (n_4), .B (addr[2]), .Y (n_11));
  CLKINVX1 g5039(.A (n_41), .Y (n_40));
  OR2X1 g5041__6161(.A (n_2), .B (addr[2]), .Y (n_10));
  NAND2XL g5042__9315(.A (n_2), .B (addr[0]), .Y (n_9));
  NAND2BX1 g5035__9945(.AN (addr[3]), .B (addr[2]), .Y (n_1));
  NAND2BX1 g5036__2883(.AN (addr[2]), .B (addr[3]), .Y (n_5));
  NOR2XL g5037__2346(.A (addr[0]), .B (addr[3]), .Y (n_4));
  NAND2XL g5040__1666(.A (en), .B (re), .Y (n_0));
  NAND2XL g5038__7410(.A (addr[2]), .B (addr[3]), .Y (n_8));
  NAND2XL g5043__6417(.A (we), .B (en), .Y (n_41));
  CLKINVX1 g5045(.A (addr[0]), .Y (n_3));
  CLKINVX1 g5044(.A (addr[1]), .Y (n_2));
  INVXL g5046(.A (rst), .Y (n_125));
  NOR2BX1 g2(.AN (n_94), .B (n_41), .Y (n_170));
  NOR2BX1 g5184(.AN (n_89), .B (n_41), .Y (n_171));
  NOR2BX1 g5185(.AN (n_74), .B (n_41), .Y (n_172));
  NOR2BX1 g5186(.AN (n_71), .B (n_41), .Y (n_173));
  NOR2BX1 g5187(.AN (n_72), .B (n_41), .Y (n_174));
  NOR2BX1 g5188(.AN (n_69), .B (n_41), .Y (n_175));
  NOR2BX1 g5189(.AN (n_38), .B (n_41), .Y (n_176));
  NOR2BX1 g5190(.AN (n_56), .B (n_41), .Y (n_177));
  NOR2BX1 g5191(.AN (n_6), .B (addr[0]), .Y (n_178));
endmodule

![FIFO_BINARY](https://github.com/user-attachments/assets/aa86cd9f-c3cf-4bf1-bb8f-00c6f69fc328)



2:SDC file

# ####################################################################

#  Created by Genus(TM) Synthesis Solution 21.14-s082_1 on Thu Oct 30 14:32:33 IST 2025

# ####################################################################

set sdc_version 2.0

set_units -capacitance 1000fF
set_units -time 1000ps

# Set the current design
current_design sram

create_clock -name "clk" -period 9.0 -waveform {0.0 5.0} [get_ports clk]
set_clock_transition 0.1 [get_clocks clk]
set_clock_gating_check -setup 0.0 
set_input_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports we]
set_input_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {addr[3]}]
set_input_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {addr[2]}]
set_input_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {addr[1]}]
set_input_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {addr[0]}]
set_input_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {din[7]}]
set_input_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {din[6]}]
set_input_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {din[5]}]
set_input_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {din[4]}]
set_input_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {din[3]}]
set_input_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {din[2]}]
set_input_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {din[1]}]
set_input_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {din[0]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {dout[7]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {dout[6]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {dout[5]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {dout[4]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {dout[3]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {dout[2]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {dout[1]}]
set_output_delay -clock [get_clocks clk] -add_delay -max 1.0 [get_ports {dout[0]}]
set_max_fanout 8.000 [get_ports clk]
set_driving_cell -lib_cell INVX1 -library fast -pin "Y" [get_ports clk]
set_driving_cell -lib_cell INVX1 -library fast -pin "Y" [get_ports rst]
set_driving_cell -lib_cell INVX1 -library fast -pin "Y" [get_ports en]
set_driving_cell -lib_cell INVX1 -library fast -pin "Y" [get_ports we]
set_driving_cell -lib_cell INVX1 -library fast -pin "Y" [get_ports re]
set_driving_cell -lib_cell INVX1 -library fast -pin "Y" [get_ports {addr[3]}]
set_driving_cell -lib_cell INVX1 -library fast -pin "Y" [get_ports {addr[2]}]
set_driving_cell -lib_cell INVX1 -library fast -pin "Y" [get_ports {addr[1]}]
set_driving_cell -lib_cell INVX1 -library fast -pin "Y" [get_ports {addr[0]}]
set_driving_cell -lib_cell INVX1 -library fast -pin "Y" [get_ports {din[7]}]
set_driving_cell -lib_cell INVX1 -library fast -pin "Y" [get_ports {din[6]}]
set_driving_cell -lib_cell INVX1 -library fast -pin "Y" [get_ports {din[5]}]
set_driving_cell -lib_cell INVX1 -library fast -pin "Y" [get_ports {din[4]}]
set_driving_cell -lib_cell INVX1 -library fast -pin "Y" [get_ports {din[3]}]
set_driving_cell -lib_cell INVX1 -library fast -pin "Y" [get_ports {din[2]}]
set_driving_cell -lib_cell INVX1 -library fast -pin "Y" [get_ports {din[1]}]
set_driving_cell -lib_cell INVX1 -library fast -pin "Y" [get_ports {din[0]}]
set_clock_uncertainty -setup 0.01 [get_ports clk]
set_clock_uncertainty -hold 0.01 [get_ports clk]

The SDC (Synopsys Design Constraints) file generated by the Cadence Genus tool is important because it defines the timing, electrical, and operating conditions under which your SRAM design must function correctly. It specifies the clock characteristics such as period, waveform, uncertainty, and transition, which guide the synthesis tool to optimize the logic so that all paths meet setup and hold timing requirements. The file also sets input and output delays to model how signals interact with external components, ensuring realistic timing analysis. Constraints like driving cell definitions and maximum fanout help the tool estimate signal slew and loading accurately, leading to better gate sizing and buffering decisions. Additionally, clock gating checks and unit definitions ensure proper handling of low-power techniques and consistent interpretation of timing values across the design flow. Overall, this SDC acts as a contract between the design and the tools, enabling timing-driven synthesis and ensuring that the resulting netlist can achieve timing closure during place-and-route and operate reliably in silicon.

---

### 3️ Innovus
how to invoke the tool.
upon logging server with your login id and password. 
   csh
   source /home/install/cshrc
   innovus for GUI


## Brief introduction of Innovus

Cadence Innovus is a physical design implementation tool used in the digital VLSI flow to convert a synthesized gate-level netlist into a manufacturable chip layout. It performs tasks such as floorplanning, placement, clock tree synthesis, routing, optimization, and physical verification to ensure that the design meets timing, power, and area requirements. Innovus works after synthesis (for example after Cadence Genus) and produces the final layout data that can be sent for fabrication.

## Significance of Innovus

Innovus is significant because it bridges the gap between logical design and physical silicon by implementing the design under real physical constraints such as wire delays, congestion, power distribution, and process variations. It helps achieve timing closure, minimizes power consumption, ensures signal integrity, and verifies that the chip can be reliably manufactured. Without physical design tools like Innovus, it would not be possible to convert RTL or netlist into a working integrated circuit. It is widely used in industry for ASIC and SoC implementation.

## Major stages performed in Innovus (brief)

Innovus handles floorplanning to define chip size and block locations, power planning to create power grids, placement to position standard cells, clock tree synthesis to distribute the clock with minimal skew, routing to connect all nets, and post-route optimization to fix timing and signal integrity issues. Finally, it generates signoff files like "" Graphic Data System "" (GDSII) for tapeout.

In Cadence Innovus, there are two main ways to use the tool: through scripting (using TCL commands) and through the graphical user interface (GUI). In the physical design flow, place-and-route (P&R) can be performed using the GUI, which provides a visual environment to manage and analyze the design. When starting a new project for the first time, it is necessary to set up all required input files such as the synthesized netlist, timing constraints, technology and cell libraries, and other supporting data. After launching the Innovus GUI, the user can navigate to the “File” menu and select the “Design Import” option, which opens a dialog window. In this window, all necessary files are specified and configured so that the tool can initialize the design database. we need to upload netlist file generated  Once the design is successfully imported, the user can proceed with floorplanning, placement, clock tree synthesis, routing, and subsequent physical design steps.

	this are the below location of lef file avaiable at 45nm technology.
"/home/install/FOUNDRY/digital/45nm/NangateOpenCellLibrary_v1.00_20080225/lef/FreePDK45_lib_v1.0.lef"
"/home/install/FOUNDRY/digital/45nm/NangateOpenCellLibrary_v1.00_20080225/lef/FreePDK45_lib_v1.0.lef.orig"
"/home/install/FOUNDRY/digital/45nm/NangateOpenCellLibrary_v1.00_20080225/lef/FreePDK45_lib_v1.0.MOD.lef"
"/home/install/FOUNDRY/digital/45nm/dig/lef/gsclib045_macro.lef"
"/home/install/FOUNDRY/digital/45nm/dig/lef/gsclib045_tech.lef"
"/home/install/FOUNDRY/digital/45nm/LIBS/lef/pads.lef"
"/home/install/FOUNDRY/digital/45nm/LIBS/lef/pdkIO.lef"
this is the padio file design requried for our design.
(globals 
   version=1
   io_order = clockwise
   space = 5
)

(iopad

    (left
        (inst name="clk"   cell=PDI place_status=fixed)
        (inst name="rst_n" cell=PDI place_status=fixed)
        (inst name="wr_en" cell=PDI place_status=fixed)
        (inst name="rd_en" cell=PDI place_status=fixed)
    )

    (top
        (inst name="wdata[0]" cell=PDI place_status=fixed)
        (inst name="wdata[1]" cell=PDI place_status=fixed)
        (inst name="wdata[2]" cell=PDI place_status=fixed)
        (inst name="wdata[3]" cell=PDI place_status=fixed)
        (inst name="wdata[4]" cell=PDI place_status=fixed)
        (inst name="wdata[5]" cell=PDI place_status=fixed)
        (inst name="wdata[6]" cell=PDI place_status=fixed)
        (inst name="wdata[7]" cell=PDI place_status=fixed)
    )

    (right
        (inst name="rdata[0]" cell=PDO place_status=fixed)
        (inst name="rdata[1]" cell=PDO place_status=fixed)
        (inst name="rdata[2]" cell=PDO place_status=fixed)
        (inst name="rdata[3]" cell=PDO place_status=fixed)
        (inst name="rdata[4]" cell=PDO place_status=fixed)
        (inst name="rdata[5]" cell=PDO place_status=fixed)
        (inst name="rdata[6]" cell=PDO place_status=fixed)
        (inst name="rdata[7]" cell=PDO place_status=fixed)

        (inst name="full"  cell=PDO place_status=fixed)
        (inst name="empty" cell=PDO place_status=fixed)
    )

)

###  Static Timing Analysis (MMMC)
we must setup the mmmc analysis  to setup the 
Setup and hold analysis performed across corners using Innovus timing engine.

➡ Next: Final design validation.

---


### 4️ Floorplanning and IO Planning

Die size is defined, IO pads are placed, and layout boundaries are established.

➡ Next: Build power infrastructure.

---

### 5️ Power Planning (PDN)

Power rings and vertical stripes are created to ensure robust power distribution across the chip.

➡ Next: Connect global power nets.

---

### 6️⃣ Placement

Standard cells are placed and optimized for timing and congestion.

➡ Next: Perform routing.

---

### 7️⃣ Routing

Signal routing is performed using NanoRoute, followed by optimization to reduce DRC violations.

➡ Next: Run verification checks.

---

### 8️⃣ Physical Verification

DRC checks confirm compliance with manufacturing rules.

➡ Next: Perform timing analysis.

---



## 📊 Results

* Successful placement and routing
* Clean DRC verification
* Timing analyzed under MMMC setup
* Functional ALU implemented at physical level

---
##  Key Learnings

* Understanding of real ASIC backend flow
* Importance of constraints in timing closure
* PDN design strategies
* Routing challenges and congestion handling
* Practical use of Cadence physical design tools

---

## Future Improvements

* Add Clock Tree Synthesis optimization
* Perform IR drop and EM analysis
* Implement MCMM signoff flow

---

## 👤 Author

Bhukya Tulasi Ram
M.Tech VLSI AND EMBEDDED SYSTEM Design
