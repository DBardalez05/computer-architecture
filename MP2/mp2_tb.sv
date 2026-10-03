`timescale 1ns/1ps

module mp2_tb;

    logic clk = 0;

    logic RGB_R;
    logic RGB_G;
    logic RGB_B;

    // Connect the testbench to our design.
    top dut (
        .clk   (clk),
        .RGB_R (RGB_R),
        .RGB_G (RGB_G),
        .RGB_B (RGB_B)
    );

    // Create a simulated 12 MHz clock.
    //
    // One 12 MHz period is approximately 83.333 ns.
    // The clock switches every half-period.
    always #41.667 clk = ~clk;

    initial begin

        // Save the simulation results.
        $dumpfile("mp2.vcd");

        // Only record the signals needed for the graph.
        // Avoid recording clk and the PWM outputs because they
        // switch millions of times and would make a huge VCD file.
        $dumpvars(
            0,
            dut.red_value,
            dut.green_value,
            dut.blue_value,
            dut.color,
            dut.fade_value
        );

        // One complete cycle is 12,000,000 clock edges.
        // Run slightly longer so we can see it return to red.
        repeat (12_010_000) @(posedge clk);

        $finish;
    end

endmodule