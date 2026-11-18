`timescale 1ns/1ns
`include "top.sv"

// Runs the supplied rv32i_test program and checks the registers it leaves behind.

module proj1_tb;

    logic clk = 0;
    logic LED, RGB_R, RGB_G, RGB_B;

    int errors = 0;
    int cycles = 0;
    logic [31:0] micros_at_load;

    top #(
        .IMEM_FILE ("programs/hex/rv32i_test")
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

    // x19 loads the microsecond timer, which keeps changing. Remember what
    // the timer showed when "lw x19, -12(x0)" read it (state 4 = MEM_READ).
    always @(posedge clk) begin
        if (u0.cu.current_state == 4'd4 && u0.dmem_address == 32'hFFFFFFF4)
            micros_at_load = u0.mem.micros;
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
        $dumpfile("results/waveforms/proj1_tb.vcd");
        $dumpvars(0, proj1_tb);

        wait (u0.halted == 1'b1);
        @(negedge clk);
        $display("CPU halted at pc = %h after %0d cycles", u0.pc, cycles);

        if (u0.pc !== 32'h108c) begin
            $display("FAIL  halted at the wrong address (expected 0000108c)");
            errors = errors + 1;
        end

        check(1,  32'hFEDCBA98);
        check(2,  32'h0FEDCBA9);
        check(3,  32'hFFEDCBA9);
        check(4,  32'h00123456);
        check(5,  32'h00000002);
        check(6,  32'h00123458);
        check(7,  32'h00000002);
        check(8,  32'h0048D158);
        check(9,  32'h0048D15F);
        check(10, 32'h12346028);
        check(11, 32'h00000001);
        check(12, 32'h00000000);
        check(13, 32'h00001038);
        check(14, 32'h00001060);
        check(15, 32'h00000000);
        check(16, 32'h00001048);
        check(17, 32'h000000C0);
        check(18, 32'hC0C0C0C0);
        check(19, micros_at_load);
        check(20, 32'hFFFFC0C0);
        check(21, 32'h0000C0C0);
        check(22, 32'hFFFFFFC0);
        check(23, 32'h000000C0);

        if (u0.mem.leds === 32'hC0C0C0C0)
            $display("PASS  leds = %h", u0.mem.leds);
        else begin
            $display("FAIL  leds = %h (expected c0c0c0c0)", u0.mem.leds);
            errors = errors + 1;
        end

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
