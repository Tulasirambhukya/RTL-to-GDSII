`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Design : Low-power synchronous FIFO with MBFF memory and Gray pointers
// Depth  : 4
// Width  : 8
// Notes  :
//   - Word-level write enable (low power)
//   - MBFF-friendly register memory
//   - Gray-code pointers
//   - FULL and EMPTY are REGISTERED (coverage-safe)
//////////////////////////////////////////////////////////////////////////////////

module fifo_4x8_mbff_gray_en (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        wr_en,
    input  wire        rd_en,
    input  wire [7:0]  wdata,
    output reg  [7:0]  rdata,
    output wire        full,
    output wire        empty
);

    // -------------------------------------------------
    // Parameters
    // -------------------------------------------------
    localparam DEPTH = 4;
    localparam DW    = 8;
    localparam ADDR  = 2;   // log2(4)

    // -------------------------------------------------
    // MBFF-friendly register-based memory
    // -------------------------------------------------
    reg [DW-1:0] mem [0:DEPTH-1];

    // -------------------------------------------------
    // Binary and Gray pointers (ADDR+1 bits)
    // -------------------------------------------------
    reg [ADDR:0] wr_bin, wr_gray;
    reg [ADDR:0] rd_bin, rd_gray;

    // -------------------------------------------------
    // Fire conditions
    // -------------------------------------------------
    wire wr_fire = wr_en && !full;
    wire rd_fire = rd_en && !empty;

    // -------------------------------------------------
    // Next-state binary pointers
    // -------------------------------------------------
    wire [ADDR:0] wr_bin_next = wr_bin + wr_fire;
    wire [ADDR:0] rd_bin_next = rd_bin + rd_fire;

    // -------------------------------------------------
    // Gray code conversion
    // -------------------------------------------------
    wire [ADDR:0] wr_gray_next = (wr_bin_next >> 1) ^ wr_bin_next;
    wire [ADDR:0] rd_gray_next = (rd_bin_next >> 1) ^ rd_bin_next;

    // -------------------------------------------------
    // Memory addresses
    // -------------------------------------------------
    wire [ADDR-1:0] wr_addr = wr_bin[ADDR-1:0];
    wire [ADDR-1:0] rd_addr = rd_bin[ADDR-1:0];

    // -------------------------------------------------
    // Registered FULL and EMPTY
    // -------------------------------------------------
    reg full_r, empty_r;
    assign full  = full_r;
    assign empty = empty_r;

    // -------------------------------------------------
    // One-hot word enable (WRITE side)
    // -------------------------------------------------
    reg [DEPTH-1:0] wr_word_en;
    integer i;

    always @(*) begin
        wr_word_en = {DEPTH{1'b0}};
        if (wr_fire)
            wr_word_en[wr_addr] = 1'b1;
    end

    // -------------------------------------------------
    // MBFF-style memory write
    // -------------------------------------------------
    genvar gi;
    generate
        for (gi = 0; gi < DEPTH; gi = gi + 1) begin : MBFF_MEM
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n)
                    mem[gi] <= {DW{1'b0}};
                else if (wr_word_en[gi])
                    mem[gi] <= wdata;
            end
        end
    endgenerate

    // -------------------------------------------------
    // Registered read data
    // -------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rdata <= {DW{1'b0}};
        else if (rd_fire)
            rdata <= mem[rd_addr];
    end

    // -------------------------------------------------
    // Write pointer update
    // -------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_bin  <= {ADDR+1{1'b0}};
            wr_gray <= {ADDR+1{1'b0}};
        end else begin
            wr_bin  <= wr_bin_next;
            wr_gray <= wr_gray_next;
        end
    end

    // -------------------------------------------------
    // Read pointer update
    // -------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_bin  <= {ADDR+1{1'b0}};
            rd_gray <= {ADDR+1{1'b0}};
        end else begin
            rd_bin  <= rd_bin_next;
            rd_gray <= rd_gray_next;
        end
    end

    // -------------------------------------------------
    // FULL flag (registered)
    // -------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            full_r <= 1'b0;
        else
            full_r <= (wr_gray_next ==
                      {~rd_gray[ADDR:ADDR-1],
                        rd_gray[ADDR-2:0]});
    end

    // -------------------------------------------------
    // EMPTY flag (registered)
    // -------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            empty_r <= 1'b1;
        else
            empty_r <= (wr_gray_next == rd_gray_next);
    end

endmodule
