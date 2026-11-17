`timescale 1ns/1ps

module control_unit_tb;

    // The inputs of the control unit
    logic clk;
    logic reset;
    logic [6:0] opcode;

    // The outputs from the control unit
    logic reg_write_enable;
    logic ir_write_enable;
    logic pc_write_enable;

    // Simulation the clock
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Connect the control unit to the testbench
    control_unit dut (
        .clk(clk),
        .reset(reset),
        .opcode(opcode),
        .reg_write_enable(reg_write_enable),
        .ir_write_enable(ir_write_enable),
        .pc_write_enable(pc_write_enable)
    );

    initial begin
        reset = 1'b1;
        opcode = 7'b0110011; // Use an r type instruction for test

        // In test 1 when reset = 1, it should put us in FETCH
        @(posedge clk);
        #1;

        $display("FETCH: reg=%b, ir=%b, pc=%b",
                reg_write_enable, ir_write_enable, pc_write_enable);

        // Test 2 is when we move to FETCH_LATCH
        reset = 1'b0;

        @(posedge clk);
        #1;

        $display("FETCH_LATCH: reg=%b, ir=%b, pc=%b",
                reg_write_enable, ir_write_enable, pc_write_enable);

        // Test 3 is when we move to DECODE
        @(posedge clk);
        #1;
        $display("DECODE: reg=%b, ir=%b, pc=%b",
                reg_write_enable, ir_write_enable, pc_write_enable);

        // Test 4 is moving to EXECUTE
        @(posedge clk);
        #1;
        $display("EXECUTE: reg=%b, ir=%b, pc=%b",
                reg_write_enable, ir_write_enable, pc_write_enable);

        // Test 5 is moving to WRITEBACK
        @(posedge clk);
        #1;
        $display("WRITEBACK: reg=%b, ir=%b, pc=%b",
                reg_write_enable, ir_write_enable, pc_write_enable);

        // Test 6 is returning to FETCH
        @(posedge clk);
        #1;
        $display("FETCH AGAIN: reg=%b, ir=%b, pc=%b",
                reg_write_enable, ir_write_enable, pc_write_enable);

        $finish;
    end

endmodule