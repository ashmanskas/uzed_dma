/*
 * busio.v
 * Simple 16A/16D bus for run-time register configuration
 * begun 2009-08-20 by wja
 */

// `include "bpet_defs.v"

`default_nettype none

module busfsm
  (
   input  wire clk,
   input  wire serialin,
   output wire serialout,
   output wire wr,
   output wire [15:0] addr,
   output wire [15:0] wrdata,
   input  wire [15:0] rddata,
   output wire [15:0] rdcount,
   output wire [15:0] wrcount,
   output wire [15:0] bytecount,
   output wire [11:0] debug,
   output wire [19:0] debug1
   );
   /*
    * Incoming bit stream is broken into 9-bit bytes, each of which is 
    * preceded by one start bit (1) and two stop bits (0).  Bit 8 (MSb)
    * of each byte is 1 if the byte contains a command, else 0 for a
    * data byte.  A message consists of zero or more data (non-command) 
    * bytes, MSB first, followed by a command byte.  The number of data 
    * bytes will vary by command.  The receiving FSM simply shifts each
    * new byte into the LSB of a shift register, until a command byte
    * is seen, at which point the message (whose command is LSB) is
    * executed.  Commands will be WRITE, READ, etc.
    */
   reg [11:0] bytereg = 0;
   reg [39:0] wordreg = 0;
   reg        execcmd = 0;
   reg        dbgtoggle = 0;
   reg [15:0] rdcount1 = 0, wrcount1 = 0, bytecount1 = 0;
   assign debug = bytereg;
   assign debug1 = wordreg;
   assign rdcount = rdcount1;
   assign wrcount = wrcount1;
   assign bytecount = bytecount1;
   always @ (posedge clk) begin
      dbgtoggle <= ~dbgtoggle;
      if (bytereg[11] & !bytereg[1:0]) begin
         bytereg <= 12'b0;
         wordreg <= {wordreg[31:0], bytereg[9:2]};
         execcmd <= bytereg[10];
         bytecount1 <= bytecount1 + 1;
         //$strobe("%1d byte %2x", $time, bytereg[10:2]);
      end else begin
         bytereg <= {bytereg[10:0], serialin};
         if (execcmd) wordreg <= 40'b0;
         execcmd <= 1'b0;
      end
      //if (execcmd) $strobe("%1d execcmd %10x", $time, wordreg);
   end
   localparam 
     IDLE=0, DECODE=1, WRITE=2, READ=3, READA=4, READB=5, READC=6,
     REPLY=7, DONE=8;
   reg [3:0]  fsm = 0, fsmnext = 0;
   reg [31:0] data = 0;
   reg [7:0]  cmd = 0;
   reg [5:0]  replybits = 0;
   reg [38:0] replyshift = 0;
   reg [15:0] ffaddr=0, ffwrdata=0, ffrddata=0;
   reg        ffwr=0, ffserialout=0;
   // avoid registered outputs, to avoid initial 'X' in RTL simulation
   assign addr = ffaddr;
   assign wrdata = ffwrdata;
   assign wr = ffwr;
   assign serialout = ffserialout;
   always @ (posedge clk) begin
      fsm <= fsmnext;
      if (execcmd) 
        {data, cmd} <= wordreg;
      else if (fsm==DONE)
        {data, cmd} <= 40'b0;
      ffwr <= (fsm==WRITE);
      ffwrdata <= data[31:16];
      ffaddr <= data[15:0];
      if (fsm==REPLY) begin
         replybits <= replybits-1;
         replyshift <= {replyshift, 1'b0};
      end else if (fsm==WRITE) begin
         replybits <= 1*13-1;
         replyshift <= {3'b011, 8'h01, 2'b00, 24'b0};
         wrcount1 <= wrcount1 + 1;
      end else if (fsm==READB) begin
          ffrddata <= rddata;
      end else if (fsm==READC) begin
         replybits <= 3*13-1;
         replyshift <= {3'b010, ffrddata[15:8], 2'b00,
                        3'b010, ffrddata[7:0],  2'b00,
                        3'b011, 8'h02,          2'b00};
         $display("busfsm/READB: %1d rddata=%x", $time, rddata);
         rdcount1 <= rdcount1 + 1;
      end else begin
         replybits <= 0;
         replyshift <= 0;
      end
      ffserialout <= (fsm==REPLY ? replyshift[38] : 1'b0);
   end
   always @* begin
      fsmnext = IDLE;
      case (fsm)
          IDLE   : fsmnext = (execcmd ? DECODE : IDLE);
          DECODE : 
            begin
                fsmnext = DONE;
                if (cmd==8'h01) fsmnext = WRITE;
                if (cmd==8'h02) fsmnext = READ;
            end
          WRITE  : fsmnext = REPLY;
          READ   : fsmnext = READA;
          READA  : fsmnext = READB;
          READB  : fsmnext = READC;
          READC  : fsmnext = REPLY;
          REPLY  : fsmnext = (replybits ? REPLY : DONE);
          DONE   : fsmnext = IDLE;
      endcase // case (bytefsm)
   end  // always @ *
endmodule  // busfsm
   
module breg #( parameter MYADDR=0, W=16, PU=0 )
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
   assign rddata = addrok ? regdat : 16'bz;
   always @ (posedge clk)
     if (wr && addrok)
       regdat <= wrdata[W-1:0];
   assign q = regdat;
endmodule  // breg

module bror #( parameter MYADDR=0, W=16 )
   (
    input  wire [1+1+16+16-1:0] i,
    output wire [15:0]          o,
    input  wire [W-1:0]         d
    );
    wire        clk, wr;
    wire [15:0] addr, wrdata;
    wire [15:0] rddata;
    assign {clk, wr, addr, wrdata} = i;
    assign o = {rddata};
    // boilerplate ends here
    wire        addrok = (addr==MYADDR);
    assign rddata = addrok ? d : 16'bz;
endmodule  // bror

`default_nettype wire
