// Control unit for our multicycle RV32I CPU (David)
//
// Holds the PC, the instruction register (IR), and the FSM.
// Decodes the instruction in IR and tells the datapath what to do.
//
// Two simple rules (see docs/architecture.md):
//   1. Decoder outputs (alu_op, the selects, ...) only depend on the instruction,
//      so they stay the same for every cycle of one instruction.
//   2. Write enables only depend on the FSM state.

module control_unit (
    input logic     clk,

    // From memory
    input logic     [31:0] imem_data_out,

    // From the datapath
    input logic     [31:0] alu_out,
    input logic     rs1_eq_rs2,
    input logic     rs1_lt_signed,
    input logic     rs1_lt_unsigned,

    // To memory
    output logic    [31:0] pc,
    output logic    dmem_wren,
    output logic    [2:0] funct3,

    // To the datapath
    output logic    [31:0] instruction,
    output logic    [31:0] pc_plus_4,
    output logic    [3:0] alu_op,
    output logic    [1:0] alu_a_sel,
    output logic    alu_b_sel,
    output logic    [2:0] imm_sel,
    output logic    reg_write_enable,
    output logic    [1:0] wb_sel,
    output logic    alu_out_write_enable,

    // For the testbench
    output logic    halted
);

    // FSM states
    localparam FETCH        = 4'd0;
    localparam FETCH_LATCH  = 4'd1;
    localparam DECODE       = 4'd2;
    localparam EXECUTE      = 4'd3;
    localparam MEM_READ     = 4'd4;
    localparam MEM_WRITE    = 4'd5;
    localparam WRITEBACK    = 4'd6;
    localparam NEXT_FETCH   = 4'd7;
    localparam HALT         = 4'd8;

    // Opcodes (instruction[6:0])
    localparam OP_R_TYPE    = 7'b0110011;
    localparam OP_I_TYPE    = 7'b0010011;
    localparam OP_LOAD      = 7'b0000011;
    localparam OP_STORE     = 7'b0100011;
    localparam OP_BRANCH    = 7'b1100011;
    localparam OP_JAL       = 7'b1101111;
    localparam OP_JALR      = 7'b1100111;
    localparam OP_LUI       = 7'b0110111;
    localparam OP_AUIPC     = 7'b0010111;
    localparam OP_FENCE     = 7'b0001111;

    // ALU operations (must match alu in datapath.sv)
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLL  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_SRA  = 4'b0111;
    localparam ALU_SLT  = 4'b1000;
    localparam ALU_SLTU = 4'b1001;

    // ALU input A select
    localparam A_RS1  = 2'b00;
    localparam A_PC   = 2'b01;
    localparam A_ZERO = 2'b10;

    // ALU input B select
    localparam B_RS2 = 1'b0;
    localparam B_IMM = 1'b1;

    // Immediate formats
    localparam IMM_I = 3'b000;
    localparam IMM_S = 3'b001;
    localparam IMM_B = 3'b010;
    localparam IMM_U = 3'b011;
    localparam IMM_J = 3'b100;

    // Writeback select
    localparam WB_ALU  = 2'b00;
    localparam WB_MEM  = 2'b01;
    localparam WB_PC4  = 2'b10;

    // Registers (initial values = our "reset")
    logic [31:0] pc_reg = 32'h00001000;
    logic [31:0] ir = 32'd0;
    logic [3:0] current_state = FETCH;
    logic [3:0] next_state;

    // Write enables that stay inside the control unit
    logic pc_write_enable;
    logic ir_write_enable;

    // Pieces of the instruction
    logic [6:0] opcode;
    logic [2:0] f3;
    logic bit30;

    // What kind of instruction is in IR
    logic is_valid;
    logic is_load;
    logic is_store;
    logic is_branch;
    logic is_jump;          // jal or jalr
    logic is_fence;

    // PC logic
    logic branch_taken;
    logic pc_sel;
    logic [31:0] next_pc;

    assign pc = pc_reg;
    assign instruction = ir;

    assign opcode = ir[6:0];
    assign f3 = ir[14:12];
    assign bit30 = ir[30];

    // funct3 goes straight to Brad's memory (it decides byte/half/word)
    assign funct3 = f3;

    // ---------------------------------------------------------------------
    // Decoder: only depends on the instruction in IR
    // ---------------------------------------------------------------------
    always_comb begin
        // Defaults (used by anything we don't list below)
        is_valid = 1'b0;
        is_load = 1'b0;
        is_store = 1'b0;
        is_branch = 1'b0;
        is_jump = 1'b0;
        is_fence = 1'b0;
        alu_a_sel = A_RS1;
        alu_b_sel = B_RS2;
        imm_sel = IMM_I;
        wb_sel = WB_ALU;
        alu_op = ALU_ADD;

        case (opcode)
            OP_R_TYPE: begin
                is_valid = 1'b1;
                alu_a_sel = A_RS1;
                alu_b_sel = B_RS2;
                case (f3)
                    3'b000: alu_op = bit30 ? ALU_SUB : ALU_ADD;
                    3'b001: alu_op = ALU_SLL;
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    3'b100: alu_op = ALU_XOR;
                    3'b101: alu_op = bit30 ? ALU_SRA : ALU_SRL;
                    3'b110: alu_op = ALU_OR;
                    3'b111: alu_op = ALU_AND;
                endcase
            end
            OP_I_TYPE: begin
                is_valid = 1'b1;
                alu_a_sel = A_RS1;
                alu_b_sel = B_IMM;
                imm_sel = IMM_I;
                case (f3)
                    3'b000: alu_op = ALU_ADD;      // addi: bit 30 is part of the immediate, don't look at it!
                    3'b001: alu_op = ALU_SLL;
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    3'b100: alu_op = ALU_XOR;
                    3'b101: alu_op = bit30 ? ALU_SRA : ALU_SRL;
                    3'b110: alu_op = ALU_OR;
                    3'b111: alu_op = ALU_AND;
                endcase
            end
            OP_LUI: begin
                is_valid = 1'b1;
                alu_a_sel = A_ZERO;     // 0 + imm
                alu_b_sel = B_IMM;
                imm_sel = IMM_U;
            end
            OP_AUIPC: begin
                is_valid = 1'b1;
                alu_a_sel = A_PC;       // PC + imm
                alu_b_sel = B_IMM;
                imm_sel = IMM_U;
            end
            OP_JAL: begin
                is_valid = 1'b1;
                is_jump = 1'b1;
                alu_a_sel = A_PC;       // target = PC + imm
                alu_b_sel = B_IMM;
                imm_sel = IMM_J;
                wb_sel = WB_PC4;        // rd = PC + 4
            end
            OP_JALR: begin
                is_valid = 1'b1;
                is_jump = 1'b1;
                alu_a_sel = A_RS1;      // target = rs1 + imm
                alu_b_sel = B_IMM;
                imm_sel = IMM_I;
                wb_sel = WB_PC4;        // rd = PC + 4
            end
            OP_BRANCH: begin
                is_valid = 1'b1;
                is_branch = 1'b1;
                alu_a_sel = A_PC;       // target = PC + imm
                alu_b_sel = B_IMM;
                imm_sel = IMM_B;
            end
            OP_LOAD: begin
                is_valid = 1'b1;
                is_load = 1'b1;
                alu_a_sel = A_RS1;      // address = rs1 + imm
                alu_b_sel = B_IMM;
                imm_sel = IMM_I;
                wb_sel = WB_MEM;
            end
            OP_STORE: begin
                is_valid = 1'b1;
                is_store = 1'b1;
                alu_a_sel = A_RS1;      // address = rs1 + imm
                alu_b_sel = B_IMM;
                imm_sel = IMM_S;
            end
            OP_FENCE: begin
                is_valid = 1'b1;        // we only have one core, so fence does nothing
                is_fence = 1'b1;
            end
            default: begin
                is_valid = 1'b0;        // ecall, ebreak, csr, 0x00000000, ... -> HALT
            end
        endcase
    end

    // ---------------------------------------------------------------------
    // Branch decision
    // ---------------------------------------------------------------------
    always_comb begin
        case (f3)
            3'b000: branch_taken = rs1_eq_rs2;          // beq
            3'b001: branch_taken = ~rs1_eq_rs2;         // bne
            3'b100: branch_taken = rs1_lt_signed;       // blt
            3'b101: branch_taken = ~rs1_lt_signed;      // bge
            3'b110: branch_taken = rs1_lt_unsigned;     // bltu
            3'b111: branch_taken = ~rs1_lt_unsigned;    // bgeu
            default: branch_taken = 1'b0;
        endcase
    end

    // ---------------------------------------------------------------------
    // Next PC
    // ---------------------------------------------------------------------
    assign pc_plus_4 = pc_reg + 32'd4;

    assign pc_sel = is_jump | (is_branch & branch_taken);

    // Clear bit 0 of the target (needed for jalr, harmless for the others)
    assign next_pc = pc_sel ? { alu_out[31:1], 1'b0 } : pc_plus_4;

    // ---------------------------------------------------------------------
    // FSM
    // ---------------------------------------------------------------------

    // Register the next state of the FSM
    always_ff @(posedge clk)
        current_state <= next_state;

    // Compute the next state of the FSM
    always_comb begin
        next_state = HALT;
        case (current_state)
            FETCH:
                next_state = FETCH_LATCH;
            FETCH_LATCH:
                next_state = DECODE;
            DECODE:
                if (is_valid)
                    next_state = EXECUTE;
                else
                    next_state = HALT;
            EXECUTE:
                if (is_load)
                    next_state = MEM_READ;
                else if (is_store)
                    next_state = MEM_WRITE;
                else if (is_branch || is_fence)
                    next_state = NEXT_FETCH;
                else
                    next_state = WRITEBACK;     // ALU, lui, auipc, jal, jalr
            MEM_READ:
                next_state = WRITEBACK;
            MEM_WRITE:
                next_state = NEXT_FETCH;
            WRITEBACK:
                next_state = NEXT_FETCH;
            NEXT_FETCH:
                next_state = FETCH;
            HALT:
                next_state = HALT;
        endcase
    end

    // Write enables: one state, one job
    assign ir_write_enable      = (current_state == FETCH_LATCH);
    assign alu_out_write_enable = (current_state == EXECUTE);
    assign dmem_wren            = (current_state == MEM_WRITE);
    assign reg_write_enable     = (current_state == WRITEBACK);
    assign pc_write_enable      = (current_state == NEXT_FETCH);

    assign halted = (current_state == HALT);

    // Instruction register
    always_ff @(posedge clk) begin
        if (ir_write_enable)
            ir <= imem_data_out;
    end

    // Program counter
    always_ff @(posedge clk) begin
        if (pc_write_enable)
            pc_reg <= next_pc;
    end

endmodule
