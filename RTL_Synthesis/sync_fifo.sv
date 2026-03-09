`timescale 1ns/1ps

module sync_fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 16
)(
    input  logic clk,
    input  logic rst,

    input  logic wr_en,
    input  logic rd_en,
    input  logic [DATA_WIDTH-1:0] wdata,

    output logic [DATA_WIDTH-1:0] rdata,
    output logic full,
    output logic empty
);

    localparam ADDR_WIDTH = $clog2(DEPTH);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    logic [ADDR_WIDTH:0] wr_ptr;
    logic [ADDR_WIDTH:0] rd_ptr;

    // -------------------------------------------------
    // WRITE LOGIC
    // -------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            wr_ptr <= 0;
        else if (wr_en && !full) begin
            mem[wr_ptr[ADDR_WIDTH-1:0]] <= wdata;
            wr_ptr <= wr_ptr + 1;
        end
    end

    // -------------------------------------------------
    // READ LOGIC
    // -------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            rd_ptr <= 0;
            rdata  <= 0;
        end
        else if (rd_en && !empty) begin
            rdata <= mem[rd_ptr[ADDR_WIDTH-1:0]];
            rd_ptr <= rd_ptr + 1;
        end
    end

    // -------------------------------------------------
    // STATUS FLAGS
    // -------------------------------------------------
    assign empty = (wr_ptr == rd_ptr);

    assign full  = (wr_ptr[ADDR_WIDTH]     != rd_ptr[ADDR_WIDTH]) &&
                   (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]);

    // =================================================
    //                  ASSERTIONS
    // =================================================

    // -------------------------------------------------
    // 1️⃣ No read when FIFO is empty
    // -------------------------------------------------
   property no_read_pointer_change_when_empty;
  @(posedge clk)
  disable iff (rst)
  ($past(empty) && $past(rd_en)) |-> $stable(rd_ptr);
endproperty

assert property(no_read_pointer_change_when_empty);

    // -------------------------------------------------
    // 2️⃣ No write when FIFO is full
    // -------------------------------------------------
    property no_write_pointer_change_when_full;
  @(posedge clk)
  disable iff (rst)
  (full && wr_en) |-> $stable(wr_ptr);
endproperty

assert property(no_write_pointer_change_when_full);

    // -------------------------------------------------
    // 3️⃣ Empty flag correctness
    // -------------------------------------------------
 property empty_flag_exact;
  @(posedge clk)
  disable iff (rst)
  empty == (wr_ptr == rd_ptr);
endproperty

    assert property(empty_flag_exact)
        else $error("ASSERTION FAILED: EMPTY flag incorrect");

    // -------------------------------------------------
    // 4️⃣ Full flag correctness
    // -------------------------------------------------
   property full_flag_exact;
  @(posedge clk)
  disable iff (rst)
  full ==
    ((wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]) &&
     (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]));
endproperty

    assert property(full_flag_exact)
        else $error("ASSERTION FAILED: FULL flag incorrect");

    // -------------------------------------------------
    // 5️⃣ Pointer should never be X
    // -------------------------------------------------
  	property wr_ptr_no_x;
  		@(posedge clk)
  		disable iff (rst)
  		!$isunknown(wr_ptr);
    endproperty

assert property (wr_ptr_no_x)
  else $error("ASSERTION FAILED: wr_ptr has X value");


property rd_ptr_no_x;
  @(posedge clk)
  disable iff (rst)
  !$isunknown(rd_ptr);
endproperty

assert property (rd_ptr_no_x)
  else $error("ASSERTION FAILED: rd_ptr has X value");

endmodule