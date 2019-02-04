
export PATH := /opt/Xilinx/SDK/2016.4/gnu/arm/lin/bin:$(PATH)
CC=arm-xilinx-linux-gnueabi-gcc
LD=arm-xilinx-linux-gnueabi-ld
CFLAGS=-std=c99

all : dma_recv.elf util1.elf server.elf

util1.elf : util1.c busio.c peek_poke.c dumb_gpio.c
	$(CC) $(CFLAGS) util1.c busio.c peek_poke.c dumb_gpio.c -o $@
	cp -p $@ /export/uzed/

dma_recv.elf : dma_recv.c
	$(CC) $(CFLAGS) dma_recv.c -o $@
	cp -p $@ /export/uzed/

server.elf : server.c busio.c
	$(CC) $(CFLAGS) server.c busio.c -o $@
	cp -p $@ /export/uzed/

