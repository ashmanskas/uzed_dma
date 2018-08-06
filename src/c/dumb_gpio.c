/*
 * dumb_gpio.c
 * First (summer 2014) attempt to R/W custom AXI GPIO peripheral from Linux
 * wja 2014-07-18 - begun as linux_user_io.c
 * wja 2014-12-17 - turned into dumb_gpio function to call from util.c
 */

#include <stdio.h>
#include <fcntl.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <assert.h>
#include <sys/mman.h>

extern int usleep(int usec);  // why isn't this in unistd.h ?!?!

// I'm not sure why I don't have this file, but it seems to live in the same
// directory as the two missing includes below.  For now I will hold my nose
// and simply define the one typedef that I need from here.
/***
#include "xil_types.h"
***/
typedef unsigned long u32;

//#include "xio.h"

// This won't work because I didn't generate these files for current project.
/***
#include "../../zynq_fsbl_0_bsp/ps7_cortexa9_0/include/myip.h"
#include "../../zynq_fsbl_0_bsp/ps7_cortexa9_0/include/xparameters.h"
***/

// Use this hack instead of the above includes
#define XPAR_MYIP_0_DEVICE_ID 0
#define XPAR_MYIP_0_S00_AXI_BASEADDR 0x43C00000
#define XPAR_MYIP_0_S00_AXI_HIGHADDR 0x43C0FFFF


int dumb_gpio(int argc, char **argv)
{
  printf("Hello world\n");
  u32 baseaddr = XPAR_MYIP_0_S00_AXI_BASEADDR;
  u32 highaddr = XPAR_MYIP_0_S00_AXI_HIGHADDR;
  u32 addrlen = (highaddr-baseaddr) + 1;

  int memfd = 0;
  void *mapped_base=0;
  off_t dev_base = baseaddr;

  memfd = open("/dev/mem", O_RDWR | O_SYNC);
  assert(memfd != -1);
  printf("/dev/mem opened.\n");

  mapped_base = mmap(0, addrlen,
		     PROT_READ|PROT_WRITE, MAP_SHARED,
		     memfd, baseaddr);
  assert(mapped_base != MAP_FAILED);
  printf("AXI peripheral memory mapped.\n");

  u32 *p = (u32 *) mapped_base;
  printf("p[0] == %lx\n", p[0]);
  printf("p[1] == %lx\n", p[1]);
  printf("p[2] == %lx\n", p[2]);

  if (argc>1) {
    u32 p1val = 0;
    int rc = sscanf(argv[1], "%lx", &p1val);
    if (rc == 1) {
      printf("writing %lx to p[1]\n", p1val);
      p[1] = p1val;
    } else {
      printf("error converting '%s' to hexadecimal\n", argv[1]);
    }
  }

  usleep(10000);
  printf("User IO Application Exiting...\n\n");
  return 0;
}
