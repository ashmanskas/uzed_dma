
`timescale 1 ns / 1 ps
`default_nettype none

module wja_bus_lite
    (
     output wire        oclk,
     output wire [15:0] baddr,
     output wire [15:0] bwrdata,
     input  wire [15:0] brddata,
     output wire        bwr,
     output wire        bstrobe,
     output wire [31:0] oreg0,
     output wire [31:0] oreg1,
     output wire [31:0] oreg2,
     input  wire [31:0] ireg3,
     input  wire [31:0] ireg4,
     input  wire [31:0] ireg5,
     input  wire [31:0] ireg6,
     input  wire [31:0] ireg7,
     // Ports of Axi Slave Bus Interface S00_AXI
     // global clock signal
     input  wire        s00_axi_aclk,
     // active-low global reset signal
     input  wire        s00_axi_aresetn,
     // write address: issued by master, acceped by slave
     input  wire  [7:0] s00_axi_awaddr,  // ADDR_WIDTH
     // write channel protection type: indicates the privilege and
     // security level of the transaction, and whether the transaction
     // is a data access or an instruction access
     input  wire  [2:0] s00_axi_awprot,
     // write address valid: master signals valid write address and
     // control information
     input  wire        s00_axi_awvalid,
     // write address ready: slave is ready to accept an address and
     // associated control signals
     output wire        s00_axi_awready,
     // write data: issued by master, acceped by slave
     input  wire [31:0] s00_axi_wdata,
    // write strobes: indicates which byte lanes hold valid data (one
    // bit per byte of wdata bus)
     input  wire  [3:0] s00_axi_wstrb,
     // write valid: indicates valid write data and strobes
     input  wire        s00_axi_wvalid,
     // write ready: indicates that slave can accept the write data
     output wire        s00_axi_wready,
     // write response: indicates the status of the write transaction
     output wire  [1:0] s00_axi_bresp,
     // write response valid: indicates that the channel is signaling
     // a valid write response
     output wire        s00_axi_bvalid,
     // response ready: master can accept a write response
     input  wire        s00_axi_bready,
     // read address: issued by master, acceped by slave
     input  wire  [7:0] s00_axi_araddr,  // ADDR_WIDTH
     // protection type: indicates the privilege and security level of
     // the transaction, and whether the transaction is a data access
     // or an instruction access
     input  wire  [2:0] s00_axi_arprot,
     // read address valid: channel is signaling valid read address
     // and control information
     input  wire        s00_axi_arvalid,
     // read address ready: slave is ready to accept an address and
     // associated control signals
     output wire        s00_axi_arready,
     // read data: issued by slave
     output wire [31:0] s00_axi_rdata,
     // read response: status of the read transfer.
     output wire  [1:0] s00_axi_rresp,
     // read valid: channel is signaling the required read data
     output wire        s00_axi_rvalid,
     // read ready: master can accept the read data and response
     // information
     input  wire        s00_axi_rready
     );
    wire clk = s00_axi_aclk;
    assign oclk = clk;
    // AXI4LITE signals
    reg  [7:0] axi_awaddr;  // ADDR_WIDTH
    reg        axi_awready;
    reg        axi_wready;
    reg  [1:0] axi_bresp;
    reg        axi_bvalid;
    reg  [7:0] axi_araddr;  // ADDR_WIDTH
    reg        axi_arready;
    reg [31:0] axi_rdata;
    reg  [1:0] axi_rresp;
    reg        axi_rvalid;
    // Example-specific design signals
    reg [31:0] slv_reg [0:63];
    wire       slv_reg_wren;
    reg [31:0] reg_data_out;
    // I/O Connections assignments
    assign s00_axi_awready = axi_awready;
    assign s00_axi_wready  = axi_wready;
    assign s00_axi_bresp   = axi_bresp;
    assign s00_axi_bvalid  = axi_bvalid;
    assign s00_axi_arready = axi_arready;
    assign s00_axi_rdata   = axi_rdata;
    assign s00_axi_rresp   = axi_rresp;
    assign s00_axi_rvalid  = axi_rvalid;
    integer    b = 0;  // byte_index
    // for register-file 'bus'
    reg [15:0] last_rdaddr=0, last_rddata=0;
    // assert awready for one clk cycle when both awvalid and wvalid
    // are asserted
    always @(posedge clk) begin
        if (!s00_axi_aresetn) begin
            axi_awready <= 0;
        end else begin
            if (!axi_awready && s00_axi_awvalid && s00_axi_wvalid) begin
                // slave is ready to accept write address when there
                // is a valid write address and write data on the
                // write address and data bus. This design expects no
                // outstanding transactions.
                axi_awready <= 1;
            end else begin
                axi_awready <= 0;
            end
        end
    end
    // Implement axi_awaddr latching This process is used to latch the
    // address when both s00_axi_awvalid and s00_axi_wvalid are valid.
    always @(posedge clk) begin
        if (!s00_axi_aresetn) begin
            axi_awaddr <= 0;
        end else begin
            if (~axi_awready && s00_axi_awvalid && s00_axi_wvalid) begin
                // Write Address latching
                axi_awaddr <= s00_axi_awaddr;
            end
        end
    end
    // assert wready for one clk cycle when both awvalid and wvalid
    // are asserted
    always @(posedge clk) begin
        if (!s00_axi_aresetn) begin
            axi_wready <= 0;
        end else begin
            if (!axi_wready && s00_axi_wvalid && s00_axi_awvalid) begin
                // slave is ready to accept write data when there is a
                // valid write address and write data on the write
                // address and data bus. This design expects no
                // outstanding transactions.
                axi_wready <= 1;
            end else begin
                axi_wready <= 0;
            end
        end
    end
    // Implement memory mapped register select and write logic
    // generation The write data is accepted and written to memory
    // mapped registers when axi_awready, s00_axi_wvalid, axi_wready
    // and s00_axi_wvalid are asserted. Write strobes are used to
    // select byte enables of slave registers while writing.  These
    // registers are cleared when reset (active low) is applied.
    // Slave register write enable is asserted when valid address and
    // data are available and the slave is ready to accept the write
    // address and write data.
    assign slv_reg_wren =
      axi_wready && s00_axi_wvalid && axi_awready && s00_axi_awvalid;
    always @(posedge clk) begin
        if (!s00_axi_aresetn) begin
            for (b=0; b<64; b=b+1) slv_reg[b] <= 0;
        end else begin
            if (slv_reg_wren) begin
                // For each slave register, assert respective byte
                // enables as per write strobes
                slv_reg[axi_awaddr[7:2]] <= s00_axi_wdata;
            end
        end
    end
    // Implement write response logic generation The write response
    // and response valid signals are asserted by the slave when
    // axi_wready, s00_axi_wvalid, axi_wready and s00_axi_wvalid are
    // asserted.  This marks the acceptance of address and indicates
    // the status of write transaction.
    always @(posedge clk) begin
        if (!s00_axi_aresetn) begin
            axi_bvalid  <= 0;
            axi_bresp   <= 0;
        end else begin
            if (axi_awready && s00_axi_awvalid &&
                !axi_bvalid && axi_wready && s00_axi_wvalid) begin
                // indicates a valid write response is available
                axi_bvalid <= 1;
                axi_bresp  <= 0; // 'OKAY' response
                // work error responses in future
            end else begin
                if (s00_axi_bready && axi_bvalid) begin
                    // check if bready is asserted while bvalid is
                    // high (there is a possibility that bready is
                    // always asserted high)
                    axi_bvalid <= 0;
                end
            end
        end
    end
    // Implement axi_arready generation axi_arready is asserted for
    // one s00_axi_aclk clock cycle when s00_axi_arvalid is
    // asserted. axi_awready is de-asserted when reset (active low) is
    // asserted.  The read address is also latched when
    // s00_axi_arvalid is asserted. axi_araddr is reset to zero on
    // reset assertion.
    always @(posedge clk) begin
        if (!s00_axi_aresetn) begin
            axi_arready <= 0;
            axi_araddr  <= 0;
        end else begin
            if (~axi_arready && s00_axi_arvalid) begin
                // slave has acceped the valid read address
                axi_arready <= 1;
                // read address latching
                axi_araddr  <= s00_axi_araddr;
            end else begin
                axi_arready <= 0;
            end
        end
    end
    // Implement axi_arvalid generation axi_rvalid is asserted for one
    // s00_axi_aclk clock cycle when both s00_axi_arvalid and
    // axi_arready are asserted. The slave registers data are
    // available on the axi_rdata bus at this instance. The assertion
    // of axi_rvalid marks the validity of read data on the bus and
    // axi_rresp indicates the status of read transaction.axi_rvalid
    // is deasserted on reset (active low). axi_rresp and axi_rdata
    // are cleared to zero on reset (active low).
    always @(posedge clk) begin
        if (!s00_axi_aresetn) begin
            axi_rvalid <= 0;
            axi_rresp  <= 0;
        end else begin
            if (axi_arready && s00_axi_arvalid && ~axi_rvalid) begin
                // Valid read data is available at the read data bus
                axi_rvalid <= 1;
                axi_rresp  <= 0; // 'OKAY' response
            end else if (axi_rvalid && s00_axi_rready) begin
                // Read data is accepted by the master
                axi_rvalid <= 0;
            end
        end
    end
    reg [31:0] ticks = 0;
    always @ (posedge clk) begin
        ticks <= ticks + 1;
    end
    always @(*) begin
        case (axi_araddr[7:2])  // address decode for reading registers
            'h03    : reg_data_out <= ireg3;
            'h04    : reg_data_out <= ireg4;
            'h05    : reg_data_out <= ireg5;
            'h06    : reg_data_out <= ireg6;
            'h07    : reg_data_out <= ireg7;
            'h08    : reg_data_out <= 0;  // buswr{addr,data}
            'h09    : reg_data_out <= {last_rdaddr,last_rddata};
                                          // busrd{addr,data}
            'h13    : reg_data_out <= 32'hdeadbeef;
            'h14    : reg_data_out <= 32'h12345678;
            'h15    : reg_data_out <= 32'h87654321;
            'h16    : reg_data_out <= 32'h07301751;
            'h17    : reg_data_out <= ticks;
            default : reg_data_out <= slv_reg[axi_araddr[7:2]];
        endcase
    end
    // Output register or memory read data
    wire slv_reg_rden = axi_arready && s00_axi_arvalid && !axi_rvalid;
    always @(posedge clk) begin
        if (!s00_axi_aresetn) begin
            axi_rdata <= 0;
        end else begin
            // When there is a valid read address (arvalid) with
            // acceptance of read address by the slave (arready),
            // output the read data
            if (slv_reg_rden) begin
                axi_rdata <= reg_data_out;  // register read data
            end
        end
    end
    assign oreg0 = slv_reg[0];
    assign oreg1 = slv_reg[1];
    assign oreg2 = slv_reg[2];
    localparam IDLE=0, WRITE=1, READ=2, READ1=3;
    reg [1:0] fsm=0;
    reg [15:0] baddr_ff=0, bwrdata_ff=0;
    reg bwr_ff=0, bstrobe_ff=0;
    always @(posedge clk) begin
        case (fsm)
            IDLE: 
              begin
                  if (slv_reg_wren && axi_awaddr[7:2]=='h08) begin
                      baddr_ff <= s00_axi_wdata[31:16];
                      bwrdata_ff <= s00_axi_wdata[15:0];
                      bwr_ff <= 1;
                      bstrobe_ff <= 1;
                      fsm <= WRITE;
                  end else if (slv_reg_wren && axi_awaddr[7:2]=='h09) begin
                      baddr_ff <= s00_axi_wdata[31:16];
                      bwrdata_ff <= 0;
                      bwr_ff <= 0;
                      bstrobe_ff <= 0;
                      fsm <= READ;
                  end else begin
                      baddr_ff <= 0;
                      bwrdata_ff <= 0;
                      bwr_ff <= 0;
                      bstrobe_ff <= 0;
                      fsm <= IDLE;
                  end
              end
            WRITE:
              begin
                  // register-file 'bus' write cycle
                  baddr_ff <= 0;
                  bwrdata_ff <= 0;
                  bwr_ff <= 0;
                  bstrobe_ff <= 0;
                  fsm <= IDLE;
              end
            READ:
              begin
                  // register-file 'bus' read cycle
                  bstrobe_ff <= 1;
                  fsm <= READ1;
              end
            READ1:
              begin
                  bstrobe_ff <= 0;
                  baddr_ff <= 0;
                  last_rdaddr <= baddr;
                  last_rddata <= brddata;
                  fsm <= IDLE;
              end
        endcase
    end
    assign baddr = baddr_ff;
    assign bwrdata = bwrdata_ff;
    assign bwr = bwr_ff;
    assign bstrobe = bstrobe_ff;
endmodule

`default_nettype wire