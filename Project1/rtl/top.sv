`include "memory.sv"
`include "control_unit.sv"
`include "datapath.sv"

// Top level: connects the control unit, the datapath and Brad's memory.
// IMEM_FILE picks the program (the default is the LED program for the board).

module top #(
    parameter IMEM_FILE = "programs/hex/led_blink",
    parameter CLK_FREQ  = 12000000
)(
    input logic     clk,
    output logic    LED,
    output logic    RGB_R,
    output logic    RGB_G,
    output logic    RGB_B
);

    // Memory signals
    logic [31:0] imem_address;
    logic [31:0] imem_data_out;
    logic [31:0] dmem_address;
    logic [31:0] dmem_data_in;
    logic [31:0] dmem_data_out;
    logic dmem_wren;
    logic [2:0] funct3;

    // Control unit -> datapath
    logic [31:0] pc;
    logic [31:0] pc_plus_4;
    logic [31:0] instruction;
    logic [3:0] alu_op;
    logic [1:0] alu_a_sel;
    logic alu_b_sel;
    logic [2:0] imm_sel;
    logic reg_write_enable;
    logic [1:0] wb_sel;
    logic alu_out_write_enable;

    // Datapath -> control unit
    logic [31:0] alu_out;
    logic rs1_eq_rs2;
    logic rs1_lt_signed;
    logic rs1_lt_unsigned;

    logic halted;

    // LED outputs from memory (active high)
    logic reset;
    logic led;
    logic red;
    logic green;
    logic blue;

    // Instructions are always fetched from the PC
    assign imem_address = pc;

    control_unit cu (
        .clk                    (clk),
        .imem_data_out          (imem_data_out),
        .alu_out                (alu_out),
        .rs1_eq_rs2             (rs1_eq_rs2),
        .rs1_lt_signed          (rs1_lt_signed),
        .rs1_lt_unsigned        (rs1_lt_unsigned),
        .pc                     (pc),
        .dmem_wren              (dmem_wren),
        .funct3                 (funct3),
        .instruction            (instruction),
        .pc_plus_4              (pc_plus_4),
        .alu_op                 (alu_op),
        .alu_a_sel              (alu_a_sel),
        .alu_b_sel              (alu_b_sel),
        .imm_sel                (imm_sel),
        .reg_write_enable       (reg_write_enable),
        .wb_sel                 (wb_sel),
        .alu_out_write_enable   (alu_out_write_enable),
        .halted                 (halted)
    );

    datapath dp (
        .clk                    (clk),
        .instruction            (instruction),
        .pc                     (pc),
        .pc_plus_4              (pc_plus_4),
        .alu_op                 (alu_op),
        .alu_a_sel              (alu_a_sel),
        .alu_b_sel              (alu_b_sel),
        .imm_sel                (imm_sel),
        .reg_write_enable       (reg_write_enable),
        .wb_sel                 (wb_sel),
        .alu_out_write_enable   (alu_out_write_enable),
        .dmem_data_out          (dmem_data_out),
        .dmem_address           (dmem_address),
        .dmem_data_in           (dmem_data_in),
        .alu_out                (alu_out),
        .rs1_eq_rs2             (rs1_eq_rs2),
        .rs1_lt_signed          (rs1_lt_signed),
        .rs1_lt_unsigned        (rs1_lt_unsigned)
    );

    memory #(
        .IMEM_INIT_FILE_PREFIX  (IMEM_FILE),
        .CLK_FREQ               (CLK_FREQ)
    ) mem (
        .clk                    (clk),
        .funct3                 (funct3),
        .dmem_wren              (dmem_wren),
        .dmem_address           (dmem_address),
        .dmem_data_in           (dmem_data_in),
        .imem_address           (imem_address),
        .imem_data_out          (imem_data_out),
        .dmem_data_out          (dmem_data_out),
        .reset                  (reset),
        .led                    (led),
        .red                    (red),
        .green                  (green),
        .blue                   (blue)
    );

    // The LEDs on the board are active low
    assign LED   = ~led;
    assign RGB_R = ~red;
    assign RGB_G = ~green;
    assign RGB_B = ~blue;

endmodule
