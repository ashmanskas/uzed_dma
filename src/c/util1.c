/*
 * util.c
 * MicroZed Linux application to collect together misc utilities
 * begun 2014-12-17 by wja
 */


#include <assert.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

#include "busio.h"

// external function prototypes
extern int dumb_gpio(int argc, char **argv);
extern int peek_poke(int argc, char **argv);
extern void shreg(int led, int pdwn9222, int pdwn9287,
		  int drsreset, int calena, int calclkena);
extern void clkdiv(void);

// forward declarations
void foobar(void);
void foobar1(void);
void foobar2(void);

int main(int argc, char **argv)
{
  int rc = 0;  // return status code
  if (0) printf("util.c starting: argc=%d\n", argc);
  if (argc>1) {
    // if command-line argument is present, treat first argument as command
    char *cmd = argv[1];
    if (!strcmp(cmd, "dumb")) {
      rc = dumb_gpio(argc-1, argv+1);
    } else if (!strcmp(cmd, "peek") || !strcmp(cmd, "poke")) {
      rc = peek_poke(argc-1, argv+1);
    } else if (!strcmp(cmd, "rd")) {
      assert(argc>2);
      int addr = 0;
      rc = sscanf(argv[2], "%x", &addr);
      assert(rc==1);
      int data = busrd(addr);
      printf("busio: rd %04x ==> %04x\n", addr, data);
      rc = 0;
    } else if (!strcmp(cmd, "wr")) {
      assert(argc>3);
      int addr = 0, data = 0;
      rc = sscanf(argv[2], "%x", &addr);
      assert(rc==1);
      rc = sscanf(argv[3], "%x", &data);
      assert(rc==1);
      buswr(addr, data);
      printf("busio: wr %04x := %04x\n", addr, data);
      rc = 0;
    } else if (!strcmp(cmd, "a7rd") || !strcmp(cmd, "v5rd")) {
      assert(argc>2);
      int addr = 0;
      rc = sscanf(argv[2], "%x", &addr);
      assert(rc==1);
      int data = a7rd(addr);
      printf("busio: a7rd %04x ==> %04x\n", addr, data);
      rc = 0;
    } else if (!strcmp(cmd, "a7wr") || !strcmp(cmd, "v5wr")) {
      assert(argc>3);
      int addr = 0, data = 0;
      rc = sscanf(argv[2], "%x", &addr);
      assert(rc==1);
      rc = sscanf(argv[3], "%x", &data);
      assert(rc==1);
      a7wr(addr, data);
      printf("busio: a7wr %04x := %04x\n", addr, data);
      rc = 0;
    } else if (!strcmp(cmd, "sreg")) {
      if (argc!=8) {
	printf("sreg led pdwn9222 pdwn9287 drsreset calena calclkena\n");
	printf("argc=%d\n", argc);
	assert(argc==7);
      }
      int led=0, pdwn9222=0, pdwn9287=0, drsreset=0, calena=0, calclkena=0;
      rc = sscanf(argv[2], "%x", &led); assert(rc==1);
      rc = sscanf(argv[3], "%x", &pdwn9222); assert(rc==1);
      rc = sscanf(argv[4], "%x", &pdwn9287); assert(rc==1);
      rc = sscanf(argv[5], "%x", &drsreset); assert(rc==1);
      rc = sscanf(argv[6], "%x", &calena); assert(rc==1);
      rc = sscanf(argv[7], "%x", &calclkena); assert(rc==1);
      printf("sreg: led=%x pdwn9222=%x pdwn9287=%x drsreset=%x "
	     "calena=%x calclkena=%x\n",
	     led, pdwn9222, pdwn9287, drsreset, calena, calclkena);
      shreg(led, pdwn9222, pdwn9287, drsreset, calena, calclkena);
      rc = 0;
    } else if (!strcmp(cmd, "clkdiv")) {
      clkdiv();
    } else if (!strcmp(cmd, "foobar")) {
      foobar();
    } else if (!strcmp(cmd, "foobar1")) {
      foobar1();
    } else if (!strcmp(cmd, "foobar2")) {
      foobar2();
    } else {
      fprintf(stderr, "command '%s' unknown\n", cmd);
      rc = 1;
    }
  }
  if (0) printf("util.c done: rc=%d\n", rc);
  return rc;
}


typedef unsigned long u32;
typedef unsigned short u16;

#define NEL(x) (sizeof((x))/sizeof((x)[0]))

void foobar(void)
{
  u32 addr = 0x43c0005c;
  u32 base = addr & 0xfffff000;
  u32 offs = addr & 0x00000fff;
  u32 mlen =        0x00001000;
  int iofs = offs / sizeof(u32);
  void *mapped_base = 0;
  int memfd = open("/dev/mem", O_RDWR | O_SYNC);
  assert(memfd != -1);
  mapped_base = mmap(0, mlen, PROT_READ|PROT_WRITE, MAP_SHARED, memfd, base);
  assert(mapped_base != MAP_FAILED);
  size_t *p = (size_t *) mapped_base;
  u32 retvals[1024];
  int i = 0, nel = NEL(retvals);
  for (i = 0; i<nel; i++)
    retvals[i] = p[iofs];
  for (i = 0; i<nel; i++) {
    // if (i%128!=0 && i+1!=NEL(retvals)) continue;
    printf("%d %x\n", i, retvals[i]);
  }
  u32 first = retvals[0], last = retvals[nel-1];
  if (last>first) {
    double avg = (last-first)/((double) (nel));
    printf("average interval: %.1f = %.1f ns\n", avg, avg*10.0);
  }
  assert(sizeof(u32)==4);
}

void foobar1(void)
{
  u16 retvals[16384];
  int i = 0, nel = NEL(retvals);
  int diff = 0;
  for (i = 0; i<nel; i++)
    retvals[i] = busrd(0x0005);
  double totdiff = 0.0;
  for (i = 0; i<nel; i++) {
    // if (i%128!=0 && i+1!=NEL(retvals)) continue;
    printf("%d %x\n", i, retvals[i]);
    if (i>0) {
      diff = (retvals[i]-retvals[i-1]) & 0xffff;
      totdiff += diff;
    }
  }
  double avg = totdiff/((double) (nel-1));
  printf("average interval: %.1f = %.1f ns\n", avg, avg*10.0);
  assert(sizeof(u16)==2);
}

void foobar2(void)
{
  u16 retvals[16384];
  int i = 0, nel = NEL(retvals);
  int diff = 0;
  for (i = 0; i<nel; i++)
    retvals[i] = a7rd(0x0005);
  double totdiff = 0.0;
  for (i = 0; i<nel; i++) {
    // if (i%128!=0 && i+1!=NEL(retvals)) continue;
    printf("%d %x\n", i, retvals[i]);
    if (i>0) {
      diff = (retvals[i]-retvals[i-1]) & 0xffff;
      totdiff += diff;
    }
  }
  double avg = totdiff/((double) (nel-1));
  printf("average interval: %.1f = %.1f ns\n", avg, avg*10.0);
  assert(sizeof(u16)==2);
}

