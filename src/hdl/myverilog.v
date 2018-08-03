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
   // for communication with PS (CPU) side
   input  wire [31:0] r0, r1, r2,
   output wire [31:0] r3, r4, r5, r6, r7,
   // ## I/O pins start here: ##
   output wire [7:0]  led
   );
    // Instantiate "bus" I/O
    wire [15:0] baddr, bwrdata;
    wire [15:0] brddata;
    wire 	bwr, bstrobe;
    wire [33:0] ibus = {clk, bwr, baddr, bwrdata};
    wire [15:0] obus;
    assign brddata = obus;
    bus_zynq_gpio bus_zynq_gpio
      (.clk(clk), .clk100(clk), .r0(r0), .r1(r1), .r2(r2),
       .r3(r3), .r4(r4), .r5(), .r6(r6), .r7(r7),
       .baddr(baddr), .bwr(bwr), .bstrobe(bstrobe),
       .bwrdata(bwrdata), .brddata(brddata));
    assign r5 = {brddata,baddr};
    zror #(16'h0000) r0000(ibus, obus, 16'h1129);
    zror #(16'h0001) r0001(ibus, obus, 16'hbeef);
    zror #(16'h0002) r0002(ibus, obus, 16'hdead);
    wire [15:0] q0003;
    zreg #(16'h0003) r0003(ibus, obus, q0003);
    wire [15:0] q0004;
    zreg #(16'h0004) r0004(ibus, obus, q0004);
    assign led = q0004;
endmodule  // myverilog


