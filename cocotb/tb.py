
import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge, Edge, ClockCycles
from cocotb.result import TestFailure
from cocotb.utils import get_sim_time

import random
import numpy as np
import traceback

from wjautil import MyBits

# * global definitions

ps = 1
ns = 1000
Tclk = 10*ns

def get_ns():
  return get_sim_time(units="ns")

def Int(simvalue):
  try:
    return int(str(simvalue.value), 2)
  except ValueError:
    return 0

expecteq_nonfatal = True
expecteq_oksofar = True
expecteq_nok = 0
expecteq_nfail = 0
expecteq_errmsg_list = []

def expecteq(fmt, got, exp):
    """
    Compare 'exp' with 'got' and if neq complain using format 'fmt'
    """
    global expecteq_nok
    global expecteq_nfail
    global expecteq_oksofar
    if got != exp:
        if fmt=="":
            fmt = "%s: "%(got._path) + "%x != %x"
            fmt += "  @t=%d"%(get_ns())
        expecteq_nfail += 1
        expecteq_oksofar = False
        errmsg = fmt%(got, exp)
        print errmsg
        expecteq_errmsg_list.append(errmsg)
        if not expecteq_nonfatal:
            raise TestFailure(fmt%(got, exp))
        else:
            stack = traceback.extract_stack()
            print stack[-2]
    else:
        expecteq_nok += 1

def expecteq_reset():
    global expecteq_nok
    global expecteq_nfail
    global expecteq_oksofar
    global expecteq_errmsg_list
    expecteq_oksofar = True
    expecteq_nfail = 0
    expecteq_nok = 0
    expecteq_errmsg_list = []
      
def expecteq_fail_if_not_ok():
    print "expecteq: %d comparisons OK, %d notok"%(
        expecteq_nok, expecteq_nfail)
    if not expecteq_oksofar:
        print "== list of failing errmsg =="
        for errmsg in expecteq_errmsg_list:
            print "  " + errmsg
        raise TestFailure("expecteq comparison failed")

def printnet(net):
    print "%s = %x  @t=%d"%(
        net._path, net, get_ns())
    
class RetVal:
  # is there a better way for coroutine to return value?
  pass


