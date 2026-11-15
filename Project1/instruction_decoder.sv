module instruction_decoder (
    input  logic [31:0] instruction,
    // Here we define the inputs and outputs and how many bits each has
    output logic [6:0] opcode,
    output logic [4:0] rd,
    output logic [4:0] rs1,
    output logic [4:0] rs2,
    output logic [2:0] funct3,
    output logic [6:0] funct7,
    output logic       alu_b_sel,
    output logic [3:0] alu_op
);
    // We will now extract the specific bits we need from the instruction
    assign opcode = instruction[6:0];
    assign rd = instruction[11:7];
    assign funct3 = instruction[14:12];
    assign rs1 = instruction[19:15];
    assign rs2 = instruction[24:20];
    assign funct7 = instruction[31:25];

    always_comb begin
        alu_b_sel = 1'b0; // Make it default to using two registers
        alu_op = 4'b0000; // Make the alu operation default to ADD
        case (opcode)
            7'b0110011: begin // R type
                 alu_b_sel = 1'b0;

                 if(funct3 == 3'b000 && funct7 == 7'b0100000) begin
                    alu_op = 4'b0001; // Sub
                 end

                 else if(funct3 == 3'b111 && funct7 == 7'b0000000) begin
                    alu_op = 4'b0010; // And
                 end

                 else if(funct3 == 3'b110 && funct7 == 7'b0000000) begin
                    alu_op = 4'b0011; // Or
                 end

                 else if(funct3 == 3'b100 && funct7 == 7'b0000000) begin
                    alu_op = 4'b0100; //Xor
                 end

                 else if(funct3 == 3'b001 && funct7 == 7'b0000000) begin
                    alu_op = 4'b0101; // Sll
                 end

                 else if(funct3 == 3'b101 && funct7 == 7'b0000000) begin
                    alu_op = 4'b0110; //Srl
                 end

                 else if(funct3 == 3'b101 && funct7 == 7'b0100000) begin
                    alu_op = 4'b0111; //Sra
                 end

                 else if(funct3 == 3'b010 && funct7 == 7'b0000000) begin
                    alu_op = 4'b1000; // SLT (signed)
                 end

                 else if(funct3 == 3'b011 && funct7 == 7'b0000000) begin
                    alu_op = 4'b1001; // SLTU
                 end
            end
            7'b0010011: begin //I type
                 alu_b_sel = 1'b1;

                 if(funct3 == 3'b000) begin
                    alu_op = 4'b0000; //ADDI
                 end

                 else if(funct3 == 3'b111) begin
                    alu_op = 4'b0010; // AndI
                 end

                 else if(funct3 == 3'b110) begin
                    alu_op = 4'b0011; // OrI
                 end

                 else if(funct3 == 3'b100) begin
                    alu_op = 4'b0100; //XorI
                 end

                 else if(funct3 == 3'b001 && instruction[31:25] == 7'b0000000) begin
                    alu_op = 4'b0101; // SllI
                 end

                 else if(funct3 == 3'b101) begin
                    if(instruction[31:25] == 7'b0000000) begin
                        alu_op = 4'b0110; //SrlI
                    end

                    else if(instruction[31:25] == 7'b0100000) begin
                        alu_op = 4'b0111; //SraI
                    end
                 end

                 else if(funct3 == 3'b010) begin
                    alu_op = 4'b1000; // SLTI (signed)
                 end

                 else if(funct3 == 3'b011) begin
                    alu_op = 4'b1001; // SLTIU
                 end
            end
        endcase
    end

endmodule