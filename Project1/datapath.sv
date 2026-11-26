// Datapath for our multicycle RV32I CPU (Murray)
//
// Register file, immediate generator, ALU, branch comparator and the
// writeback mux. The control unit tells it what to do every cycle.

module datapath (
    input logic     clk,

    input logic     [31:0] instruction,
    input logic     [31:0] pc,
    input logic     [31:0] pc_plus_4,
    input logic     [3:0] alu_op,
    input logic     [1:0] alu_a_sel,
    input logic     alu_b_sel,
    input logic     [2:0] imm_sel,
    input logic     reg_write_enable,
    input logic     [1:0] wb_sel,
    input logic     alu_out_write_enable,

    input logic     [31:0] dmem_data_out,

    output logic    [31:0] dmem_address,
    output logic    [31:0] dmem_data_in,

    output logic    [31:0] alu_out,
    output logic    rs1_eq_rs2,
    output logic    rs1_lt_signed,
    output logic    rs1_lt_unsigned
);

    logic [4:0] rs1;
    logic [4:0] rs2;
    logic [4:0] rd;

    logic [31:0] rs1_value;
    logic [31:0] rs2_value;
    logic [31:0] imm;
    logic [31:0] alu_a;
    logic [31:0] alu_b;
    logic [31:0] alu_result;
    logic [31:0] write_data;

    // ALU result saved in EXECUTE; used later as the memory address,
    // the jump/branch target, or the value written back to rd
    logic [31:0] alu_out_reg = 32'd0;

    assign rs1 = instruction[19:15];
    assign rs2 = instruction[24:20];
    assign rd = instruction[11:7];

    register_file rf (
        .clk            (clk),
        .rs1            (rs1),
        .rs2            (rs2),
        .rd             (rd),
        .write_enable   (reg_write_enable),
        .write_data     (write_data),
        .rs1_value      (rs1_value),
        .rs2_value      (rs2_value)
    );

    imm_gen ig (
        .instruction    (instruction),
        .imm_sel        (imm_sel),
        .imm            (imm)
    );

    // ALU input A: rs1, PC, or zero (for lui)
    always_comb begin
        case (alu_a_sel)
            2'b00: alu_a = rs1_value;
            2'b01: alu_a = pc;
            2'b10: alu_a = 32'd0;
            default: alu_a = 32'd0;
        endcase
    end

    // ALU input B: rs2 or the immediate
    assign alu_b = alu_b_sel ? imm : rs2_value;

    alu alu1 (
        .a              (alu_a),
        .b              (alu_b),
        .alu_op         (alu_op),
        .result         (alu_result)
    );

    always_ff @(posedge clk) begin
        if (alu_out_write_enable)
            alu_out_reg <= alu_result;
    end

    assign alu_out = alu_out_reg;

    // Branch comparator (separate from the ALU, which computes PC + offset)
    assign rs1_eq_rs2 = (rs1_value == rs2_value);
    assign rs1_lt_signed = ($signed(rs1_value) < $signed(rs2_value));
    assign rs1_lt_unsigned = (rs1_value < rs2_value);

    // What gets written to rd: ALU result, loaded data, or PC + 4 (jal/jalr)
    always_comb begin
        case (wb_sel)
            2'b00: write_data = alu_out_reg;
            2'b01: write_data = dmem_data_out;
            2'b10: write_data = pc_plus_4;
            default: write_data = 32'd0;
        endcase
    end

    assign dmem_address = alu_out_reg;
    assign dmem_data_in = rs2_value;
endmodule

module register_file (
    input logic     clk,
    input logic     [4:0] rs1,
    input logic     [4:0] rs2,
    input logic     [4:0] rd,
    input logic     write_enable,
    input logic     [31:0] write_data,
    output logic    [31:0] rs1_value,
    output logic    [31:0] rs2_value
);

    logic [31:0] regs [0:31];

    // Start every register at 0 (our "reset")
    int i;

    initial begin
        for (i = 0; i < 32; i++) begin
            regs[i] = 32'd0;
        end
    end

    // x0 always reads as 0 and is never written
    assign rs1_value = (rs1 == 5'd0) ? 32'd0 : regs[rs1];
    assign rs2_value = (rs2 == 5'd0) ? 32'd0 : regs[rs2];

    always_ff @(posedge clk) begin
        if (write_enable && (rd != 5'd0))
            regs[rd] <= write_data;
    end
endmodule

module alu (
    input logic     [31:0] a,
    input logic     [31:0] b,
    input logic     [3:0] alu_op,
    output logic    [31:0] result
);

    logic [4:0] shamt;

    assign shamt = b[4:0];      // shifts only use the low 5 bits

    always_comb begin
        case (alu_op)
            4'b0000: result = a + b;                                        // add
            4'b0001: result = a - b;                                        // sub
            4'b0010: result = a & b;                                        // and
            4'b0011: result = a | b;                                        // or
            4'b0100: result = a ^ b;                                        // xor
            4'b0101: result = a << shamt;                                   // sll
            4'b0110: result = a >> shamt;                                   // srl
            4'b0111: result = $signed(a) >>> shamt;                         // sra
            4'b1000: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;    // slt
            4'b1001: result = (a < b) ? 32'd1 : 32'd0;                      // sltu
            default: result = 32'd0;
        endcase
    end
endmodule

module imm_gen (
    input logic     [31:0] instruction,
    input logic     [2:0] imm_sel,
    output logic    [31:0] imm
);

    logic [31:0] i;
    logic [31:0] imm_i;
    logic [31:0] imm_s;
    logic [31:0] imm_b;
    logic [31:0] imm_u;
    logic [31:0] imm_j;

    assign i = instruction;

    assign imm_i = { {20{i[31]}}, i[31:20] };
    assign imm_s = { {20{i[31]}}, i[31:25], i[11:7] };
    assign imm_b = { {19{i[31]}}, i[31], i[7], i[30:25], i[11:8], 1'b0 };
    assign imm_u = { i[31:12], 12'd0 };
    assign imm_j = { {11{i[31]}}, i[31], i[19:12], i[20], i[30:21], 1'b0 };

    always_comb begin
        case (imm_sel)
            3'b000: imm = imm_i;
            3'b001: imm = imm_s;
            3'b010: imm = imm_b;
            3'b011: imm = imm_u;
            3'b100: imm = imm_j;
            default: imm = 32'd0;
        endcase
    end
endmodule
