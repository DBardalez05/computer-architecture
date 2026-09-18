//start at R Then RG G GB B BR
//So every 2MHz change color = 1/6 of second
module top(
    input logic clk,
    output logic RGB_B,
    output logic RGB_G,
    output logic RGB_R
);

    parameter BLINK_INTERVAL = 2000000;
    logic [$clog2(BLINK_INTERVAL)-1:0] count = 0;
    // 3 bit variable for the color
    logic [2:0] color = 0;

    initial begin
        RGB_R = 1'b0;
        RGB_B =1'b1;
        RGB_G =1'b1;
    end

    always_ff @(posedge clk) begin
    //Since <= updates variables every rising edge my plan was to pre move the next 
    //color so that is why when it gets to 5, we make it set to 0 from there since changes are not immediate.
        if (count == BLINK_INTERVAL - 1) begin
            count <= 0;
            color <= color + 1;
            RGB_B <=1'b1;
            RGB_G <=1'b1;
            RGB_R <=1'b1;
            if (color == 0) begin
                RGB_R <= 1'b0;
                RGB_G <= 1'b0;
            end
            if (color == 1)
                RGB_G <= 1'b0;
            if (color == 2) begin
                RGB_G <= 1'b0;
                RGB_B <= 1'b0;
            end
            if (color == 3)
                RGB_B <= 1'b0;
            if (color == 4) begin
                RGB_R <= 1'b0;
                RGB_B <= 1'b0;
            end
            if (color == 5) begin
                RGB_R <= 1'b0;
                color <= 0;
            end
        end
        else begin
            count <= count + 1;
        end

    end

endmodule
            
