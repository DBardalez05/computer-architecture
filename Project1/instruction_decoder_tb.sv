
`timescale 1ns/1ps

module instruction_decoder_tb;

    // Here are the signals connecting the testbench to the decoder
    logic [31:0] instruction;
    logic        alu_b_sel;
    logic [3:0]  alu_op;
    integer passed = 0;
    integer failed = 0;

    instruction_decoder dut (
        .instruction(instruction),
        .alu_b_sel(alu_b_sel),
        .alu_op(alu_op)
    );

    // Reusable test for all the cases
    task automatic check_instruction(
        input string test_name,
        input logic [31:0] test_instruction,
        input logic [3:0] expected_op,
        input logic expected_b_sel
    );
        begin
            instruction = test_instruction;
            #10;

            if ((alu_op === expected_op) &&
                (alu_b_sel === expected_b_sel)) begin

                $display("PASS: %s", test_name);
                passed = passed + 1;

            end else begin

                $display("FAIL: %s", test_name);
                $display("  Expected: alu_op=%b, alu_b_sel=%b",
                         expected_op, expected_b_sel);
                $display("  Actual:   alu_op=%b, alu_b_sel=%b",
                         alu_op, alu_b_sel);

                failed = failed + 1;
            end
        end
    endtask

    // Run all test cases
    initial begin

        $display("R-TYPE TESTS");

        // Format: name, instruction, expected alu_op, expected alu_b_sel

        check_instruction("ADD",  32'h002081B3, 4'b0000, 1'b0);
        check_instruction("SUB",  32'h402081B3, 4'b0001, 1'b0);
        check_instruction("AND",  32'h0020F1B3, 4'b0010, 1'b0);
        check_instruction("OR",   32'h0020E1B3, 4'b0011, 1'b0);
        check_instruction("XOR",  32'h0020C1B3, 4'b0100, 1'b0);
        check_instruction("SLL",  32'h002091B3, 4'b0101, 1'b0);
        check_instruction("SRL",  32'h0020D1B3, 4'b0110, 1'b0);
        check_instruction("SRA",  32'h4020D1B3, 4'b0111, 1'b0);
        check_instruction("SLT",  32'h0020A1B3, 4'b1000, 1'b0);
        check_instruction("SLTU", 32'h0020B1B3, 4'b1001, 1'b0);

        $display("");
        $display("I-TYPE TESTS");

        check_instruction("ADDI",  32'h00708193, 4'b0000, 1'b1);
        check_instruction("ANDI",  32'h0070F193, 4'b0010, 1'b1);
        check_instruction("ORI",   32'h0070E193, 4'b0011, 1'b1);
        check_instruction("XORI",  32'h0070C193, 4'b0100, 1'b1);
        check_instruction("SLLI",  32'h00209193, 4'b0101, 1'b1);
        check_instruction("SRLI",  32'h0020D193, 4'b0110, 1'b1);
        check_instruction("SRAI",  32'h4020D193, 4'b0111, 1'b1);
        check_instruction("SLTI",  32'h0070A193, 4'b1000, 1'b1);
        check_instruction("SLTIU", 32'h0070B193, 4'b1001, 1'b1);

        // Displays the final results
        $display("");
        $display("===== TEST SUMMARY =====");
        $display("Passed: %0d", passed);
        $display("Failed: %0d", failed);

        if (failed == 0) begin
            $display("ALL TESTS PASSED!");
        end else begin
            $fatal(1, "Some decoder tests failed!");
        end

        $finish;
    end

endmodule
