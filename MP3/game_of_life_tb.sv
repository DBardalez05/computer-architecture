`timescale 1ns/1ps
`include "game_of_life.sv"

module game_of_life_tb;

    // Signals in the game of life file
    logic clk;
    logic update;
    logic [5:0] pixel;
    logic cell_alive;

    // Now we have to create the game of life module being tested
    game_of_life dut (.clk(clk), .update(update), .pixel(pixel), .cell_alive(cell_alive));

    initial begin
        clk = 1'b0; // Start the clock at 0
    end

    always #5 clk = ~clk;

    initial begin
        $dumpfile("game_of_life.vcd");
        $dumpvars(0, game_of_life_tb);// Save the signal changes
        
        // Initial conditions
        update = 1'b0;
        pixel = 6'b0;
        #1; 

        // Analyze the starting matrix
        // For context my most left column is 7 and right most is 0
        // iniital check is row 3 column 2-4 are alive we will check one alive and one dead
        pixel = 6'd26;
        #1;

        if (cell_alive !== 1'b1)
            $error("Matrix Frame 0: pixel (3,2) should be alive, is dead :(");
        else
            $display("Matrix Frame 0: pixel (3,2) is alive as intended!");
        
        pixel = 6'd19;
        #1;

        if (cell_alive !== 1'b0)
            $error("Matrix Frame 0: pixel (2,3) should be dead, is alive :(");
        else
            $display("Matrix Frame 0: pixel (2,3) is dead as intended!");

        // Now test the next matrix frame
        update = 1'b1;
        @(posedge clk);
        #1;
        update = 1'b0;

        // Check first row 3 column 2 as it should now be dead and then check if r2c3 is bow alive
        pixel = 6'd26;
        #1;

        if (cell_alive !== 1'b0)
            $error("Matrix Frame 0: pixel (3,2) should be dead, is alive :(");
        else
            $display("Matrix Frame 0: pixel (3,2) is dead as intended!");
        
        pixel = 6'd19;
        #1;

        if (cell_alive !== 1'b1)
            $error("Matrix Frame 0: pixel (2,3) should be alive, is dead :(");
        else
            $display("Matrix Frame 0: pixel (2,3) is alive as intended!");

        // Next matrix frame
        update = 1'b1;
        @(posedge clk);
        #1;
        update = 1'b0;

        // Check first row 3 column 2 as it should have returned to being alive and then check if r2c3 is now dead again
        pixel = 6'd26;
        #1;

        if (cell_alive !== 1'b1)
            $error("Matrix Frame 0: pixel (3,2) should be alive, is dead :(");
        else
            $display("Matrix Frame 0: pixel (3,2) is alive as intended!");
        
        pixel = 6'd19;
        #1;

        if (cell_alive !== 1'b0)
            $error("Matrix Frame 0: pixel (2,3) should be dead, is alive :(");
        else
            $display("Matrix Frame 0: pixel (2,3) is dead as intended!");
        
        $display("Game of life testbench is done!");
        $finish;
    end
endmodule