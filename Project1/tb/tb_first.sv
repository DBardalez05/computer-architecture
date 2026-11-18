`timescale 1ns/1ns
`include "top.sv"

// First test: three instructions (addi, addi, add), then HALT.

module tb_first;

    logic clk = 0;
    logic LED, RGB_R, RGB_G, RGB_B;

    int errors = 0;
    int cycles = 0;

    top #(
        .IMEM_FILE ("programs/hex/test_first")
    ) u0 (
        .clk    (clk),
        .LED    (LED),
        .RGB_R  (RGB_R),
        .RGB_G  (RGB_G),
        .RGB_B  (RGB_B)
    );

    // About 12 MHz
    always #42 clk = ~clk;

    always @(posedge clk) begin
        cycles = cycles + 1;
        if (u0.alu_out_write_enable)
            $display("pc = %h  instruction = %h", u0.pc, u0.instruction);
    end

    task check(input int r, input logic [31:0] expected);
        if (u0.dp.rf.regs[r] === expected)
            $display("PASS  x%0d = %h", r, u0.dp.rf.regs[r]);
        else begin
            $display("FAIL  x%0d = %h (expected %h)", r, u0.dp.rf.regs[r], expected);
            errors = errors + 1;
        end
    endtask

    initial begin
        $dumpfile("results/waveforms/tb_first.vcd");
        $dumpvars(0, tb_first);

        wait (u0.halted == 1'b1);
        @(negedge clk);
        $display("CPU halted at pc = %h after %0d cycles", u0.pc, cycles);

        if (u0.pc !== 32'h100c) begin
            $display("FAIL  halted at the wrong address (expected 0000100c)");
            errors = errors + 1;
        end

        check(1, 32'd5);
        check(2, 32'd7);
        check(3, 32'd12);

        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d TESTS FAILED", errors);
        $finish;
    end

    // Stop if the CPU never reaches HALT
    initial begin
        repeat (5000) @(posedge clk);
        $display("TIMEOUT: CPU never reached HALT");
        $finish;
    end

endmodule
