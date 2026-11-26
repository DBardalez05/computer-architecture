module cpu (
    input logic clk,
    input logic reset
);

    // The program counter signals
    logic [31:0] pc;
    logic [31:0] next_pc;
    logic pc_write_enable;

    // Mem signals
    logic [2:0] funct3;
    logic dmem_wren;
    logic [31:0] dmem_address;
    logic [31:0] dmem_data_in;
    logic [31:0] dmem_data_out;
    logic [31:0] imem_data_out;

    logic memory_reset;
    logic led;
    logic red;
    logic green;
    logic blue;

    // IR signals
    logic [31:0] instruction;
    logic ir_write_enable;

    // Instruction Decoder signals
    logic [6:0] opcode;
    logic [4:0] rd;
    logic [4:0] rs1;
    logic [4:0] rs2;
    logic [6:0] funct7;
    logic alu_b_sel;
    logic [3:0] alu_op;

    // FSM signals
    logic reg_write_enable;
    logic alu_out_write_enable;

    // Datapath signals
    logic [1:0] alu_a_sel;
    logic [2:0] imm_sel;
    logic [1:0] wb_sel;
    logic [31:0] alu_out;
    logic rs1_eq_rs2;
    logic rs1_lt_signed;
    logic rs1_lt_unsigned;


    // Calculates teh address of the next instruction
    assign next_pc = pc + 32'd4;

    // Default control signals taht were set for arithmetic instructions
    assign alu_a_sel = 2'b00;
    assign imm_sel = 3'b000;
    assign wb_sel = 2'b00;
    assign dmem_wren = 1'b0;


    // Connect the program counter
    program_counter pc_module (
        .clk(clk),
        .reset(reset),
        .pc_write_enable(pc_write_enable),
        .next_pc(next_pc),
        .pc(pc)
    );

    memory #(
        .IMEM_INIT_FILE_PREFIX("Project1/arith_test")
    ) mem (
        .clk(clk),
        .funct3(funct3),
        .dmem_wren(dmem_wren),
        .dmem_address(dmem_address),
        .dmem_data_in(dmem_data_in),
        .imem_address(pc),
        .imem_data_out(imem_data_out),
        .dmem_data_out(dmem_data_out),
        .reset(memory_reset),
        .led(led),
        .red(red),
        .green(green),
        .blue(blue)
    );

    // Connect instruction register
    instruction_register ir_module(
        .clk(clk),
        .reset(reset),
        .ir_write_enable(ir_write_enable),
        .imem_data_out(imem_data_out),
        .instruction(instruction)
    );

    // Connect the instruction decoder
    instruction_decoder decoder_module (
        .instruction(instruction),
        .opcode(opcode),
        .rd(rd),
        .rs1(rs1),
        .rs2(rs2),
        .funct3(funct3),
        .funct7(funct7),
        .alu_b_sel(alu_b_sel),
        .alu_op(alu_op)
    );

    // Connect the FSM
    control_unit cu_module (
        .clk(clk),
        .reset(reset),
        .opcode(opcode),
        .reg_write_enable(reg_write_enable),
        .ir_write_enable(ir_write_enable),
        .pc_write_enable(pc_write_enable),
        .alu_out_write_enable(alu_out_write_enable)
    );

    // Connect datapath
    datapath dp_module (
        .clk(clk),
        .instruction(instruction),
        .pc(pc),
        .pc_plus_4(next_pc),
        .alu_op(alu_op),
        .alu_a_sel(alu_a_sel),
        .alu_b_sel(alu_b_sel),
        .imm_sel(imm_sel),
        .reg_write_enable(reg_write_enable),
        .wb_sel(wb_sel),
        .alu_out_write_enable(alu_out_write_enable),
        .dmem_data_out(dmem_data_out),
        .dmem_address(dmem_address),
        .dmem_data_in(dmem_data_in),
        .alu_out(alu_out),
        .rs1_eq_rs2(rs1_eq_rs2),
        .rs1_lt_signed(rs1_lt_signed),
        .rs1_lt_unsigned(rs1_lt_unsigned)
    );

endmodule