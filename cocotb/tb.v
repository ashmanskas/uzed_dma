
`timescale 1ns / 1ps
`default_nettype none

module tb;
    // Set up 100 MHz clock: this is the 'fclk' provided by the PS
    reg clk = 0;
    initial begin
        while (1) begin
            clk = 0;
            #5;
            clk = 1;
            #5;
        end
    end
    // This clock, also nominally 100 MHz, is used internally by the PL
    reg plclk = 0;
    initial begin
        while (1) begin
            plclk = 0;
            #6;
            plclk = 1;
            #5;
        end
    end
    // Lets me see from SimVision GUI where a teste begins and ends
    integer cocotb_testnum = 0;
    // Data storage by cocotb test bench
    reg  [31:0] last_rdata = 0;
    // wja_bus_lite inputs/outputs (other than clock)
    reg         aresetn = 0;
    reg   [7:0] awaddr  = 0;
    reg   [2:0] awprot  = 0;
    reg         awvalid = 0;
    wire        awready;
    reg  [31:0] wdata   = 0;
    reg   [3:0] wstrb   = 4'hf;
    reg         wvalid  = 0;
    wire        wready;
    wire  [1:0] bresp;
    wire        bvalid;
    reg         bready  = 0;
    reg   [7:0] araddr  = 0;
    reg   [2:0] arprot  = 0;
    reg         arvalid = 0;
    wire        arready;
    wire [31:0] rdata;
    wire  [1:0] rresp;
    wire        rvalid;
    reg         rready  = 0;
    wire [15:0] baddr, bwrdata, brddata;
    wire        bwr, bstrobe;
    wire        do_a7_write;
    wire        do_a7_read;
    // Instantiate wja_bus_lite
    wja_bus_lite bl
      (.plclk(plclk), .baddr(baddr), .bwrdata(bwrdata), 
       .brddata(brddata), .bwr(bwr), .bstrobe(bstrobe),
       .do_a7_write(do_a7_write), .do_a7_read(do_a7_read),
       .s00_axi_aclk(clk), .s00_axi_aresetn(aresetn),
       .s00_axi_awaddr(awaddr), .s00_axi_awvalid(awvalid),
       .s00_axi_awready(awready), .s00_axi_wdata(wdata),
       .s00_axi_wstrb(wstrb), .s00_axi_wvalid(wvalid),
       .s00_axi_wready(wready), .s00_axi_bresp(bresp),
       .s00_axi_bvalid(bvalid), .s00_axi_bready(bready),
       .s00_axi_araddr(araddr), .s00_axi_arprot(arprot),
       .s00_axi_arvalid(arvalid), .s00_axi_arready(arready),
       .s00_axi_rdata(rdata), .s00_axi_rresp(rresp),
       .s00_axi_rvalid(rvalid), .s00_axi_rready(rready));
    // Additional inputs/outputs needed for myverilog
    wire [7:0] led;
    // Instantiate myverilog
    myverilog mv
      (.clk(plclk), 
       .baddr(baddr), .bwrdata(bwrdata), .brddata(brddata),
       .bwr(bwr), .bstrobe(bstrobe), 
       .do_a7_write(do_a7_write), .do_a7_read(do_a7_read),
       .led(led));
endmodule

`default_nettype wire
