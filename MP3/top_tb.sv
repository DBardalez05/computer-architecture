`timescale 1ns/1ps
`include "top.sv"

module top_tb;

    logic clk;
    logic _48b;
    logic _45a;

    top dut(.clk(clk), ._48b(_48b), ._45a(_45a));

    initial begin
        clk = 1'b0;
    end
    always #5 clk = ~clk;

    initial begin
        $dumpfile("top.vcd");
        $dumpvars(0, top_tb);
        #1;

        // Check that pixel 60 starts alive in red and green with our current starting grid
        // Use fprce in order to selected the needed pixel instead of waiting for the controller to reach it
        force dut.pixel = 6'd60;
        #1;

        if (dut.red_data === 8'd64 && dut.green_data === 8'd64 && dut.blue_data === 8'd0)
            $display("Pixel 60 is yellos as intended :)");
        else
            $error("Pizel 60 should be yellow, it is not :(");

        // Another random pixel we will test is pizel 3 whichshould start as green and blue
        force dut.pixel = 6'd3;
        #1;

        if (dut.red_data === 8'd0 && dut.green_data === 8'd64 && dut.blue_data === 8'd64)
            $display("Pixel 3 is cyan as intended :)");
        else
            $error("Pizel 3 should be cyan, it is not :(");

        // Lastly we will check pixel 41 which should start as red and blue
        force dut.pixel = 6'd41;
        #1;

        if (dut.red_data === 8'd64 && dut.green_data === 8'd0 && dut.blue_data === 8'd64)
            $display("Pixel 41 is magenta as intended :)");
        else
            $error("Pizel 41 should be magenta, it is not :(");

        // Check if the generation tick variable correctly updates on change of frame 31 to frame 0
        force dut.frame = 5'd31;
        @(posedge clk);
        #1;

        force dut.frame = 5'd0;
        #1;

        if (dut.generation_tick == 1'b1)
            $display("generation_tick turn on successfully :)");
        else
            $error("generation_tick did not turn on :(");

        // Now check if generation_tick returns to 0
        @(posedge clk);
        #1;

        if (dut.generation_tick == 1'b0)
            $display("generation_tick turned off successfully :)");
        else
            $error("generation_tick stayed on too long :(");
        
        $display("Top testbench finished!");
        $finish;
    end
endmodule

