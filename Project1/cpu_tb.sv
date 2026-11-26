`timescale 1ns/1ps

module cpu_tb;

    logic clk;
    logic reset;

    // Generate the clock
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Connect our CPU
    cpu dut (
        .clk(clk),
        .reset(reset)
    );

    initial begin
        // Reset the CPU
        reset = 1'b1;
        repeat (2) @(posedge clk);
        #1;
        reset = 1'b0;

        // Execute the first instruction
        repeat (5) @(posedge clk);
        #1;
        $display("x1 = %d", dut.dp_module.rf.regs[1]);

        // Execute the second instruction
        repeat (5) @(posedge clk);
        #1;
        $display("x2 = %d", dut.dp_module.rf.regs[2]);

        // Execute the third instruction
        repeat (5) @(posedge clk);
        #1;
        $display("x3 = %d", dut.dp_module.rf.regs[3]);

        $display("Final PC = %h", dut.pc);

        $finish;
    end

endmodule