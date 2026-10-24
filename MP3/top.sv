// From the iceBlinkPico led_matrix example code, im reusing the controller WS2812B driver, and shift-register interface code
// Game of Life Logic and the color control code were added for MP3

`include "ws2812b.sv"
`include "controller.sv"
`include "game_of_life.sv"

// led_matrix top level module

module top(
    input logic     clk,
    output logic    _48b,
    output logic    _45a
);

    logic [7:0] red_data;
    logic [7:0] green_data;
    logic [7:0] blue_data;

    logic [5:0] pixel;
    logic [4:0] frame;

    logic [23:0] shift_reg = 24'd0;
    logic load_sreg;
    logic transmit_pixel;
    logic shift;
    logic ws2812b_out;

    // For each game we must see the the selected pixel is alive in that game
    logic red_alive;
    logic green_alive;
    logic blue_alive;
    logic generation_tick;
    logic [4:0] previous_frame = 5'd0;

    // Red Game of Life
    game_of_life #(.INIT_FILE("red_grid.mem")) 
    red_game 
    (
        .clk            (clk),
        .update         (generation_tick),
        .pixel          (pixel),
        .cell_alive     (red_alive)
    );

    // Green Game of Life
    game_of_life #(.INIT_FILE("green_grid.mem")) 
    green_game 
    (
        .clk            (clk),
        .update         (generation_tick),
        .pixel          (pixel),
        .cell_alive     (green_alive)
    );

    // Blue Game of Life
    game_of_life #(.INIT_FILE("blue_grid.mem")) 
    blue_game 
    (
        .clk            (clk),
        .update         (generation_tick),
        .pixel          (pixel),
        .cell_alive     (blue_alive)
    );

    // Keep track of the previous frame
    always_ff @(posedge clk) begin
        previous_frame <= frame;
    end

    // Update the generation tick value for all the games
    assign generation_tick = (previous_frame == 5'd31) && (frame == 5'd0);

    // Set each color channel based on teh pixel taht is alive in each game
    always_comb begin
        red_data   = 8'd0;
        green_data = 8'd0;
        blue_data  = 8'd0;

        if (red_alive)
            red_data = 8'd64;
        
        if (green_alive)
            green_data = 8'd64;

        if (blue_alive)
            blue_data = 8'd64;
    end

    // Instance the WS2812B output driver
    ws2812b u4 (
        .clk            (clk),
        .serial_in      (shift_reg[23]),
        .transmit       (transmit_pixel),
        .ws2812b_out    (ws2812b_out),
        .shift          (shift)
    );


    // Instance the controller
    controller u5 (
        .clk            (clk),
        .load_sreg      (load_sreg),
        .transmit_pixel (transmit_pixel),
        .pixel          (pixel),
        .frame          (frame)
    );


    always_ff @(posedge clk) begin
        if (load_sreg) begin
            shift_reg <= { green_data, red_data, blue_data };
        end
        else if (shift) begin
            shift_reg <= { shift_reg[22:0], 1'b0 };
        end
    end


    assign _48b = ws2812b_out;
    assign _45a = ~ws2812b_out;

endmodule