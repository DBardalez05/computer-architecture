`timescale 1ns/1ps

module instruction_register_tb;

    logic clk;
    logic reset;
    logic ir_write_enable;
    logic [31:0] imem_data_out;
    logic [31:0] instruction;

    // Generate a clock
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Connect the instruction register
    instruction_register dut (
        .clk(clk),
        .reset(reset),
        .ir_write_enable(ir_write_enable),
        .imem_data_out(imem_data_out),
        .instruction(instruction)
    );

    initial begin
        // In this first test we will see if the reset will clear the instruction register
        reset = 1'b1;
        ir_write_enable = 1'b0;
        imem_data_out = 32'h00500093;

        @(posedge clk);
        #1;
        $display("IR after the reset = %h", instruction);

        // In this second test we save a new instruction
        reset = 1'b0;
        ir_write_enable = 1'b1;
        imem_data_out = 32'h00500093;

        @(posedge clk);
        #1;

        $display("IR after write = %h", instruction);

         // For this third test we check that the IR will hold its previous instruction
         ir_write_enable = 1'b0;
         imem_data_out = 32'h00700113;

         @(posedge clk);
         #1;
         $display("IR after hold = %h", instruction);

        
        $finish;
    end
endmodule