/*
 * myverilog.v
 * User Verilog logic for "Programmable Logic" (PL) side of Microzed
 * modified 2018-08-03 by wja, starting from rocstar_uzed.v
 */

`timescale 1ns / 1ps
`default_nettype none

module myverilog
  (
   // MicroZed internal clock provided by Zynq PS fclk0
   input  wire        clk,
   // register file 'bus' driven directly by 'wja_bus_lite' module
   input  wire [15:0] baddr, bwrdata,
   output wire [15:0] brddata,
   input  wire        bwr, bstrobe,
   input  wire        do_a7_write,
   input  wire        do_a7_read,
   // ## I/O pins start here: ##
   output wire [7:0]  led
   );
    // Instantiate "bus" I/O
    wire [33:0] ibus = {clk, bwr, baddr, bwrdata};
    wire [15:0] obus;
    assign brddata = obus;
    zror #(16'h0000) r0000(ibus, obus, 16'h0808);
    zror #(16'h0001) r0001(ibus, obus, 16'hbeef);
    zror #(16'h0002) r0002(ibus, obus, 16'hdead);
    wire [15:0] q0003;
    zreg #(16'h0003) r0003(ibus, obus, q0003);
    wire [15:0] q0004;
    zreg #(16'h0004) r0004(ibus, obus, q0004);
    assign led = q0004;
    reg [15:0] ticks = 0;
    always @ (posedge clk) ticks <= ticks + 1;
    zror #(16'h0005) r0005(ibus, obus, ticks);
    zror #(16'h0006) r0006(ibus, obus, 16'h3333);

    // simple mechanism to compile a timestamp into the firmware;
    // before recompiling, run 'python fw_timestamp.py'
