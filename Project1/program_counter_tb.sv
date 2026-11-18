`timescale 1ns/1ps

module program_counter_tb;

    logic clk;
    logic reset;
    logic pc_write_enable;
    logic [31:0] next_pc;
    logic [31:0] pc;

    // For this testbench we must generate a clock
    // First tart the clock at 0
    initial clk = 1'b0;

    // Then flip the clock every 5 nanoseconds
    always #5 clk = ~clk;

    program_counter dut (
    .clk(clk),
    .reset(reset),
    .pc_write_enable(pc_write_enable),
    .next_pc(next_pc),
    .pc(pc)
    );

    initial begin
        // First test we doing is when the PC value should reset
        reset = 1'b1;
        pc_write_enable = 1'b0;
        next_pc = 32'h00002000;

        @(posedge clk);
        #1;

        $display("PC after reset = %h", pc);

        // Second test is when the PC should hold its value
        reset = 1'b0;
        pc_write_enable = 1'b0;
        next_pc = 32'h00001004;

        @(posedge clk);
        #1;

        $display("PC after hold = %h", pc);

        // Third test is when the PC should update when enabled
        reset = 1'b0;
        pc_write_enable = 1'b1;
        next_pc = 32'h00001004;

        @(posedge clk);
        #1;

        $display("PC after update = %h", pc);

        $finish;
    end

endmodule