`timescale 1ns/1ps

module fir_accelerator #(
    parameter TAPS = 8
)(
    input  wire         clk,
    input  wire         reset,

    // Control
    input  wire         start,
    output reg          busy,
    output reg          done,

    // Sample and coefficient write interface
    input  wire         sample_we,
    input  wire         coeff_we,
    input  wire [2:0]   data_index,
    input  wire signed [15:0] data_in,

    // Result
    output reg signed [39:0] result
);

    // ------------------------------------------------------------
    // Storage
    // ------------------------------------------------------------

    reg signed [15:0] samples [0:TAPS-1];
    reg signed [15:0] coeffs  [0:TAPS-1];

    // ------------------------------------------------------------
    // MAC state
    // ------------------------------------------------------------

    reg [3:0] tap_index;

    reg signed [31:0] product;
    reg signed [39:0] accumulator;

    localparam IDLE = 2'd0;
    localparam MAC  = 2'd1;
    localparam DONE = 2'd2;

    reg [1:0] state;

    integer i;

    // ------------------------------------------------------------
    // Sequential logic
    // ------------------------------------------------------------

    always @(posedge clk) begin

        if (reset) begin

            busy       <= 1'b0;
            done       <= 1'b0;
            result     <= 40'sd0;
            tap_index  <= 4'd0;
            product    <= 32'sd0;
            accumulator <= 40'sd0;
            state      <= IDLE;

            for (i = 0; i < TAPS; i = i + 1) begin
                samples[i] <= 16'sd0;
                coeffs[i]  <= 16'sd0;
            end

        end else begin

            // ----------------------------------------------------
            // Load sample
            // ----------------------------------------------------

            if (sample_we && !busy) begin
                samples[data_index] <= data_in;
            end

            // ----------------------------------------------------
            // Load coefficient
            // ----------------------------------------------------

            if (coeff_we && !busy) begin
                coeffs[data_index] <= data_in;
            end

            // DONE is a one-cycle pulse
            done <= 1'b0;

            // ----------------------------------------------------
            // State machine
            // ----------------------------------------------------

            case (state)

                // ------------------------------------------------
                // IDLE
                // ------------------------------------------------

                IDLE: begin

                    busy <= 1'b0;

                    if (start) begin

                        busy        <= 1'b1;
                        tap_index   <= 4'd0;
                        accumulator <= 40'sd0;

                        state <= MAC;

                    end

                end

                // ------------------------------------------------
                // MAC
                // ------------------------------------------------

                MAC: begin

                    busy <= 1'b1;

                    // Signed 16 x Signed 16 = Signed 32
                    product <= samples[tap_index] *
                               coeffs[tap_index];

                    // Accumulate the current product
                    accumulator <= accumulator +
                                   (samples[tap_index] *
                                    coeffs[tap_index]);

                    if (tap_index == TAPS-1) begin

                        // Final result
                        result <= accumulator +
                                  (samples[tap_index] *
                                   coeffs[tap_index]);

                        state <= DONE;

                    end else begin

                        tap_index <= tap_index + 1'b1;

                    end

                end

                // ------------------------------------------------
                // DONE
                // ------------------------------------------------

                DONE: begin

                    busy <= 1'b0;
                    done <= 1'b1;

                    state <= IDLE;

                end

                default: begin

                    state <= IDLE;
                    busy  <= 1'b0;
                    done  <= 1'b0;

                end

            endcase

        end

    end

endmodule