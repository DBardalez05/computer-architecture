module control_unit (
    input logic clk,
    input logic reset,
    input logic [6:0] opcode,
    output logic reg_write_enable,
    output logic ir_write_enable,
    output logic pc_write_enable
);
    // All the different states that state_t can be
    typedef enum logic [2:0] {
        FETCH,
        FETCH_LATCH,
        DECODE,
        EXECUTE,
        WRITEBACK
    } state_t;
    // We keep track of the curent state we are in and that the state shoudl be on the next clock edge
    state_t state, next_state;

    // Here we change the current state at each rising clock edge
    always_ff @(posedge clk) begin
        if (reset) begin
            state <= FETCH; // We will start the CPU in FETCH
        end
        
        else begin
            state <= next_state; // Then we move to the next state
        end
    end

    //Now here we determine what is the next state that comes
    always_comb begin
        case (state)
            FETCH: next_state = FETCH_LATCH;
            FETCH_LATCH: next_state = DECODE;
            DECODE: next_state = EXECUTE;
            EXECUTE: next_state = WRITEBACK;
            WRITEBACK: next_state = FETCH; 

            default: next_state = FETCH;
        endcase
    end
    // When the state is wrtieback we enable out processor to write into registars
    assign reg_write_enable = (state == WRITEBACK);
    // Make it to where you can only save new instruction during fetch_latch
    assign ir_write_enable = (state == FETCH_LATCH);
    // Then we will only update the pc once the current instruction is finished
    assign pc_write_enable = (state == WRITEBACK);
endmodule