module bus_zynq_gpio
  (input  wire        clk,
   input  wire        clk100,
   input  wire [31:0] r0, r1, r2,
   output wire [31:0] r3, r4, r5, r6, r7,
   output wire [15:0] baddr,
   output wire        bwr,
   output wire        bstrobe,
   output wire [15:0] bwrdata, 
   input  wire [15:0] brddata
   );
    /*
     * Note for future:  See logbook entries for 2015-05-19 and 05-18.  At 
     * some point I want to make the entire "bus" synchronous to 
     * "mcu_clk100" so that the main FPGA logic all runs off of a single 
     * clock.  When I do that, it may be helpful to use a spare AXI register
     * to allow me to debug the presence of mcu_clk100.
     */

    /*
     * Register assignments:
     *   == read/write by PS (read-only by PL) ==
     *   r0: 32-bit data (reserved for future use)
     *   r1: current operation addr (16 bits) + data (16 bits)
     *   r2: strobe (from PS to PL) + opcode for current operation
     *   == read-only by PS (write-only by PL) ==
     *   r3: status register (includes strobe from PL to PS)
     *   r4: data from last operation (16 bits, may expand to 32)
     *   r5: opcode + addr from last operation
     *   r6: number of "bus" writes (16 bits) + reads (16 bits)
     *   r7: constant 0xfab40001 (could be redefined later)
     */
    // baddr, bwr, bwrdata are output ports of this module whose
    // contents come from the corresponding D-type flipflops.  The
    // "_reg" variable is the FF's "Q" output, and the "_next"
    // variable is the FF's "D" input, which I declare as a "reg" so
    // that its value can be set by a combinational always block.
    // I've added a new "bstrobe" signal to the bus, which could be
    // useful for FIFO R/W or for writing to an asynchronous RAM.
    reg [15:0] baddr_reg=0, baddr_next=0;
    reg [15:0] bwrdata_reg=0, bwrdata_next=0;
    reg        bwr_reg=0, bwr_next=0;
    reg        bstrobe_reg=0, bstrobe_next=0;
    assign baddr = baddr_reg;
    assign bwr = bwr_reg;
    assign bstrobe = bstrobe_reg;
    assign bwrdata = bwrdata_reg;
    // nwr and nrd will be DFFEs that count the number of read and
    // write operations to the bus.  Send results to PS on r6.
    reg [15:0] nwr=0, nrd=0;
    assign r6 = {nwr,nrd};
    // r7 reports to PS this identifying fixed value for now.
    assign r7 = 'hfab40001;
    // These bits of r2 are how the PS tells us to "go" to do the next
    // read or write operation.
    wire ps_rdstrobe = r2[0];  // "read strobe" from PS
    wire ps_wrstrobe = r2[1];  // "write strobe" from PS
    // Make copies of ps_{rd,wr}strobe synchronous to 'clk100'
    reg ps_rdstrobe_clk100_sync = 0;
    reg ps_rdstrobe_clk100 = 0;
    reg ps_wrstrobe_clk100_sync = 0;
    reg ps_wrstrobe_clk100 = 0;
    always @ (posedge clk100) begin
	ps_rdstrobe_clk100_sync <= ps_rdstrobe;
	ps_rdstrobe_clk100 <= ps_rdstrobe_clk100_sync;
	ps_wrstrobe_clk100_sync <= ps_wrstrobe;
	ps_wrstrobe_clk100 <= ps_wrstrobe_clk100_sync;
    end
    // Enumerate the states of the FSM that executes the bus I/O
    localparam 
      FsmStart=0, FsmIdle=1, FsmRead=2, FsmRead1=3,
      FsmWrite=4, FsmWrite1=5, FsmWait=6;
    reg [2:0] fsm=0, fsm_next=0;  // current and next FSM state
    reg       pl_ack=0, pl_ack_next=0;  // "ack" strobe from PL back to PS
    // Make a copy of pl_ack that is synchronous to 'clk'
    reg       pl_ack_clk_sync=0, pl_ack_clk=0;
    always @ (posedge clk) begin
	pl_ack_clk_sync <= pl_ack;
	pl_ack_clk <= pl_ack_clk_sync;
    end
    assign r3 = {fsm, 3'b000, pl_ack_clk};
    reg [31:0] r4_reg=0, r4_next=0;
    assign r4 = r4_reg;
    reg [31:0] r5_reg=0, r5_next=0;
    assign r5 = r5_reg;
    always @(posedge clk100) begin
	fsm <= fsm_next;
	baddr_reg <= baddr_next;
	bwrdata_reg <= bwrdata_next;
	bwr_reg <= bwr_next;
	bstrobe_reg <= bstrobe_next;
	pl_ack <= pl_ack_next;
	r4_reg <= r4_next;
	r5_reg <= r5_next;
	if (fsm==FsmRead1) nrd <= nrd + 1;
	if (fsm==FsmWrite1) nwr <= nwr + 1;
    end
    always @(*) begin
	// these default to staying in same state
	fsm_next = fsm;
	baddr_next = baddr_reg;
	bwrdata_next = bwrdata_reg;
	r4_next = r4_reg;
	r5_next = r5_reg;
	// these default to zero
	bwr_next = 0;
	bstrobe_next = 0;
	pl_ack_next = 0;
	case (fsm)
	    FsmStart: begin
		// Start state: wait for both read and write strobes
		// from PS to be deasserted, then go to Idle state to
		// wait for first bus transaction.
		if (!ps_rdstrobe_clk100 && !ps_wrstrobe_clk100)
		  fsm_next = FsmIdle;
	    end
	    FsmIdle: begin
		// Idle state: When we first arrive here, both read and
		// write strobes from PS should be deasserted.  Wait
		// for one or the other to be asserted, then initiate
		// Read or Write operation, accordingly.
		if (ps_rdstrobe_clk100) begin
		    // Before asserting its "read strobe," the PS
		    // should have already put the target bus address
		    // into r1[15:0].  These go out onto my "bus" on
		    // the next clock cycle.
		    fsm_next = FsmRead;
		    baddr_next = r1[15:0];
		end else if (ps_wrstrobe_clk100) begin
		    // Before asserting its "write strobe," the PS
		    // should have already put the target bus address
		    // into r1[15:0] and the data to be written into
		    // r1[31:16].  These go out onto my "bus" on the
		    // next clock cycle.
		    fsm_next = FsmWrite;
		    baddr_next = r1[15:0];
		    bwrdata_next = r1[31:16];
		    bwr_next = 1;
		end
	    end
	    FsmWrite: begin
		// On this clock cycle, baddr, bwrdata, and bwr are
		// already out on the bus, but no bstrobe yet.
		fsm_next = FsmWrite1;
		bstrobe_next = 1;
		bwr_next = 1;
	    end
	    FsmWrite1: begin
		// bstrobe is asserted for just this clock cycle.  bwr
		// is asserted for both this and previous cycle.  On
		// next cycle, it will be safe to tell the PS that
		// we're done.
		fsm_next = FsmWait;
		r4_next = bwrdata;
		pl_ack_next = 1;
		r5_next = {16'h0002,baddr};
	    end
	    FsmRead: begin
		// On this clock cycle, baddr is already out on the
		// bus, but no bstrobe yet.
		fsm_next = FsmRead1;
		bstrobe_next = 1;
	    end
	    FsmRead1: begin
		// bstrobe is asserted for just this clock cycle.  On
		// the next cycle, it will be safe to tell the PS that
		// we're done and that it can find our answer on r4.
		fsm_next = FsmWait;
		r4_next = brddata;
		pl_ack_next = 1;
		r5_next = {16'h0001,baddr};
	    end
	    FsmWait: begin
		// On this cycle, pl_ack is asserted, informing the PS
		// that we're done with this operation.  We sit here
		// until the PS drops its read or write strobe, thus
		// acknowledging our being done.  Once that happens,
		// we can drop our pl_ack and go to Idle to wait for
		// the next operation.
		pl_ack_next = 1;
		if (!ps_rdstrobe_clk100 && !ps_wrstrobe_clk100) begin
		    pl_ack_next = 0;
		    fsm_next = FsmIdle;
		end
	    end
	    default: begin
		// We somehow find ourselves in an illegal state: 
		// go back to the start state.
		fsm_next = FsmStart;
	    end
	endcase
    end
endmodule


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
