// All of the different colors
// R -> RG -> G -> GB -> B -> BR -> R
// 12 MHz clock
// Brightness will change every 10,000 clocks.
// Brightness will change by 6 each time.

//Some calcs I did:
// 1,200 / 6 = 200 updates per color section. Using PMW interval from PMW example code
// 10,000 * 200 = 2,000,000 clocks per section. Sp every 10000 clocks, change the step

module top(
    input  logic clk,
    output logic RGB_B,
    output logic RGB_G,
    output logic RGB_R
);

    parameter PWM_INTERVAL = 1_200;
    parameter FADE_INTERVAL = 10_000;
    parameter BRIGHTNESS_STEP = 6;

    
    logic [$clog2(PWM_INTERVAL) - 1:0] pwm_count = 0;
    logic [$clog2(FADE_INTERVAL) - 1:0] fade_count = 0;//every 10k clocks the birghtness will change
    logic [2:0] color = 0;//6 different modes 

    // Current fade amount.
    logic [$clog2(PWM_INTERVAL + 1) - 1:0] fade_value = 0;

    // Brightness of each color so 0 is off and 1200 would be fully on
    logic [$clog2(PWM_INTERVAL + 1) - 1:0] red_value;
    logic [$clog2(PWM_INTERVAL + 1) - 1:0] green_value;
    logic [$clog2(PWM_INTERVAL + 1) - 1:0] blue_value;

    // Rising clock
    always_ff @(posedge clk) begin

        // PWM counter
        if (pwm_count == PWM_INTERVAL - 1)
            pwm_count <= 0;
        else
            pwm_count <= pwm_count + 1;

        // Fade timing counter
        if (fade_count == FADE_INTERVAL - 1) begin
            fade_count <= 0;

            // After reaching 1194, it will start the next color section since 1194 + 6 becomes 1200 = 0    
            if (fade_value == PWM_INTERVAL - BRIGHTNESS_STEP) begin
                fade_value <= 0;

                if (color == 5)
                    color <= 0;
                else
                    color <= color + 1;
            end
            else begin
                fade_value <= fade_value + BRIGHTNESS_STEP;
            end
        end
        else begin
            fade_count <= fade_count + 1;
        end
    end

    // Based on color select which fade we are doing on the pico
    always_comb begin
        case (color)

            // Red -> Yellow
            3'd0: begin
                red_value   = PWM_INTERVAL;
                green_value = fade_value;
                blue_value  = 0;
            end

            // Yellow -> Green
            3'd1: begin
                red_value   = PWM_INTERVAL - fade_value;
                green_value = PWM_INTERVAL;
                blue_value  = 0;
            end

            // Green -> Cyan
            3'd2: begin
                red_value   = 0;
                green_value = PWM_INTERVAL;
                blue_value  = fade_value;
            end

            // Cyan -> Blue
            3'd3: begin
                red_value   = 0;
                green_value = PWM_INTERVAL - fade_value;
                blue_value  = PWM_INTERVAL;
            end

            // Blue -> Magenta
            3'd4: begin
                red_value   = fade_value;
                green_value = 0;
                blue_value  = PWM_INTERVAL;
            end

            // Magenta -> Red
            3'd5: begin
                red_value   = PWM_INTERVAL;
                green_value = 0;
                blue_value  = PWM_INTERVAL - fade_value;
            end

            default: begin
                red_value   = 0;
                green_value = 0;
                blue_value  = 0;
            end
        endcase
    end

    // Turn each color on and off for the correct brightness.
    always_comb begin
        RGB_R = (pwm_count >= red_value);
        RGB_G = (pwm_count >= green_value);
        RGB_B = (pwm_count >= blue_value);
    end

endmodule