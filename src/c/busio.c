/*
 * busio.c
 * Attempt to R/W arbitrary MicroZed memory from Linux command line
 * wja 2014-12-17
 */

#include <stdio.h>
#include <fcntl.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <assert.h>
#include <sys/mman.h>

#include "busio.h"

typedef unsigned long u32;
typedef unsigned long u32;
#define NEL(x) ((sizeof((x))/sizeof((x)[0])))

static int memfd = 0;
static size_t *bus_r = 0;

static int
bus_init(void)
{
  // Xilinx uses u32, while mmap uses size_t
  assert(sizeof(u32)==sizeof(size_t));
  // It seems that mmap wants base address to lie on a page boundary
  u32 base = 0x43c00000;
  // Map 4096 bytes (which is presumably a page or power-of-two pages)
  u32 mlen = 0x00001000;
  void *mapped_base = 0;
  memfd = open("/dev/mem", O_RDWR | O_SYNC);
  assert(memfd != -1);
  mapped_base = mmap(0, mlen,
		     PROT_READ|PROT_WRITE, MAP_SHARED,
		     memfd, base);
  assert(mapped_base != MAP_FAILED);
  bus_r = (size_t *) mapped_base;
}

void
buswr(int addr, int data)
{
  if (!bus_r) bus_init();
  size_t *r = bus_r;
  assert(r!=0);
  assert(r[7]==0xfab40001);
  // "bus" write operation
  r[2] = 0;                        // all PS strobes should already be 0
  assert((r[3] & 1)==0);           // PL strobe should already be 0
  r[1] = ((data & 0xffff) << 16) | (addr & 0xffff);
  r[2] = 2;                        // raise PS write strobe
  assert(r[3] & 1);                // PL strobe should be 1 now
  r[2] = 0;                        // lower PS write strobe
  // printf("busio: wr %04x := %04x\n", r[5] & 0xffff, r[4] & 0xffff);
  return;
}

int
busrd(int addr)
{
  if (!bus_r) bus_init();
  size_t *r = bus_r;
  assert(r!=0);
  assert(r[7]==0xfab40001);
  // "bus" read operation
  r[2] = 0;                        // all PS strobes should already be 0
  assert((r[3] & 1)==0);           // PL strobe should already be 0
  r[1] = addr & 0xffff;
  r[2] = 1;                        // raise PS read strobe
  assert(r[3] & 1);                // PL strobe should be 1 now
  int data = r[4] & 0xffff;        // latch in data from read cycle
  r[2] = 0;                        // lower PS read strobe
  //printf("busio: rd %04x ==> %04x\n", r[5] & 0xffff, data);
  return data;
}

int
a7rd(int addr)
{
  int bytessent0 = busrd(0x0084);
  int bytesseen0 = busrd(0x0083);
  buswr(0x0082, addr>>8 & 0xff);
  buswr(0x0082, addr    & 0xff);
  buswr(0x0082, 0x0102);
  int bytesseen_expect = (bytesseen0+3) & 0xffff;
  int bytesseen1 = busrd(0x0083);
  int bytessent1 = busrd(0x0084);
  int status = busrd(0x0080);
  int data = busrd(0x0081);
  if (bytesseen1!=bytesseen_expect ||
      status!=2 || addr==0xffff ||
      bytessent1!=((bytessent0+3)&0xffff)) {
    printf("a7rd: a=%x bs0=%d bs1=%d bsexp=%d st=%x d=%x\n"
	   "      bx0=%d bx1=%d dbx=%d\n",
	   addr, bytesseen0, bytesseen1, bytesseen_expect,
	   status, data, 
	   bytessent0, bytessent1, (bytessent1-bytessent0)&0xffff);
  }
  return data;
}

void
a7wr(int addr, int data)
{
  int bytesseen0 = busrd(0x0083);
  buswr(0x0082, data>>8 & 0xff);
  buswr(0x0082, data    & 0xff);
  buswr(0x0082, addr>>8 & 0xff);
  buswr(0x0082, addr    & 0xff);
  buswr(0x0082, 0x0101);
  int bytesseen_expect = (bytesseen0+1) & 0xffff;
  int bytesseen1 = busrd(0x0083);
  int status = busrd(0x0080);
  if (bytesseen1!=bytesseen_expect || status!=1) {
    printf("a7wr: a=%x bs0=%d bs1=%d bsexp=%d st=%x\n",
	   addr, bytesseen0, bytesseen1, bytesseen_expect, status);
  }
  return;
}

