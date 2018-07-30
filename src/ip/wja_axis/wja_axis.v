
// Language: Verilog 2001

`timescale 1ns / 1ps
`default_nettype none

module wja_axis
  (
   // AXI master interface (output of the FIFO)
   input  wire        m00_axis_aclk,
   input  wire        m00_axis_aresetn,
   output wire [31:0] m00_axis_tdata,
   // output wire  [3:0] m00_axis_tstrb,
   output wire        m00_axis_tvalid,
   input  wire        m00_axis_tready,
   output wire        m00_axis_tlast
   );
    wire clk = m00_axis_aclk;  // use a single clock for all logic
    reg [2:0] rst_sync = 3'b111;  // synchronize reset signal
    reg mrvalid = 0;  // is 'mrdat' valid?
    reg m00_tvalid = 0;  // FF to drive m00_axis_tvalid
    wire empty = 0; // (rptr==wptr);
    // control signals
    wire store_output = m00_axis_tready || !m00_axis_tvalid;
    // reset synchronization
    always @(posedge clk) begin
        if (!m00_axis_aresetn) begin
            rst_sync <= 3'b111;
        end else begin
            rst_sync <= {rst_sync,1'b0};
        end
    end
    wire rst = rst_sync[2];
    // Read logic
    wire read = (store_output || !mrvalid) && !empty;
    reg [7:0] foobar = 0;  // dummy counter to provide data contents
    always @(posedge clk) begin
        if (rst) begin
            mrvalid <= 0;
        end else if (store_output || !mrvalid) begin
            mrvalid <= !empty;
        end
        if (read) begin
            foobar <= foobar + 1;
        end
    end
    always @(posedge clk) begin
        if (rst) begin
            m00_tvalid <= 0;
        end else if (store_output) begin
            m00_tvalid <= mrvalid;
        end
    end
    // AXI bus output
    assign m00_axis_tvalid = m00_tvalid;
    assign m00_axis_tlast = !(~foobar[3:0]);
    assign m00_axis_tdata = {4{foobar}};
endmodule

`default_nettype wire

// started from axis_fifo.v by Alex Forencich
