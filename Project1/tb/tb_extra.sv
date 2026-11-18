`timescale 1ns/1ns
`include "top.sv"

// Extra test: the instructions rv32i_test does not use (and, or, xor, srl,
// sra, sw, sh, bne, bge, bgeu, fence, ...) plus a few corner cases:
// writing x0, shift amounts above 31, and jalr with rd == rs1.

module tb_extra;

    logic clk = 0;
    logic LED, RGB_R, RGB_G, RGB_B;

    int errors = 0;
    int cycles = 0;

    top #(
        .IMEM_FILE ("programs/hex/test_extra")
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
        $dumpfile("results/waveforms/tb_extra.vcd");
        $dumpvars(0, tb_extra);

        wait (u0.halted == 1'b1);
        @(negedge clk);
        $display("CPU halted at pc = %h after %0d cycles", u0.pc, cycles);

        if (u0.pc !== 32'h1098) begin
            $display("FAIL  halted at the wrong address (expected 00001098)");
            errors = errors + 1;
        end

        check(0,  32'h00000000);    // addi x0, x0, 5 must not change x0
        check(1,  32'hFFFFFFF0);
        check(2,  32'h0000005A);
        check(3,  32'h00000050);    // and
        check(4,  32'hFFFFFFFA);    // or
        check(5,  32'hFFFFFFAA);    // xor
        check(6,  32'h0000000A);    // andi
        check(7,  32'h000005A0);    // slli
        check(8,  32'h0000003F);    // srl, shift by 0x5A uses only 26
        check(9,  32'hFFFFFFFF);    // sra
        check(10, 32'h00000001);    // slti
        check(11, 32'h00000001);    // sltiu
        check(12, 32'hFFFFFFFA);    // sw then lw
        check(13, 32'h05A0005A);    // two sh then lw
        check(14, 32'h00000001);    // bne
        check(15, 32'h00000002);    // bge
        check(16, 32'h00000003);    // bgeu
        check(17, 32'h00000004);    // jal
        check(18, 32'hABCDE000);    // lui
        check(19, 32'h00001090);    // jalr x19, 13(x19): return address
        check(20, 32'h00000005);    // jalr jumped to the right place

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