void
shiftit(int bit, int oen)
{
  enum {
    OEN = 1<<4,
    DS = 1<<3,
    STCP = 1<<2,
    STCP0 = 1<<1,
    SHCP = 1<<0
  };
  int ds = (bit & 1) ? DS : 0;
  buswr(0x000a, oen);
  buswr(0x000a, oen | ds);
  buswr(0x000a, oen | ds | SHCP);
  buswr(0x000a, oen | ds);
  buswr(0x000a, oen);
}

/*
 * Shift registers:
 *
 * led0
 * ..
 * led7
 * ad9222pdwn0
 * ..
 * ad9222pdwn9
 * ad9287pdwn0
 * ..
 * ad9287pdwn5
 * drsresetn0
 * ..
 * drsresetn9
 * calena0
 * ..
 * calena19
 * calclkenan
 * led10
 */
void
shreg(int led, int pdwn9222, int pdwn9287,
      int drsreset, int calena, int calclkena)
{
  enum {
    OEN = 1<<4,
    DS = 1<<3,
    STCP = 1<<2,
    STCP0 = 1<<1,
    SHCP = 1<<0
  };
  int oen = OEN;
  oen = 0;
  buswr(0x000a, oen);
  shiftit(led>>10 & 1, oen);
  shiftit(calclkena, oen);
  for (int i = 19; i>=0; i--) shiftit(calena>>i & 1, oen);
  for (int i = 9; i>=0; i--) shiftit(drsreset>>i & 1, oen);
  for (int i = 5; i>=0; i--) shiftit(pdwn9287>>i & 1, oen);
  for (int i = 9; i>=0; i--) shiftit(pdwn9222>>i & 1, oen);
  for (int i = 7; i>=0; i--) shiftit(led>>i & 1, oen);
  buswr(0x000a, oen);
  buswr(0x000a, oen | STCP | STCP0);
  buswr(0x000a, oen);
  buswr(0x000a, 0);
}

/*
 * Temporary hack for writing to 'CLKDIV' LMK03000 chip.
 */
static void
clkzzz_word(int baddr, int ireg, int data)
{
  int leu = 1, clk = 0, dat = 0;
  // enum { LEU = 1<<8, CLK = 1<<4, DAT = 1<<0 };
  enum { LEU = 8, CLK = 4, DAT = 0 };
  // int baddr = 0x000e;
  printf("clkdiv_word: ireg=%x := data=%x\n", ireg, data);
  leu = 1; clk = 0; dat = 0;
  buswr(baddr, leu<<LEU | clk<<CLK | dat<<DAT);
  leu = 0; clk = 0; dat = 0;
  buswr(baddr, leu<<LEU | clk<<CLK | dat<<DAT);
  for (int i = 27; i>=0; i--) {
    dat = data>>i & 1;
    buswr(baddr, 0<<CLK | dat<<DAT);
    buswr(baddr, 1<<CLK | dat<<DAT);
    buswr(baddr, 0<<CLK | dat<<DAT);
  }
  for (int i = 3; i>=0; i--) {
    dat = ireg>>i & 1;
    buswr(baddr, 0<<CLK | dat<<DAT);
    buswr(baddr, 1<<CLK | dat<<DAT);
    buswr(baddr, 0<<CLK | dat<<DAT);
  }
  leu = 0; clk = 0; dat = 0;
  buswr(baddr, leu<<LEU | clk<<CLK | dat<<DAT);
  leu = 1; clk = 0; dat = 0;
  buswr(baddr, leu<<LEU | clk<<CLK | dat<<DAT);
  return;
}


void
clkdiv_word(int ireg, int data)
{
  clkzzz_word(0x000e, ireg, data);
}


void
clkcln_word(int ireg, int data)
{
  clkzzz_word(0x000f, ireg, data);
}


