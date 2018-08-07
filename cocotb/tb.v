
`timescale 1ns / 1ps
`default_nettype none

module tb;
    // Set up 100 MHz clock
    reg clk = 0;
    initial begin
        while (1) begin
            clk = 0;
            #5;
            clk = 1;
            #5;
        end
    end
    // I don't remember what I use this for
    integer cocotb_testnum = 0;
    // Data storage by cocotb test bench
    reg  [31:0] last_rdata = 0;
    // wja_bus_lite inputs/outputs (other than clock)
    wire [31:0] reg0, reg1, reg2, reg3, reg4, reg5, reg6, reg7;
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
    // Instantiate wja_bus_lite
    wja_bus_lite bl
      (.oreg0(reg0), .oreg1(reg1), .oreg2(reg2), .ireg3(reg3),
       .ireg4(reg4), .ireg5(reg5), .ireg6(reg6), .ireg7(reg7),
       .baddr(baddr), .bwrdata(bwrdata), .brddata(brddata),
       .bwr(bwr), .bstrobe(bstrobe),
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
      (.clk(clk), 
       .r0(reg0), .r1(reg1), .r2(reg2), .r3(reg3), .r4(reg4),
       .r5(reg5), .r6(reg6), .r7(reg7),
       .bbaddr(baddr), .bbwrdata(bwrdata), .bbrddata(brddata),
       .bbwr(bwr), .bbstrobe(bstrobe),
       .led(led));
endmodule

`default_nettype wire
