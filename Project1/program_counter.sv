module program_counter (
    input  logic        clk,
    input  logic        reset,
    input  logic        pc_write_enable,
    input  logic [31:0] next_pc,
    output logic [31:0] pc
);

    always_ff @(posedge clk) begin
        if (reset) begin
            pc <= 32'h00001000; // Here is the start of the instruction memory
        end
        else if (pc_write_enable) begin
            pc <= next_pc; // Update PC when enabled
        end
    end

endmodule