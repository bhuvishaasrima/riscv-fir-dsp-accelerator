/* Copyright 2024 Grug Huhler.  License SPDX BSD-2-Clause. */
/*
Top level module of simple SoC based on picorv32.

Includes:
     * picorv32 core
     * SRAM
     * LEDs
     * UART
     * Countdown timer
     * WS2812B
     * Custom 8-tap FIR DSP accelerator

The FIR accelerator is memory mapped at:

     0x80000040  CONTROL
     0x80000044  STATUS
     0x80000048  RESULT

     0x80000050 - 0x8000006C  SAMPLES
     0x80000070 - 0x8000008C  COEFFICIENTS
*/

// Define this for logic analyzer connections and enable picorv32_la.cst.
//`define USE_LA

module top (
            input wire        clk,
            input wire        reset_button,
            input wire        uart_rx,
            output wire       uart_tx,
            output wire       ws2812b_din,
`ifdef USE_LA
            output wire       clk_out,
            output wire       mem_instr,
            output wire       mem_valid,
            output wire       mem_ready,
            output wire       b25,
            output wire       b24,
            output wire       b17,
            output wire       b16,
            output wire       b09,
            output wire       b08,
            output wire       b01,
            output wire       b00,
            output wire [3:0] mem_wstrb,
`endif
            output wire [5:0] leds
            );

   // Software-generated system parameters
   `include "sys_parameters.v"

   parameter BARREL_SHIFTER = 0;
   parameter ENABLE_MUL = 0;
   parameter ENABLE_DIV = 0;
   parameter ENABLE_FAST_MUL = 0;
   parameter ENABLE_COMPRESSED = 0;
   parameter ENABLE_IRQ_QREGS = 0;

   parameter MEMBYTES = 4*(1 << SRAM_ADDR_WIDTH);
   parameter [31:0] STACKADDR = (MEMBYTES);
   parameter [31:0] PROGADDR_RESET = 32'h0000_0000;
   parameter [31:0] PROGADDR_IRQ = 32'h0000_0000;

   // ------------------------------------------------------------
   // PicoRV32 memory bus
   // ------------------------------------------------------------

   wire                       reset_n;

   wire                       mem_valid;
   wire                       mem_instr;
   wire [31:0]                mem_addr;
   wire [31:0]                mem_wdata;
   wire [31:0]                mem_rdata;
   wire [3:0]                 mem_wstrb;
   wire                       mem_ready;

   // ------------------------------------------------------------
   // Existing peripheral signals
   // ------------------------------------------------------------

   wire                       leds_sel;
   wire                       leds_ready;
   wire [31:0]                leds_data_o;

   wire                       sram_sel;
   wire                       sram_ready;
   wire [31:0]                sram_data_o;

   wire                       cdt_sel;
   wire                       cdt_ready;
   wire [31:0]                cdt_data_o;

   wire                       uart_sel;
   wire [31:0]                uart_data_o;
   wire                       uart_ready;

   wire                       ws2812b_sel;
   wire                       ws2812b_ready;

   // ------------------------------------------------------------
   // FIR accelerator signals
   // ------------------------------------------------------------

   wire                       fir_sel;
   wire                       fir_ready;
   wire [31:0]                 fir_data_o;

   wire                       fir_mem_write;

   // A PicoRV32 write transaction has one or more active byte
   // strobes.
   assign fir_mem_write = |mem_wstrb;

`ifdef USE_LA
   // ------------------------------------------------------------
   // Logic analyzer connections
   // ------------------------------------------------------------

   assign clk_out = clk;

   assign b25 = mem_rdata[25];
   assign b24 = mem_rdata[24];
   assign b17 = mem_rdata[17];
   assign b16 = mem_rdata[16];
   assign b09 = mem_rdata[9];
   assign b08 = mem_rdata[8];
   assign b01 = mem_rdata[1];
   assign b00 = mem_rdata[0];
