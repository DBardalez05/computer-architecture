`timescale 1ns/1ns
`include "top.sv"

// Runs the real LED program (led_blink) and checks that it writes the six
// colors in order, 200 ms apart, and then starts over with red.
//
// To keep the simulation short the clock is 2 MHz instead of 12 MHz. We pass
// the same CLK_FREQ to the memory, so its millisecond timer is still correct.

module tb_led;

    localparam CLK_FREQ = 2000000;

    logic clk = 0;
    logic LED, RGB_R, RGB_G, RGB_B;

    // LED register = { user LED, red, green, blue }, one byte each
    logic [31:0] expected [0:6];
    int count = 0;
    logic [31:0] last_millis;
    logic [31:0] elapsed;

    top #(
        .IMEM_FILE  ("programs/hex/led_blink"),
        .CLK_FREQ   (CLK_FREQ)
    ) u0 (
        .clk    (clk),
        .LED    (LED),
        .RGB_R  (RGB_R),
        .RGB_G  (RGB_G),
        .RGB_B  (RGB_B)
    );

    // 2 MHz
    always #250 clk = ~clk;

    initial begin
        expected[0] = 32'h00FF0000;     // red,     user LED off
        expected[1] = 32'hFFFFFF00;     // yellow,  user LED on
        expected[2] = 32'h0000FF00;     // green,   user LED off
        expected[3] = 32'hFF00FFFF;     // cyan,    user LED on
        expected[4] = 32'h000000FF;     // blue,    user LED off
        expected[5] = 32'hFFFF00FF;     // magenta, user LED on
        expected[6] = 32'h00FF0000;     // red again

        $dumpfile("results/waveforms/tb_led.vcd");
        $dumpvars(0, u0.mem.leds, u0.mem.millis, LED, RGB_R, RGB_G, RGB_B);

        // Start the millisecond timer 100 ms before it wraps around to 0,
        // so the first delay also tests the wraparound.
        @(negedge clk);
        u0.mem.millis = 32'hFFFFFF9C;
    end

    // Every time the CPU stores to the LED register (0xFFFFFFFC)
    always @(posedge clk) begin
        if (u0.dmem_wren && u0.dmem_address == 32'hFFFFFFFC) begin
            if (u0.dmem_data_in !== expected[count]) begin
                $display("FAIL  color %0d: wrote %h, expected %h", count, u0.dmem_data_in, expected[count]);
                $finish;
            end

            if (count == 0)
                $display("PASS  color 0 = %h  millis = %h", u0.dmem_data_in, u0.mem.millis);
            else begin
                elapsed = u0.mem.millis - last_millis;
                if (elapsed < 200 || elapsed > 201) begin
                    $display("FAIL  color %0d came after %0d ms, expected 200 ms", count, elapsed);
                    $finish;
                end
                $display("PASS  color %0d = %h  millis = %h  (%0d ms later)", count, u0.dmem_data_in, u0.mem.millis, elapsed);
            end

            last_millis = u0.mem.millis;
            count = count + 1;

            if (count == 7) begin
                $display("ALL TESTS PASSED");
                $finish;
            end
        end
    end

    // 6 delays of 200 ms at 2 MHz is 2.4 million cycles
    initial begin
        repeat (2600000) @(posedge clk);
        $display("TIMEOUT: the LED program did not finish one color cycle");
        $finish;
    end

endmodule