class Tester(object):

    def __init__(self, dut):
        self.dut = dut
        self.bytessent = 0
        self.bytesseen = 0

    @cocotb.coroutine
    def wait_clk(self, n=1):
        """
        Wait for 'n' cycles of 'dut.clk'.  Avoids cocotb bug in which
        RisingEdge and ClockCycles conflict with one another.
        https://github.com/potentialventures/cocotb/issues/520
        """
        for i in range(n):
            yield RisingEdge(self.dut.clk)

    @cocotb.coroutine
    def axi_wr(self, a, d):
        dut = self.dut
        dut.awvalid = 0
        dut.wvalid = 0
        dut.bready = 0
        yield self.wait_clk()
        dut.awaddr = a<<2
        dut.wdata = d
        dut.awvalid = 1
        dut.wvalid = 1
        dut.bready = 1
        for i in range(10):
            yield self.wait_clk()
            if Int(dut.awready) and Int(dut.wready):
                break
            if i==9:
                raise TestFailure("timeout(awready/wready)")
        dut.awaddr = 0
        dut.wdata = 0
        dut.awvalid = 0
        dut.wvalid = 0
        dut.bready = 0
        yield self.wait_clk()

    @cocotb.coroutine
    def s6_rd(self, a, rv=None):
        # Mimic 'a7_rd' code in busio.c
        dut = self.dut
        yield self.bus_rd(0x0084)  # bytessent0
        expecteq("", dut.last_rdata, self.bytessent)
        yield self.bus_rd(0x0083)  # bytesseen0
        expecteq("", dut.last_rdata, self.bytesseen)
        yield self.bus_wr(0x0082, a>>8 & 0xff)
        yield self.bus_wr(0x0082, a    & 0xff)
        yield self.bus_wr(0x0082, 0x0102)
        yield self.wait_clk(30)
        yield self.bus_rd(0x0083)  # bytesseen1
        expecteq("", dut.last_rdata, (self.bytesseen + 3) & 0xffff)
        self.bytesseen = Int(dut.last_rdata)
        yield self.bus_rd(0x0084)  # bytessent1
        expecteq("", dut.last_rdata, (self.bytessent + 3) & 0xffff)
        self.bytessent = Int(dut.last_rdata)
        yield self.bus_rd(0x0080)  # status
        expecteq("", dut.last_rdata, 0x0002)
        yield self.bus_rd(0x0081)  # data
        data = Int(dut.last_rdata) & 0xffff
        if rv is not None:
            rv.data = data
        dut.last_rdata = data
        
    @cocotb.coroutine
    def s6_wr(self, a, d):
        # Mimic 'a7_wr' code in busio.c
        dut = self.dut
        yield self.bus_rd(0x0084)  # bytessent0
        expecteq("", dut.last_rdata, self.bytessent)
        yield self.bus_rd(0x0083)  # bytesseen0
        expecteq("", dut.last_rdata, self.bytesseen)
        yield self.bus_wr(0x0082, d>>8 & 0xff)
        yield self.bus_wr(0x0082, d    & 0xff)
        yield self.bus_wr(0x0082, a>>8 & 0xff)
        yield self.bus_wr(0x0082, a    & 0xff)
        yield self.bus_wr(0x0082, 0x0101)
        yield self.wait_clk(3)
        yield self.bus_rd(0x0083)  # bytesseen1
        expecteq("", dut.last_rdata, (self.bytesseen + 1) & 0xffff)
        self.bytesseen = Int(dut.last_rdata)
        yield self.bus_rd(0x0084)  # bytessent1
        expecteq("", dut.last_rdata, (self.bytessent + 5) & 0xffff)
        self.bytessent = Int(dut.last_rdata)
        yield self.bus_rd(0x0080)  # status
        expecteq("", dut.last_rdata, 0x0001)
        
    @cocotb.coroutine
    def bus_rd(self, a, rv=None):
        # Mimic 'busrd' code in busio.c
        dut = self.dut
        yield self.axi_rd(7)
        expecteq("", dut.last_rdata, 0xfab40001)
        # all PS strobes should already be zero
        yield self.axi_wr(2, 0)
        # PL strobe should already be zero
        yield self.axi_rd(3)
        expecteq("r[3] & 1: %x != %x", Int(dut.last_rdata) & 1, 0)
        # set address register
        yield self.axi_wr(1, a & 0xffff)
        # raise PS read strobe
        yield self.axi_wr(2, 1)
        # Wait for FSM to catch up
        yield self.wait_clk(4)
        # PL strobe should be 1 now
        yield self.axi_rd(3)
        expecteq("r[3] & 1: %x != %x", Int(dut.last_rdata) & 1, 1)
        # read data register
        yield self.axi_rd(4)
        data = Int(dut.last_rdata) & 0xffff
        # lower PS read strobe
        yield self.axi_wr(2, 0)
        if rv is not None:
            rv.data = data
        dut.last_rdata = data

    @cocotb.coroutine
    def bus_wr(self, a, d):
        # Mimic 'buswr' code in busio.c
        dut = self.dut
        yield self.axi_rd(7)
        expecteq("", dut.last_rdata, 0xfab40001)
        # all PS strobes should already be zero
        yield self.axi_wr(2, 0)
        # PL strobe should already be zero
        yield self.axi_rd(3)
        expecteq("r[3] & 1: %x != %x", Int(dut.last_rdata) & 1, 0)
        # set address+data register
        yield self.axi_wr(1, ((d & 0xffff) << 16) | (a & 0xffff))
        # raise PS write strobe
        yield self.axi_wr(2, 2)
        # Wait for FSM to catch up
        yield self.wait_clk(4)
        # PL strobe should be 1 now
        yield self.axi_rd(3)
        expecteq("r[3] & 1: %x != %x", Int(dut.last_rdata) & 1, 1)
        # read data register
        yield self.axi_rd(4)
        data = Int(dut.last_rdata) & 0xffff
        # lower PS write strobe
        yield self.axi_wr(2, 0)

    @cocotb.coroutine
    def axi_rd(self, a, rv=None):
        dut = self.dut
        dut.rready = 0
        dut.arvalid = 0
        yield self.wait_clk()
        dut.araddr = a<<2
        dut.arvalid = 1
        dut.rready = 1
        for i in range(10):
            yield self.wait_clk()
            if Int(dut.arready):
                break
            if i==9:
                raise TestFailure("timeout(arready)")
        dut.arvalid = 0
        for i in range(10):
            yield self.wait_clk()
            if Int(dut.rvalid):
                break
            if i==9:
                raise TestFailure("timeout(rvalid)")
        dut.last_rdata = Int(dut.rdata)
        if rv is not None:
            rv.rdata = Int(dut.rdata)
        dut.rready = 0
        dut.araddr = 0
        yield self.wait_clk()

    @cocotb.coroutine
    def do_reset(self):
        dut = self.dut
        yield self.wait_clk(10)
        dut.aresetn = 0
        dut.awaddr = 0
        dut.awprot = 0
        dut.awvalid = 0
        dut.wdata = 0
        dut.wstrb = 0xf
        dut.wvalid = 0
        yield self.wait_clk(10)
        dut.aresetn = 1
        yield self.wait_clk()
        
    @cocotb.coroutine
    def run_hello(self):
        dut = self.dut
        dut._log.info("run_hello: begin")
        yield self.do_reset()
        yield self.axi_wr(0x22, 0x54321888)
        expecteq("", dut.bl.slv_reg[0x22], 0x54321888)
        yield self.axi_wr(0x22, 0x54321999)
        expecteq("", dut.bl.slv_reg[0x22], 0x54321999)
        yield self.axi_wr(0, 0xbabeface)
        expecteq("", dut.bl.slv_reg[0], 0xbabeface)
        expecteq("", dut.reg0, 0xbabeface)
        yield self.axi_rd(0x13)
        expecteq("", dut.last_rdata, 0xdeadbeef)
        yield self.axi_rd(0x14)
        expecteq("", dut.last_rdata, 0x12345678)
        yield self.axi_rd(0x15)
        expecteq("", dut.last_rdata, 0x87654321)
        yield self.axi_rd(0x22)
        expecteq("", dut.last_rdata, 0x54321999)
        yield self.bus_rd(0x0001)
        expecteq("", dut.last_rdata, 0xbeef)
        yield self.bus_rd(0x0002)
        expecteq("", dut.last_rdata, 0xdead)
        yield self.bus_wr(0x0003, 0x1234)
        expecteq("", dut.mv.q0003, 0x1234)
        yield self.bus_wr(0x0004, 0x5678)
        expecteq("", dut.mv.q0004, 0x5678)
        yield self.bus_rd(0x0003)
        expecteq("", dut.last_rdata, 0x1234)
        yield self.bus_rd(0x0004)
        expecteq("", dut.last_rdata, 0x5678)
        yield self.s6_rd(0x0002)
        expecteq("", dut.last_rdata, 0xdead)
        yield self.s6_wr(0x0003, 0x1234)
        yield self.s6_rd(0x0003)
        expecteq("", dut.last_rdata, 0x1234)
        yield self.s6_rd(0x0001)
        expecteq("", dut.last_rdata, 0xbeef)
        yield self.s6_rd(0x0003)
        expecteq("", dut.last_rdata, 0x1234)
        dut._log.info("run_hello: done")

    @cocotb.coroutine
    def run_anode_path_more_realistic(self):
        dut = self.dut
        dut._log.info("run_anode_path_more_realistic: begin")
        rs = dut.rs
        ap = rs.AP
        dtd = rs.dtd
        yield self.wait_clk(50)
        if 0: self.debug_thread = cocotb.fork(self.monitor_stuff())
        baseline = 1638  # see bpdig_anode.v comments
        # --------------------------------------------------
        # trigger source := 'NIM'
        yield self.bus_wq_chk(0x0100, 0x0001, rs.trigger_source)
        # spybuf input select := 'anode'
        yield self.bus_wq_chk(0x0201, 0x0002, rs.spybuf_input_select)
        # --------------------------------------------------
        # These are largely in order of appearance in anode_path.v:
        self.baseline = 16*[0]
        for i in range(16):
            # anode integration pipeline length minus 1
            yield self.bus_wq_chk(
                0x0a10+i, 0x000f, ap.integration_pipeline_len[i])
            # anode data pipeline length
            yield self.bus_wq_chk(0x0a20+i, 0x0008, ap.data_pipeline_len[i])
            # anode baseline value (to be subtracted)
            ibaseline = baseline
            ibaseline = 3*i  # chosen somewhat arbitrarily
            self.baseline[i] = ibaseline
            yield self.bus_wq_chk(0x0a30+i, ibaseline, ap.baseline_value[i])
            # ADC data IO delay (is this functional?)
            yield self.bus_wq_chk(0x0a60+i, 0x0000, ap.adc_io_delay[i])
        for i in range(4):
            # ADC framing signal IO delay (is this functional?)
            yield self.bus_wq_chk(0x0a70+i, 0x0000, ap.adc_io_delay_frame[i])
        # select mask for resetting IODELAY2 (is this functional?)
        yield self.bus_wq_chk(0x0a78, 0x0000, ap.adc_io_delay_rst)
        # channel enable := ALL
        yield self.bus_wq_chk(0x0a80, 0xffff, ap.channel_enable)
        # readout mode := 'scope'
        yield self.bus_wq_chk(0x0a90, 0x0002, ap.readout_mode)
        # baseline subtract mode := 'constant' ('tracking' NYI)
        yield self.bus_wq_chk(0x0aa0, 0x0000, ap.baseline_sub_mode)
        # trigger delay select := 5 (range 0..63)
        yield self.bus_wq_chk(0x0ab0, 16, ap.trigger_delay_select)
        # As currently coded (with trigger_delay_select == 16, and
        # with do_test_pattern == True), I see 'trigger_delayed' when
        # anode_raw[n] == n0F, and scope[n] == 0n0D.  'afifo_wen'
        # rises two clocks after 'trigger_delayed' pulse.  In scope
        # mode, data written to FIFO n are 0n0F..0n2D (31 values).
        #
        # AP output mode := 'raw' (not 'sum')
        yield self.bus_wq_chk(0x0009, 0x0000, ap.data_out_mode)
        # assert top-level 'fifo_reset' signal
        yield self.bus_wq(0x000e, 0x0001)
        # check that anode_path FIFOs are really empty
        expecteq("", ap.anode_data_fifo.nword, 0)
        for i in range(16):
            expecteq("", ap.AEB.fifo[i].anode_fifo.nword, 0)
        # check that dynode_trigger_data FIFO is really empty
        expecteq("", dtd.trigger_data_fifo.nword, 0)
        # Temporarily inhibit afifo readout in anode_event_builder.
        # This is a simulation-only feature, to make the data flow
        # easier to examine.
        ap.AEB.inhibit = 1
        # Now initialize dynode_trigger_data path
        yield self.bus_wq_chk(0x0d07, 4, rs.dynode_integration_pipeline_len)
        yield self.bus_wq_chk(0x0d08, 1, rs.dynode_data_pipeline_len)
        yield self.bus_wq_chk(0x0e02, 1, rs.trigger_data_mode)
        if 1:
            # This is really for DRS path (dynode_path.v)
            yield self.bus_wq_chk(0x0d01, 200, rs.dyn0.readout_ncells)
        # --------------------------------------------------
        # Srilalan says gaussian with FWTM ~ 90ns (so I use 6sigma=90ns)
        pulse = [3, 28, 135, 411, 800, 1000, 800, 411, 135, 28, 3]
        row_iadc, row_jchan = 1, 1  # no idea what real channel map is
        col_iadc, col_jchan = 2, 2  # no idea what real channel map is
        ktzero = 20
        # Calculate data pattern to send
        do_test_pattern = True
        for iadc in range(4):
            for jchan in range(4):
                for kword in range(80):
                    adcword = baseline
                    if ((kword >= ktzero and kword < ktzero+len(pulse)) and
                        ((iadc==row_iadc and jchan==row_jchan) or
                         (iadc==col_iadc and jchan==col_jchan))):
                        adcword += pulse[kword-ktzero]
                    if do_test_pattern:
                        adcword = (
                            iadc<<10 |
                            jchan<<8 |
                            (kword & 0xff))
                    self.ad9633_push(iadc, jchan, adcword)
        # Also calculate AD9222 data pattern (this may move elsewhere later)
        for idrs in range(2):
            for jchan in range(8):
                for kword in range(500):
                    adcword = [0x555, 0xaaa][kword%2]
                    adcword = jchan<<8 | (kword & 0xff)
                    self.ad9222_push(idrs, jchan, adcword)
        # Set AD9633 (anode) ADC outputs to bogus value
        print "should send data at t=%d ns"%(get_ns())
        for i in range(4):
           yield self.ad9633_ddr(i, [0, 0, 0, 0])
        # Issue trigger pulse
        yield self.wait_clk(1)
        dut.trig_in_prompt = 1
        yield self.wait_clk(2)
        dut.trig_in_prompt = 0
        yield self.wait_clk(2)
        # Send AD9633 (anode) ADC data
        self.feed_adc_thread = 4*[0]
        for iadc in range(4):
            self.feed_adc_thread[iadc] = cocotb.fork(
                self.feed_ad9633_task(iadc))
        # Send AD9222 (DRS4) ADC data (this may later move elsewhere)
        self.feed_ad9222_thread = 2*[0]
        for iadc in range(2):
            self.feed_ad9222_thread[iadc] = cocotb.fork(
                self.feed_ad9222_task(iadc))
        yield self.wait_clk(200)
        for i in range(16):
            printnet(ap.AEB.fifo[i].anode_fifo.nword)
        # Check data written into each anode_fifo
        for i in range(16):
            expecteq("", ap.AEB.fifo[i].anode_fifo.wptr, 32)
            expecteq("", ap.AEB.fifo[i].anode_fifo.rptr, 0)
            # In current firmware, maximum allowed energy integration
            # length is 16 samples, while scope readout length is 31
            # samples (plus the appended energy word).  With current
            # pipeline-delay settings, the 16-word integration window
            # appears at positions 12 through 27 (counting from zero)
            # of the scope readout.
            for j in range(31):
                offset_nticks = 15
                word = self.ad9633_history[i][offset_nticks + j]
                expecteq("", ap.AEB.fifo[i].anode_fifo.mem[j], word)
            # Note: the baseline value is subtracted from the N-sample
            # sum, not from each individual sample!
            bl = self.baseline[i]
            sumword = np.sum(self.ad9633_history[i][27:][:16])
            if sumword<bl:
                sumword = 0
            else:
                sumword -= bl
            expecteq("", ap.AEB.fifo[i].anode_fifo.mem[31], sumword)
        # now permit AEB to drain afifo[]
        ap.AEB.inhibit = 0
        yield self.wait_clk(600)
        for i in range(16):
            expecteq("", ap.AEB.fifo[i].anode_fifo.wptr, 32)
            expecteq("", ap.AEB.fifo[i].anode_fifo.rptr, 32)
            printnet(ap.anode[i].anode.int_pipeline_len)
        # check that data were correctly concatenated
        printnet(ap.anode_data_fifo.nword)
        expecteq("", ap.anode_data_fifo.nword, 0x203)
        trigger_number = 1
        fm = ap.anode_data_fifo.mem
        expecteq("", fm[0], 0xa5a0 | (trigger_number & 15))
        n_data_words = 0x200
        readout_mode = 2
        expecteq("", fm[1], readout_mode<<12 | n_data_words)
        enabled_chnl_mask = 0xffff
        expecteq("", fm[2], enabled_chnl_mask)
        for i in range(n_data_words):
            janode = i/32
            kword = i%32
            expword = self.ad9633_history[janode][offset_nticks + kword]
            if kword==31:
                bl = self.baseline[janode]
                sumword = np.sum(self.ad9633_history[janode][27:][:16])
                if sumword<bl:
                    sumword = 0
                else:
                    sumword -= bl
                expword = sumword
            expecteq("", fm[3+i], expword)
        if 0:
            print "ap.anode_data_fifo.mem:", " ".join(
                ["%04x"%(ap.anode_data_fifo.mem[i]) for i in range(0x203)])
        # check that data were written to dynode_trigger_data FIFO
        expecteq("", dtd.trigger_data_fifo.nword, 3+32)
        expecteq("", dtd.trigger_data_fifo.mem[0], 0xa5a5)
        expecteq("", dtd.trigger_data_fifo.mem[1], 32)
        expecteq("", dtd.trigger_data_fifo.mem[2], 0x0001)
        for i in range(32):
            # This will become nonzero once I get AD9287 data flowing
            expecteq("", dtd.trigger_data_fifo.mem[3+i], 0)
        # check that data were written to DRS4 readout FIFOs
        drsa = rs.dyn0.DRSA_rfsm
        drsb = rs.dyn0.DRSB_rfsm
        fifoa = [drsa.__getattr__("fifo_ch%d"%(i)) for i in range(8)]
        fifob = [drsb.__getattr__("fifo_ch%d"%(i)) for i in range(8)]
        for i in range(8):
            nword = 200
            word0 = 12
            expecteq("", fifoa[i].nword, nword)
            for j in range(nword):
                # assign 'qout' in ad9222_s6.v reverses channel order
                expecteq("", fifoa[i].mem[j],
                         self.ad9222_history[7-i][word0+j])
        # assert top-level 'fifo_reset' signal
        yield self.bus_wq(0x000e, 0x0001)
        yield self.wait_clk(2)
        # check that anode_path FIFOs are really empty
        expecteq("", ap.anode_data_fifo.nword, 0)
        for i in range(16):
            expecteq("", ap.AEB.fifo[i].anode_fifo.nword, 0)
        yield self.wait_clk(10)
        if 0:
            #
            # This is a quick-and-dirty check of DRS4 reaodut hacked in here
            #
            yield self.bus_wq_chk(0x0100, 0x12, rs.trigger_source)
            for i in range(2):
                yield self.bus_wq(0x0e20, 1)  # trigger_soft
                yield self.wait_clk(1000)
        yield self.wait_clk(100)
        dut._log.info("run_anode_path_more_realistic: done")


from testwrapper import CocotbTest
@CocotbTest("T02", skip=False)
def test02_hello(dut):
    "hello world: test AXI-Lite I/O to wja_bus_lite module"
    expecteq_reset()
    dut.cocotb_testnum = 2
    o = Tester(dut)
    yield o.run_hello()
    expecteq_fail_if_not_ok()

from testwrapper import CocotbTest
@CocotbTest("T99", skip=True)
def test99_ipython(dut):
    "embed IPython shell for interactive exploration"
    expecteq_reset()
    dut.cocotb_testnum = 99
    o = RocstarTester(dut)
    yield o.run_hello()
    skip = False
    try:
        text = open("skip_t99.txt").read().strip().upper()
        print "skip_t99.txt contents:", text
        if "Y" in text:
            skip = True
    except IOError:
        print "skip_t99.txt not found"
        pass
    if skip:
        print "skipping T99 IPython() invocation, due to 'skip_t99.txt'"
    else:
        import IPython
        IPython.embed_kernel()
    expecteq_fail_if_not_ok()
