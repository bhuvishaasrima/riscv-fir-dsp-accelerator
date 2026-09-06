`timescale 1ns/1ps

module tb_fir_accelerator;

    reg clk;
    reg reset;

    reg start;

    reg sample_we;
    reg coeff_we;
    reg [2:0] data_index;

    reg signed [15:0] data_in;

    wire busy;
    wire done;

    wire signed [39:0] result;

    // ------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------

    fir_accelerator dut (
        .clk(clk),
        .reset(reset),

        .start(start),
        .busy(busy),
        .done(done),

        .sample_we(sample_we),
        .coeff_we(coeff_we),
        .data_index(data_index),
        .data_in(data_in),

        .result(result)
    );

    // ------------------------------------------------------------
    // Clock: 10 ns period
    // ------------------------------------------------------------

    always #5 clk = ~clk;

    // ------------------------------------------------------------
    // Test
    // ------------------------------------------------------------

    integer i;

    initial begin

        clk = 0;

        reset = 1;
        start = 0;

        sample_we = 0;
        coeff_we = 0;

        data_index = 0;
        data_in = 0;

        #20;

        reset = 0;

        // --------------------------------------------------------
        // Samples
        //
        // [1,2,3,4,5,6,7,8]
        // --------------------------------------------------------

        for (i = 0; i < 8; i = i + 1) begin

            @(negedge clk);

            sample_we = 1;
            data_index = i[2:0];
            data_in = i + 1;

            @(negedge clk);

            sample_we = 0;

        end

        // --------------------------------------------------------
        // Coefficients
        //
        // [1,1,1,1,1,1,1,1]
        // --------------------------------------------------------

        for (i = 0; i < 8; i = i + 1) begin

            @(negedge clk);

            coeff_we = 1;
            data_index = i[2:0];
            data_in = 16'sd1;

            @(negedge clk);

            coeff_we = 0;

        end

        // --------------------------------------------------------
        // Start accelerator
        // --------------------------------------------------------

        @(negedge clk);

        start = 1;

        @(negedge clk);

        start = 0;

        // Wait for completion

        wait(done);

        #1;

        $display("----------------------------------------");
        $display("FIR ACCELERATOR TEST");
        $display("----------------------------------------");

        $display("Expected result = 36");
        $display("RTL result      = %0d", result);

        if (result == 40'sd36)
            $display("PASS");
        else
            $display("FAIL");

        $display("----------------------------------------");

        #20;

        $finish;

    end

endmodule