`include "fw_timestamp.v"
    bror #('h0010) r0010(ibus, obus, fw_yyyy);
    bror #('h0011) r0011(ibus, obus, fw_mmdd);
    bror #('h0012) r0012(ibus, obus, fw_hhmm);

    // ======================================================================
    // mimic serialized Microzed-to-Spartan6 I/O here, so that I can use
    // this code as a platform for making a much faster protocol
    wire from_spartan6;
    wire to_spartan6;
    fake_spartan6 fs6
      (.clk(clk), .busin(to_spartan6), .busout(from_spartan6));
    wire clk100 = clk;
    reg a7_bus_wdat = 0, a7_bus_wdat1 = 0, a7_bus_rdat = 0;
    reg a7_bus_wdat1a = 0, a7_bus_wdat1b = 0;
    wire a7_bus_wdat9;
    wire a7_bus_rdat0 = from_spartan6;
    always @ (posedge clk100) a7_bus_rdat <= from_spartan6;
    // see comments for "busfsm" in busio.v
    reg [15:0] bytesseen = 0, bytessent = 0;
    reg [11:0] bytereg = 0;
    reg [39:0] wordreg = 0, lastword = 0;
    reg        execcmd = 0, newrequest = 0;
    always @ (posedge clk100) begin
        if (bytereg[11] & !bytereg[1:0]) begin
            bytesseen <= bytesseen+1;
            bytereg <= 12'b0;
            wordreg <= {wordreg[31:0], bytereg[9:2]};
            execcmd <= bytereg[10];
        end else begin
            bytereg <= {bytereg[10:0], a7_bus_rdat};
            if (execcmd) begin
                lastword <= wordreg;
                wordreg <= 40'b0;
            end else if (newrequest) begin
                lastword <= 40'b0;
            end
            execcmd <= 1'b0;
        end
    end
    // registers returning status+data from last A7 bus operation
    wire [7:0]  laststatus = lastword[7:0];
    zror #('h0080,8) r0080(ibus, obus, lastword);
    wire [15:0] lastread   = lastword[23:8];
    zror #('h0081) r0081(ibus, obus, lastread);
    zror #('h0083) r0083(ibus, obus, bytesseen);
    zror #('h0084) r0084(ibus, obus, bytessent);
    // register/FSM to shift a (9-bit) "byte" out to Artix7
    reg [64:0] a7shiftout = 0;
    always @ (posedge clk100) begin
        if (do_a7_write) begin
            a7shiftout <= {3'b010, bwrdata[15:8], 2'b00,
                           3'b010, bwrdata[7:0],  2'b00,
                           3'b010, baddr[15:8],   2'b00,
                           3'b010, baddr[7:0],    2'b00,
                           3'b011, 8'h01,         2'b00};
            bytessent <= bytessent + 5;
            newrequest <= 1;
        end else if (do_a7_read) begin
            a7shiftout <= {3'b010, baddr[15:8],   2'b00,
                           3'b010, baddr[7:0],    2'b00,
                           3'b011, 8'h02,         2'b00,
                           3'b000, 8'h00,         2'b00,
                           3'b000, 8'h00,         2'b00};
            bytessent <= bytessent + 3;
            newrequest <= 1;
        end else begin
            a7shiftout <= {a7shiftout,1'b0};
            newrequest <= 0;
        end
        a7_bus_wdat1 <= a7shiftout[64];
    end
    assign to_spartan6 = a7_bus_wdat1;
endmodule  // myverilog

module fake_spartan6
  (
   input  wire clk,
   input  wire busin,
   output wire busout
   );
    // Instantiate state machine to accept "bus" commands
    // via ad-hoc serial link from Microzed.
    wire [15:0] baddr, bwrdata, brddata;
    wire        bwr;
    wire [15:0] rdcount, wrcount, bytecount;
    busfsm busfsm (.clk(clk), .serialin(busin), .serialout(busout),
                   .wr(bwr), .addr(baddr), .wrdata(bwrdata),
                   .rddata(brddata), .rdcount(rdcount), .wrcount(wrcount),
                   .bytecount(bytecount), .debug(), .debug1());
    localparam IBUSW = 1+1+16+16;
    wire [IBUSW-1:0] ibus = {clk, bwr, baddr, bwrdata};
    wire [15:0]      obus;
    assign brddata = obus;
    bror #('h0210) r0210(ibus, obus, rdcount);
    bror #('h0211) r0211(ibus, obus, wrcount);
    bror #('h0212) r0212(ibus, obus, bytecount);
    bror #('h0000) r0000(ibus, obus, 16'h0000); // always reads zero
    bror #('h0001) r0001(ibus, obus, 16'hbeef); // always reads funny message
    bror #('h0002) r0002(ibus, obus, 16'hdead); // always reads funny message
    wire [15:0] q0003;
    breg #('h0003) r0003(ibus, obus, q0003);    // generic read/write register

    reg [15:0] ticks = 0;
    always @ (posedge clk) ticks <= ticks + 1;
    bror #('h0005) r0005(ibus, obus, ticks);
    bror #('h0006) r0006(ibus, obus, 16'h6666);
endmodule  // fake_spartan6

// a read/write register to live on the "bus"
module zreg #( parameter MYADDR=0, W=16, PU=0 )
    (
     input  wire [1+1+16+16-1:0] i,
     output wire [15:0]          o,
     output wire [W-1:0]         q
     );
    wire        clk, wr;
    wire [15:0] addr, wrdata;
    wire [15:0] rddata;
    assign {clk, wr, addr, wrdata} = i;
    assign o = {rddata};
    // boilerplate ends here
    reg [W-1:0] regdat = PU;
    wire addrok = (addr==MYADDR);
    assign rddata = addrok ? regdat : 16'hzzzz;
    always @ (posedge clk)
      if (wr && addrok)
	regdat <= wrdata[W-1:0];
    assign q = regdat;
endmodule // zreg

// a read-only register to live on the "bus"
module zror #( parameter MYADDR=0, W=16 )
    (
     input  wire [1+1+16+16-1:0] i,
     output wire [15:0]          o,
     input  wire [W-1:0]         d
     );
    wire 	clk, wr;
    wire [15:0] addr, wrdata;
    wire [15:0] rddata;
    assign {clk, wr, addr, wrdata} = i;
    assign o = {rddata};
    // boilerplate ends here
    wire addrok = (addr==MYADDR);
    assign rddata = addrok ? d : 16'hzzzz;
endmodule // zror

`default_nettype wire

