/*
 * peek_poke.c
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

typedef unsigned long u32;

int peek_poke(int argc, char **argv)
{
  int i = 0, rc = 0;
  int poke = 0;
  if (0) {
    printf("peek_poke:");
    for (i = 0; i<argc; i++) printf(" %s", argv[i]);
    printf("\n");
  }

  assert(argc>1);   // need command + at least 1 argument
  u32 addr = 0, pval = 0;
  rc = sscanf(argv[1], "%x", &addr);
  assert(rc==1);
  if (!strcmp(argv[0], "peek")) {
    poke = 0;
  } else if (!strcmp(argv[0], "poke")) {
    poke = 1;
    assert(argc>2);  // need at least 2 arguments after command
    rc = sscanf(argv[2], "%x", &pval);
    assert(rc==1);
  } else {
    fprintf(stderr, "peek_poke: unknown command '%s'\n", argv[0]);
    return 1;
  }

  // Xilinx uses u32, while mmap uses size_t
  assert(sizeof(u32)==sizeof(size_t));

  // It seems that mmap wants base address to lie on a page boundary
  u32 base = addr & 0xfffff000;
  u32 offs = addr & 0x00000fff;

  // Map 4096 bytes (which is presumably a page or power-of-two pages)
  u32 mlen =        0x00001000;

  // Use iofs as array index into array whose stride is sizeof(u32)
  int iofs = offs / sizeof(u32);

  int memfd = 0;
  void *mapped_base = 0;
  memfd = open("/dev/mem", O_RDWR | O_SYNC);
  assert(memfd != -1);
  if (0) printf("/dev/mem opened.\n");

  mapped_base = mmap(0, mlen,
		     PROT_READ|PROT_WRITE, MAP_SHARED,
		     memfd, base);
  assert(mapped_base != MAP_FAILED);
  if (0) printf("memory mapped\n");

  size_t *p = (size_t *) mapped_base;
  printf("peek: mem[%x] == %x\n", addr, p[iofs]);
  if (poke) {
    printf("poke: writing mem[%x] := %x\n", addr, pval);
    p[iofs] = pval;
  }
  printf("peek: mem[%x] == %x\n", addr, p[iofs]);
  return 0;
}
