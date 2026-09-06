`timescale 1ns/1ps

module tb_fir_mmio;

    reg clk;
    reg reset;

    reg        sel;
    reg        mem_valid;
    reg        mem_write;
    reg [31:0] mem_addr;
    reg [31:0] mem_wdata;
    reg [3:0]  mem_wstrb;

    wire        mem_ready;
    wire [31:0] mem_rdata;

    fir_mmio dut (
        .clk(clk),
        .reset(reset),

        .sel(sel),
        .mem_valid(mem_valid),
        .mem_write(mem_write),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),

        .mem_ready(mem_ready),
        .mem_rdata(mem_rdata)
    );

    always #5 clk = ~clk;

    task write_reg;
        input [31:0] address;
        input [31:0] value;

        begin

            @(negedge clk);

            sel        = 1'b1;
            mem_valid  = 1'b1;
            mem_write  = 1'b1;
            mem_addr   = address;
            mem_wdata  = value;
            mem_wstrb  = 4'b1111;

            @(negedge clk);

            sel        = 1'b0;
            mem_valid  = 1'b0;
            mem_write  = 1'b0;
            mem_addr   = 32'd0;
            mem_wdata  = 32'd0;
            mem_wstrb  = 4'd0;

        end
    endtask

    task read_reg;
        input [31:0] address;

        begin

            @(negedge clk);

            sel        = 1'b1;
            mem_valid  = 1'b1;
            mem_write  = 1'b0;
            mem_addr   = address;
            mem_wstrb  = 4'd0;

            @(posedge clk);

            #1;

            $display(
                "READ 0x%08h = 0x%08h",
                address,
                mem_rdata
            );

            @(negedge clk);

            sel       = 1'b0;
            mem_valid = 1'b0;

        end
    endtask

    integer i;

    initial begin

        clk = 0;

        reset = 1;

        sel        = 0;
        mem_valid  = 0;
        mem_write  = 0;
        mem_addr   = 0;
        mem_wdata  = 0;
        mem_wstrb  = 0;

        #20;

        reset = 0;

        // --------------------------------------------------------
        // samples = [1 2 3 4 5 6 7 8]
        // coefficients = [1 1 1 1 1 1 1 1]
        // expected = 36
        // --------------------------------------------------------

        for (i = 0; i < 8; i = i + 1) begin

            write_reg(
                32'h80000050 + (i * 4),
                i + 1
            );

            write_reg(
                32'h80000070 + (i * 4),
                1
            );

        end

        // START

        write_reg(
            32'h80000040,
            32'h00000001
        );

        // Wait until DONE

        wait (dut.done);

        #1;

        read_reg(32'h80000044);
        read_reg(32'h80000048);

        $display("----------------------------------------");
        $display("MMIO FIR TEST");
        $display("Expected RESULT = 36");
        $display("Actual RESULT   = %0d", $signed(dut.fir_result));

        if (dut.fir_result == 40'sd36)
            $display("PASS");
        else
            $display("FAIL");

        $display("----------------------------------------");

        #20;

        $finish;

    end

endmodule