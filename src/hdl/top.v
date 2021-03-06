`timescale 1ns / 1ps
`default_nettype none

module top
  ( inout  wire [14:0] DDR_addr,
    inout  wire [2:0]  DDR_ba,
    inout  wire        DDR_cas_n,
    inout  wire        DDR_ck_n,
    inout  wire        DDR_ck_p,
    inout  wire        DDR_cke,
    inout  wire        DDR_cs_n,
    inout  wire [3:0]  DDR_dm,
    inout  wire [31:0] DDR_dq,
    inout  wire [3:0]  DDR_dqs_n,
    inout  wire [3:0]  DDR_dqs_p,
    inout  wire        DDR_odt,
    inout  wire        DDR_ras_n,
    inout  wire        DDR_reset_n,
    inout  wire        DDR_we_n,
    inout  wire        FIXED_IO_ddr_vrn,
    inout  wire        FIXED_IO_ddr_vrp,
    inout  wire [53:0] FIXED_IO_mio,
    inout  wire        FIXED_IO_ps_clk,
    inout  wire        FIXED_IO_ps_porb,
    inout  wire        FIXED_IO_ps_srstb,
    output wire        pl_clk_en,
    input  wire        pl_clk,
    output wire [7:0]  led
    );
    wire clk0;
    wire [15:0] baddr, bwrdata, brddata;
    wire bwr, bstrobe;
    wire do_a7_write, do_a7_read;
    wire plclk = pl_clk;
    bd_wrapper bd_wrapper_inst
      (.DDR_addr(DDR_addr), .DDR_ba(DDR_ba), .DDR_cas_n(DDR_cas_n),
       .DDR_ck_n(DDR_ck_n), .DDR_ck_p(DDR_ck_p), .DDR_cke(DDR_cke),
       .DDR_cs_n(DDR_cs_n), .DDR_dm(DDR_dm), .DDR_dq(DDR_dq),
       .DDR_dqs_n(DDR_dqs_n), .DDR_dqs_p(DDR_dqs_p), .DDR_odt(DDR_odt),
       .DDR_ras_n(DDR_ras_n), .DDR_reset_n(DDR_reset_n), .DDR_we_n(DDR_we_n),
       .FIXED_IO_ddr_vrn(FIXED_IO_ddr_vrn),
       .FIXED_IO_ddr_vrp(FIXED_IO_ddr_vrp),
       .FIXED_IO_mio(FIXED_IO_mio), .FIXED_IO_ps_clk(FIXED_IO_ps_clk),
       .FIXED_IO_ps_porb(FIXED_IO_ps_porb),
       .FIXED_IO_ps_srstb(FIXED_IO_ps_srstb),
       .oclk(clk0), .plclk(plclk),
       .baddr(baddr), .bwrdata(bwrdata), .brddata(brddata),
       .bwr(bwr), .bstrobe(bstrobe),
       .do_a7_write(do_a7_write), .do_a7_read(do_a7_read));
    myverilog mv
      (.clk(plclk), 
       .baddr(baddr), .bwrdata(bwrdata), .brddata(brddata),
       .bwr(bwr), .bstrobe(bstrobe),
       .do_a7_write(do_a7_write), .do_a7_read(do_a7_read),
       .led(led));
    assign pl_clk_en = 1;
endmodule

`default_nettype wire
