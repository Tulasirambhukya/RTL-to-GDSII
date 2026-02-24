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

## 🔄 Design Flow

### 1️⃣ RTL Development and Verification

RTL is written in Verilog and verified in Vivado simulator using a task-based testbench to ensure functional correctness under different operating scenarios. The RTL source file and testbench are added to a Vivado project, simulation sources are compiled, and behavioral simulation is run to validate the design functionality.
The design implements a 16×8 synchronous FIFO using a register-based memory array and binary read/write pointers. The RTL is written in Verilog and simulated in Vivado to verify correct data transfer, pointer updates, and status flag behavior under various read and write conditions.

The FIFO uses binary pointers with an extra MSB to detect wrap-around and generate accurate FULL and EMPTY flags. Write operations occur when wr_en is asserted and the FIFO is not full, while read operations occur when rd_en is asserted and the FIFO is not empty. The memory array stores data words, and the read data is registered to ensure stable output timing.

The FULL condition is detected when the next write pointer equals the read pointer with the MSB inverted, indicating the buffer is full. The EMPTY condition occurs when write and read pointers are equal, indicating no data is available.

After functional verification in Vivado using a task-based testbench, switching activity is captured through SAIF generation to enable realistic power analysis in downstream synthesis tools.
`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// 16x8 Synchronous FIFO (Binary Pointer)
// - Register-based memory
// - Correct FULL/EMPTY detection
// - Stable read data
//////////////////////////////////////////////////////////////////////////////////

module fifo_16x8_binary_en (
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

A task-based Verilog testbench is developed in Vivado to verify the functionality of the 16×8 synchronous FIFO under different operating conditions. The testbench instantiates the FIFO DUT and generates a periodic clock along with an active-low reset sequence to initialize the design.

Reusable tasks such as fifo_write, fifo_read, fill_fifo, drain_fifo, and fifo_rw are created to simplify stimulus generation and improve readability. These tasks allow systematic verification of scenarios including partial writes and reads, full condition detection, empty condition detection, overflow attempts, underflow attempts, pointer wrap-around behavior, and simultaneous read/write operations.

During simulation, signal activity is monitored using $monitor to observe data flow and status flags in real time. After functional verification, the same simulation is used to generate a SAIF file capturing switching activity across the DUT hierarchy, which is later used for accurate power estimation during synthesis.
the test bench is as follows.
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 24.02.2026 11:59:49
// Design Name: 
// Module Name: tb_fifo_16x8_binary
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


module tb_fifo_16x8_binary;

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
  fifo_16x8_binary_en dut (
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

➡️ After successful verification, a Switching Activity Interchange Format (SAIF) file is generated to capture signal toggling information required for accurate power analysis.

In the Vivado TCL console, the following commands are used:

open_saif rtl_fifo.saif — Creates a new SAIF file to store switching activity.

log_saif [get_objects /tb_fifo/dut/*] — Records switching activity of all signals inside the DUT hierarchy.

run all — Runs the simulation to capture signal transitions.

close_saif — Finalizes and saves the SAIF file.

The wildcard * ensures that all internal signals of the DUT are monitored. The generated SAIF file is later used in synthesis or power analysis tools to estimate dynamic power based on real switching activity.the path to get the saif is is as mention below.

C:\Users\user_name\fifo_16x8\fifo_16x8.sim\sim_1\behav\xsim
 below is the saif file that we use for the SAIF based power analysis.
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

---

### 2️⃣ Genus Synthesis

Cadene Genus is used to map RTL to standard cells with timing constraints applied via SDC. SAIF based synthesis is done to generate the PPA reports.Cadence Genus is an advanced logic synthesis tool used to convert RTL designs into optimized gate-level implementations while meeting timing, area, power, and testability requirements. It supports modern low-power methodologies such as power gating, multi-supply voltage domains, and clock gating, enabling designers to build energy-efficient ASICs and SoCs. Genus integrates Design for Test (DFT) capabilities to insert scan chains and improve test coverage, ensuring manufacturability and reliability. It also supports constraint-driven optimization, multi-corner multi-mode (MCMM) analysis, and switching activity-based power estimation using SAIF or VCD files. Overall, Genus plays a critical role in achieving low-power, high-performance, and testable digital designs before physical implementation tools like Innovus.
# ==============================================================
# Cadence Genus Common UI Setup File for FIFO.v
# ==============================================================

# ---- 1. Design & Directory Setup ----
set DESIGN_NAME "FIFO_45NM"
set DESIGN_DIR "/home/Mtech2413/verilog/multibit_fifo/"
set RTL_DIR     "$DESIGN_DIR"
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
here we can do cpf,dft,multi_supply voltage and level shifter cell can be added based on over design synthis

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
➡ Next: Validate netlist and prepare for physical design.

---

### 3️⃣ Innovus


### 4️⃣ Floorplanning and IO Planning

Die size is defined, IO pads are placed, and layout boundaries are established.

➡ Next: Build power infrastructure.

---

### 5️⃣ Power Planning (PDN)

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

### 9️⃣ Static Timing Analysis (MMMC)

Setup and hold analysis performed across corners using Innovus timing engine.

➡ Next: Final design validation.

---

## ⚡ Power Delivery Network

PDN consists of:

* Power rings
* Vertical stripes
* Standard cell rails

Ensures stable voltage and minimizes IR drop.

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
* Explore low-power techniques

---

## 👤 Author

Bhukya Tulasi Ram
M.Tech VLSI Design
