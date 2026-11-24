module instruction_register (
    input logic clk,
    input logic reset,
    input logic ir_write_enable,
    input logic [31:0] imem_data_out,
    output logic [31:0] instruction
);

    // Save the fetched instruction when instructed to by our FSM
    always_ff @(posedge clk) begin
        if (reset) begin
            instruction <= 32'd0;
        end
        else if (ir_write_enable) begin
            instruction <= imem_data_out;
        end
    end

endmodule