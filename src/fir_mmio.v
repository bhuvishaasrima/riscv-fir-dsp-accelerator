`timescale 1ns/1ps

module fir_mmio (
    input  wire        clk,
    input  wire        reset,

    // PicoRV32-style local peripheral bus
    input  wire        sel,
    input  wire        mem_valid,
    input  wire        mem_write,
    input  wire [31:0] mem_addr,
    input  wire [31:0] mem_wdata,
    input  wire [3:0]  mem_wstrb,

    output reg         mem_ready,
    output reg [31:0]  mem_rdata
);

    // ------------------------------------------------------------
    // Address map
    // ------------------------------------------------------------

    localparam ADDR_CONTROL = 32'h80000040;
    localparam ADDR_STATUS  = 32'h80000044;
    localparam ADDR_RESULT  = 32'h80000048;

    localparam ADDR_SAMPLE0 = 32'h80000050;
    localparam ADDR_COEFF0  = 32'h80000070;

    // ------------------------------------------------------------
    // FIR control signals
    // ------------------------------------------------------------

    reg start;

    reg sample_we;
    reg coeff_we;

    reg [2:0] data_index;

    reg signed [15:0] data_in;

    wire busy;
    wire done;

    wire signed [39:0] fir_result;

    // ------------------------------------------------------------
    // FIR accelerator
    // ------------------------------------------------------------

    fir_accelerator fir_core (
        .clk(clk),
        .reset(reset),

        .start(start),
        .busy(busy),
        .done(done),

        .sample_we(sample_we),
        .coeff_we(coeff_we),
        .data_index(data_index),
        .data_in(data_in),

        .result(fir_result)
    );

    // ------------------------------------------------------------
    // Bus logic
    // ------------------------------------------------------------

    always @(posedge clk) begin

        if (reset) begin

            mem_ready <= 1'b0;
            mem_rdata <= 32'd0;

            start     <= 1'b0;
            sample_we <= 1'b0;
            coeff_we  <= 1'b0;

            data_index <= 3'd0;
            data_in    <= 16'sd0;

        end else begin

            // Default: one-cycle pulses
            mem_ready <= 1'b0;
            start     <= 1'b0;
            sample_we <= 1'b0;
            coeff_we  <= 1'b0;

            // ----------------------------------------------------
            // Handle bus transaction
            // ----------------------------------------------------

            if (sel && mem_valid) begin

                mem_ready <= 1'b1;

                // ------------------------------------------------
                // WRITE
                // ------------------------------------------------

                if (mem_write) begin

                    // START register
                    if (mem_addr == ADDR_CONTROL) begin

                        if (mem_wstrb[0] && mem_wdata[0]) begin
                            start <= 1'b1;
                        end

                    end

                    // SAMPLE registers
                    else if ((mem_addr >= ADDR_SAMPLE0) &&
                             (mem_addr < ADDR_COEFF0)) begin

                        data_index <= (mem_addr - ADDR_SAMPLE0) >> 2;
                        data_in    <= mem_wdata[15:0];

                        sample_we <= 1'b1;

                    end

                    // COEFFICIENT registers
                    else if ((mem_addr >= ADDR_COEFF0) &&
                             (mem_addr < 32'h80000090)) begin

                        data_index <= (mem_addr - ADDR_COEFF0) >> 2;
                        data_in    <= mem_wdata[15:0];

                        coeff_we <= 1'b1;

                    end

                end

                // ------------------------------------------------
                // READ
                // ------------------------------------------------

                else begin

                    case (mem_addr)

                        ADDR_CONTROL: begin
                            mem_rdata <= 32'd0;
                        end

                        ADDR_STATUS: begin
                            mem_rdata <= {
                                30'd0,
                                done,
                                busy
                            };
                        end

                        ADDR_RESULT: begin
                            mem_rdata <= fir_result[31:0];
                        end

                        default: begin
                            mem_rdata <= 32'd0;
                        end

                    endcase

                end

            end

        end

    end

endmodule