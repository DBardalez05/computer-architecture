module game_of_life #(
    parameter INIT_FILE = "initial_grid.mem"
)(
    input  logic       clk,
    input  logic       update,
    input  logic [5:0] pixel,
    output logic       cell_alive
);

    // Eight rows, with eight cells in each row.
    // A bit value of 1 means alive, and 0 means dead.
    logic [7:0] current_grid [0:7];
    logic [7:0] next_grid [0:7];

    integer row;
    integer col;
    integer neighbor_count;
    integer update_row;

    // Load the starting grid once when the FPGA begins.
    initial begin
        $readmemh(INIT_FILE, current_grid);
    end

    // Return whether the requested pixel is alive.
    //
    // pixel[5:3] gives the row number.
    // pixel[2:0] gives the column number.
    assign cell_alive =
        current_grid[pixel[5:3]][pixel[2:0]];

    // We must find the next state of each cell based on its neighbors
    always_comb begin
        // First go through each row then each column in the 8x8 grid
        for (row = 0; row < 8; row = row + 1) begin
            for (col = 0;  col < 8; col = col + 1) begin
                
                // For the cell that we inspect, we start off with 0 neighbors and add as we detect another neighbor
                neighbor_count = 0;

                // We will first scan for the three neighbor cells above the selected cell
                // We use % 8 for column and row equation to still account for the wrap around in the matrix
                neighbor_count = neighbor_count + current_grid[(row + 7) % 8][(col + 7) % 8];
                neighbor_count = neighbor_count + current_grid[(row + 7) % 8][col];
                neighbor_count = neighbor_count + current_grid[(row + 7) % 8][(col + 1) % 8];

                // Now we will check for the neighbors on the left and right side of the selected cell
                neighbor_count = neighbor_count + current_grid[row][(col + 7) % 8];
                neighbor_count = neighbor_count + current_grid[row][(col + 1) % 8];
                
                //Finally we will check for the cells in row below the selected cell
                neighbor_count = neighbor_count + current_grid[(row + 1) % 8][(col + 7) % 8];
                neighbor_count = neighbor_count + current_grid[(row + 1) % 8][col];
                neighbor_count = neighbor_count + current_grid[(row + 1) % 8][(col + 1) % 8];

                // Now that we have the amount of neighbors of the selected cell using the rules we must see if the cell survives or not
                // Accounts for overpopulation and underpopulation
                if (current_grid[row][col] == 1'b1) begin
                    if (neighbor_count == 2 || neighbor_count == 3) begin
                        next_grid[row][col] = 1'b1;
                    end
                    else begin
                        next_grid[row][col] = 1'b0;
                    end
                end

                //Now we check for when the selected cell is 0 and check whether it has 3 on neighbors so that it comes back to life and change to a 1
                else begin
                    if(neighbor_count == 3) begin
                        next_grid[row][col] = 1'b1;
                    end

                    else begin
                        next_grid[row][col] = 1'b0;
                    end
                end
            end
        end
    end

    // When the update variable is high, copy over the new grid state into the current_grid variable
    always_ff @(posedge clk) begin
        if (update) begin
            for (update_row = 0; update_row < 8; update_row = update_row + 1) begin
            current_grid[update_row] <= next_grid[update_row];
            end
        end
    end
endmodule