void
clkdiv(void)
{
  int ireg = 0;
  int data = 0;
  // clkdiv_word(ireg, data);
  clkdiv_word(0, 1<<(31-4));  // reset to power-on defaults
  ireg = 0;
  data =
    1   << (17-4) |      // CLKout0_MUX := 1 (divided)
    1   << (16-4) |      // CLKout0_EN  := 1 (enabled)
    120 << ( 8-4) |      // CLKout0_DIV := 120
    0   << ( 4-4) ;      // CLKout0_DLY := 0
  clkdiv_word(ireg, data);
  ireg = 13;
  data = 100 << (14-4);  // OSCin_FREQ := 100 (100 MHz)
  clkdiv_word(ireg, data);
  ireg = 15;
  data =
    5  << (26-4) |       // VCO_DIV := 5
    24 << ( 8-4) ;       // PLL_N   := 24
  clkdiv_word(ireg, data);
  return;
}


static int scl = 1, sda = 1, sdw = 1, wc = 0;

static void
iv_do(void)
{
  buswr(0x000c, sda<<(0+wc) | scl<<(4+wc) | sdw<<(8+wc));
}


static int
iv_sendbit(int bit)
{
  scl = 0; iv_do();
  sda = bit; sdw = 1; iv_do();
  scl = 1; iv_do();
  scl = 0; iv_do();
}


static int
iv_recvbit(void)
{
  scl = 0; iv_do();
  sdw = 0; sda = 0; iv_do();
  assert(busrd(0x000c)==0x0000);
  scl = 1; iv_do();
  assert(busrd(0x000c)==(wc==0 ? 0x0010 : 0x0020));
  assert(busrd(0x000c)==(wc==0 ? 0x0010 : 0x0020));
  int bit = busrd(0x000b)>>wc & 1;
  scl = 0; iv_do();
  assert(busrd(0x000c)==0x0000);
  return bit;
}


static int
iv_readack(void)
{
  int d = iv_recvbit();
  if (d!=0) printf("iv_readack: expect 0, read %d\n", d);
  return d;
}


static void
iv_start(void)
{
  scl = 1; sda = 1; sdw = 1; iv_do();
  sda = 0; iv_do();
  scl = 0; iv_do();
}


static void
iv_stop(void)
{
  scl = 0; iv_do();
  sda = 0; sdw = 1; iv_do();
  scl = 1; iv_do();
  sda = 1; iv_do();
}


static int
iv_readword(int a, int b)
{
  // write to command register
  iv_start();
  for (int i = 6; i>=0; i--)
    iv_sendbit(a>>i & 1);
  iv_sendbit(0);
  if (iv_readack()!=0) {
    printf("iv_readack()!=0 after 'a' byte\n");
  }
  for (int i = 7; i>=0; i--)
    iv_sendbit(b>>i & 1);
  if (iv_readack()!=0) {
    printf("iv_readack()!=0 after 'b' byte\n");
  }
  // read two bytes
  iv_start();
  for (int i = 6; i>=0; i--)
    iv_sendbit(a>>i & 1);
  iv_sendbit(1);
  if (iv_readack()!=0) {
    printf("iv_readack()!=0 after reading 1st byte\n");
  }
  int d1 = 0;
  for (int i = 0; i<8; i++)
    d1 = (d1<<1) | iv_recvbit();
  iv_sendbit(0);
  if (iv_readack()!=0) {
    printf("iv_readack()!=0 after reading 2nd byte\n");
  }
  int d0 = 0;
  for (int i = 0; i<8; i++)
    d0 = (d0<<1) | iv_recvbit();
  iv_sendbit(1);
  iv_stop();
  d1 &= 0xff;
  d0 &= 0xff;
  return (d1<<8) | d0;
}


int
iv_word(int chain, int a, int b)
{
  wc = chain;
  scl = 1; sda = 1; sdw = 1; iv_do();
  int d = iv_readword(a, b);
  return d;
}

int
rofiforead(long long *databuf, int databuflen)
{
  int nwords = busrd(0x001c)>>2 & 0xfff;
  for (int i = 0; i<nwords; i++) {
    if (i>=databuflen) break;
    buswr(0x001f, 0);
    long long w3 = busrd(0x0023);
    long long w2 = busrd(0x0022);
    long long w1 = busrd(0x0021);
    long long w0 = busrd(0x0020);
    long long w = (w3<<48) | (w2<<32) | (w1<<16) | w0;
    databuf[i] = w;
  }
  return nwords;
}
