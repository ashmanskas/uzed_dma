
`timescale 1 ns / 1 ps

module wja_bus_lite
    (
     output wire [31:0] reg0,
     // output wire [31:0] reg1,
     // output wire [31:0] reg2,
     // input  wire [31:0] R3,
     // input  wire [31:0] R4,
     // input  wire [31:0] R5,
     // input  wire [31:0] R6,
     // input  wire [31:0] R7,
     // Ports of Axi Slave Bus Interface S00_AXI
     // global clock signal
     input  wire        s00_axi_aclk,
     // active-low global reset signal
     input  wire        s00_axi_aresetn,
     // write address: issued by master, acceped by slave
     input  wire  [4:0] s00_axi_awaddr,  // ADDR_WIDTH
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
     input  wire  [4:0] s00_axi_araddr,  // ADDR_WIDTH
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
    // AXI4LITE signals
    reg  [4:0] axi_awaddr;  // ADDR_WIDTH
    reg        axi_awready;
    reg        axi_wready;
    reg  [1:0] axi_bresp;
    reg        axi_bvalid;
    reg  [4:0] axi_araddr;  // ADDR_WIDTH
    reg        axi_arready;
    reg [31:0] axi_rdata;
    reg  [1:0] axi_rresp;
    reg        axi_rvalid;
    // Example-specific design signals
    reg [31:0] slv_reg0;
    reg [31:0] slv_reg1;
    reg [31:0] slv_reg2;
    wire       slv_reg_wren;
    reg [31:0] reg_data_out;
    integer    b;  // byte_index
    // I/O Connections assignments
    assign s00_axi_awready = axi_awready;
    assign s00_axi_wready  = axi_wready;
    assign s00_axi_bresp   = axi_bresp;
    assign s00_axi_bvalid  = axi_bvalid;
    assign s00_axi_arready = axi_arready;
    assign s00_axi_rdata   = axi_rdata;
    assign s00_axi_rresp   = axi_rresp;
    assign s00_axi_rvalid  = axi_rvalid;
    // assert awready for one clk cycle when both awvalid and wvalid
    // are asserted
    always @(posedge s00_axi_aclk) begin
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
    always @(posedge s00_axi_aclk) begin
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
    always @(posedge s00_axi_aclk) begin
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
    always @(posedge s00_axi_aclk) begin
        if (!s00_axi_aresetn) begin
            slv_reg0 <= 0;
            slv_reg1 <= 0;
            slv_reg2 <= 0;
        end else begin
            if (slv_reg_wren) begin
                // For each slave register, assert respective byte
                // enables as per write strobes
                case (axi_awaddr[4:2])
                    3'h0:
                      for (b = 0; b<=3; b = b+1)
                        if (s00_axi_wstrb[b]) begin
                            slv_reg0[(b*8)+:8] <= s00_axi_wdata[(b*8)+:8];
                        end  
                    3'h1:
                      for (b = 0; b<=3; b = b+1)
                        if (s00_axi_wstrb[b]) begin
                            slv_reg1[(b*8)+:8] <= s00_axi_wdata[(b*8)+:8];
                        end  
                    3'h2:
                      for (b = 0; b<=3; b = b+1)
                        if (s00_axi_wstrb[b]) begin
                            slv_reg2[(b*8)+:8] <= s00_axi_wdata[(b*8)+:8];
                        end  
                    default : begin
                        slv_reg0 <= slv_reg0;
                        slv_reg1 <= slv_reg1;
                        slv_reg2 <= slv_reg2;
                    end
                endcase
            end
        end
    end    
    // Implement write response logic generation The write response
    // and response valid signals are asserted by the slave when
    // axi_wready, s00_axi_wvalid, axi_wready and s00_axi_wvalid are
    // asserted.  This marks the acceptance of address and indicates
    // the status of write transaction.
    always @(posedge s00_axi_aclk) begin
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
    always @(posedge s00_axi_aclk) begin
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
    always @(posedge s00_axi_aclk) begin
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
    always @(*) begin
        case (axi_araddr[4:2])  // address decode for reading registers
            3'h0   : reg_data_out <= slv_reg0;
            3'h1   : reg_data_out <= slv_reg1;
            3'h2   : reg_data_out <= slv_reg2;
            3'h3   : reg_data_out <= 32'hdeadbeef; // R3;
            3'h4   : reg_data_out <= 32'h12345678; // R4;
            3'h5   : reg_data_out <= 32'h87654321; // R5;
            3'h6   : reg_data_out <= 32'h07301751; // R6;
            3'h7   : reg_data_out <= 0; // R7;
            default : reg_data_out <= 0;
        endcase
    end
    // Output register or memory read data
    wire slv_reg_rden = axi_arready && s00_axi_arvalid && !axi_rvalid;
    always @(posedge s00_axi_aclk) begin
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
    assign reg0 = slv_reg0;
    // assign reg1 = slv_reg1;
    // assign reg2 = slv_reg2;
endmodule
