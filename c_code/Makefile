SRAM_ADDR_WIDTH=12
CLK_FREQ=20000000

COMMONFLAGS=-march=rv32i2p0 -mabi=ilp32
CFLAGS=-mno-save-restore $(COMMONFLAGS) -nostartfiles -nostdlib -static -O1
ASFLAGS=--defsym SRAM_ADDR_WIDTH=$(SRAM_ADDR_WIDTH) $(COMMONFLAGS)

CC=riscv64-unknown-elf-gcc
OBJCOPY=riscv64-unknown-elf-objcopy
OBJDUMP=riscv64-unknown-elf-objdump
AS=riscv64-unknown-elf-as

LIBGCC=C:/RISC-V/riscv64-unknown-elf-toolchain-10.2.0-2020.12.8-x86_64-w64-mingw32/lib/gcc/riscv64-unknown-elf/10.2.0/libgcc.a

all: prog.bin conv_to_init

main.o: main.c
    $(CC) $(CFLAGS) -DCLK_FREQ=$(CLK_FREQ) -c main.c

countdown_timer.o: countdown_timer.c
    $(CC) $(CFLAGS) -c countdown_timer.c

uart.o: uart.c
    $(CC) $(CFLAGS) -c uart.c

leds.o: leds.c
    $(CC) $(CFLAGS) -c leds.c

ws2812b.o: ws2812b.c
    $(CC) $(CFLAGS) -c ws2812b.c

startup.o: startup.s Makefile
    $(AS) $(ASFLAGS) -o startup.o startup.s

prog.elf: startup.o main.o countdown_timer.o uart.o leds.o ws2812b.o
    $(CC) $(CFLAGS) -Tlink_cmd.ld -o prog.elf startup.o main.o countdown_timer.o uart.o leds.o ws2812b.o $(LIBGCC)

prog.bin: prog.elf
    $(OBJCOPY) prog.elf -O binary prog.bin

conv_to_init: prog.bin conv_to_init.py
    python conv_to_init.py $(CLK_FREQ) $(SRAM_ADDR_WIDTH) prog.bin
    powershell -NoProfile -Command "New-Item -ItemType File -Force '..\src\force_rebuild.v' | Out-Null"

clean:
    -powershell -NoProfile -Command "Remove-Item -Force -ErrorAction SilentlyContinue 'prog.elf','prog.bin','main.o','countdown_timer.o','uart.o','startup.o','leds.o','ws2812b.o','..\src\mem_init0.ini','..\src\mem_init1.ini','..\src\mem_init2.ini','..\src\mem_init3.ini','..\src\sys_parameters.v'"