`endif

   // ------------------------------------------------------------
   // Memory map
   // ------------------------------------------------------------
   //
   // SRAM      00000000 - 00000FFF
   // LED       80000000
   // UART      80000008 - 8000000F
   // CDT       80000010
   // WS2812B   80000020
   //
   // FIR:
   // CONTROL   80000040
   // STATUS    80000044
   // RESULT    80000048
   // SAMPLES   80000050 - 8000006C
   // COEFFS    80000070 - 8000008C
   // ------------------------------------------------------------

   assign sram_sel =
       mem_valid &&
       (mem_addr < MEMBYTES);

   assign leds_sel =
       mem_valid &&
       (mem_addr == 32'h80000000);

   assign uart_sel =
       mem_valid &&
       ((mem_addr & 32'hfffffff8) == 32'h80000008);

   assign cdt_sel =
       mem_valid &&
       (mem_addr == 32'h80000010);

   assign ws2812b_sel =
       mem_valid &&
       (mem_addr == 32'h80000020);

   // FIR occupies 0x80000040 - 0x8000008F.
   assign fir_sel =
       mem_valid &&
       (mem_addr >= 32'h80000040) &&
       (mem_addr <  32'h80000090);

   // ------------------------------------------------------------
   // CPU ready
   // ------------------------------------------------------------

   assign mem_ready =
       mem_valid &
       (
          sram_ready     |
          leds_ready     |
          uart_ready     |
          cdt_ready      |
          ws2812b_ready  |
          fir_ready
       );

   // ------------------------------------------------------------
   // Read-data multiplexer
   // ------------------------------------------------------------

   assign mem_rdata =
       sram_sel    ? sram_data_o :
       leds_sel    ? leds_data_o :
       uart_sel    ? uart_data_o :
       cdt_sel     ? cdt_data_o :
       fir_sel     ? fir_data_o :
                     32'h00000000;

   // LEDs are active-low on the Tang Nano.
   assign leds = ~leds_data_o[5:0];

   // ------------------------------------------------------------
   // Reset controller
   // ------------------------------------------------------------

   reset_control reset_controller
     (
      .clk(clk),
      .reset_button(reset_button),
      .reset_n(reset_n)
      );

   // ------------------------------------------------------------
   // UART
   // ------------------------------------------------------------

   uart_wrap uart
     (
      .clk(clk),
      .reset_n(reset_n),
      .uart_tx(uart_tx),
      .uart_rx(uart_rx),
      .uart_sel(uart_sel),
      .addr(mem_addr[3:0]),
      .uart_wstrb(mem_wstrb),
      .uart_di(mem_wdata),
      .uart_do(uart_data_o),
      .uart_ready(uart_ready)
      );

   // ------------------------------------------------------------
   // Countdown timer
   // ------------------------------------------------------------

   countdown_timer cdt
     (
      .clk(clk),
      .reset_n(reset_n),
      .cdt_sel(cdt_sel),
      .cdt_data_i(mem_wdata),
      .we(mem_wstrb),
      .cdt_ready(cdt_ready),
      .cdt_data_o(cdt_data_o)
      );

   // ------------------------------------------------------------
   // WS2812B
   // ------------------------------------------------------------

   ws2812b_tgt #(.CLK_FREQ(CLK_FREQ)) ws2812b_led
     (
      .clk(clk),
      .reset_n(reset_n),
      .ws2812b_sel(ws2812b_sel),
      .we(&mem_wstrb),
      .wdata({mem_wdata[15:8],
              mem_wdata[23:16],
              mem_wdata[7:0]}),
      .ws2812b_ready(ws2812b_ready),
      .to_din(ws2812b_din)
      );

   // ------------------------------------------------------------
   // SRAM
   // ------------------------------------------------------------

   sram #(.SRAM_ADDR_WIDTH(SRAM_ADDR_WIDTH)) memory
     (
      .clk(clk),
      .reset_n(reset_n),
      .sram_sel(sram_sel),
      .wstrb(mem_wstrb),
      .addr(mem_addr[SRAM_ADDR_WIDTH + 1:0]),
      .sram_data_i(mem_wdata),
      .sram_ready(sram_ready),
      .sram_data_o(sram_data_o)
      );

   // ------------------------------------------------------------
   // LEDs
   // ------------------------------------------------------------

   tang_leds soc_leds
     (
      .clk(clk),
      .reset_n(reset_n),
      .leds_sel(leds_sel),
      .leds_data_i(mem_wdata[5:0]),
      .we(mem_wstrb[0]),
      .leds_ready(leds_ready),
      .leds_data_o(leds_data_o)
      );

   // ------------------------------------------------------------
   // CUSTOM FIR DSP ACCELERATOR
   // ------------------------------------------------------------

   fir_mmio fir_dsp
     (
      .clk(clk),

      // fir_mmio expects active-high reset.
      .reset(~reset_n),

      .sel(fir_sel),
      .mem_valid(mem_valid),
      .mem_write(fir_mem_write),
      .mem_addr(mem_addr),
      .mem_wdata(mem_wdata),
      .mem_wstrb(mem_wstrb),

      .mem_ready(fir_ready),
      .mem_rdata(fir_data_o)
      );

   // ------------------------------------------------------------
   // PicoRV32 CPU
   // ------------------------------------------------------------

   picorv32
     #(
       .STACKADDR(STACKADDR),
       .PROGADDR_RESET(PROGADDR_RESET),
       .PROGADDR_IRQ(PROGADDR_IRQ),
       .BARREL_SHIFTER(BARREL_SHIFTER),
       .COMPRESSED_ISA(ENABLE_COMPRESSED),
       .ENABLE_MUL(ENABLE_MUL),
       .ENABLE_DIV(ENABLE_DIV),
       .ENABLE_FAST_MUL(ENABLE_FAST_MUL),
       .ENABLE_IRQ(1),
       .ENABLE_IRQ_QREGS(ENABLE_IRQ_QREGS)
       )
   cpu
     (
      .clk         (clk),
      .resetn      (reset_n),

      .mem_valid   (mem_valid),
      .mem_instr   (mem_instr),
      .mem_ready   (mem_ready),
      .mem_addr    (mem_addr),
      .mem_wdata   (mem_wdata),
      .mem_wstrb   (mem_wstrb),
      .mem_rdata   (mem_rdata),

      .irq         ('b0)
      );

endmodule