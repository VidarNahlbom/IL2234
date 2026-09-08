
// Testbech used in order to validate the functionality of the register module
module register_tb;

    // Circuit parameters
    parameter BW = 4;                   // Bit width
    parameter DEPTH = 15;               // Number of registers

    // Inputs for registers
    logic clk;                          // Clock
    logic chip_en;                      // Chip enable active high
    logic write_en;                     // Write enable active low
    logic reset;                        // Chip reset active low
    
    logic [BW-1:0] data_in;             // Input line into registers
    logic [$clog2(DEPTH)] read_addr_1;  // Address for output line 1
    logic [$clog2(DEPTH)] read_addr_2;  // Address for output line 2
    logic [$clog2(DEPTH)] write_addr;   // Address to be written to

    // Outputs from register
    logic [BW-1:0] data_out_1;          // Data output line 1
    logic [BW-1:0] data_out_2;          // Data output line 2


    // Delcaring the register
    register #(.BW(BW), .DEPTH(DEPTH)) DUT (
        .clk(clk),
        .rst_n(reset),
        .write_en_n(write_en),
        .chip_en(chip_en),
        .data_in(data_in),
        .read_addr_1(read_addr_1),
        .read_addr_2(read_addr_2),
        .write_addr(write_addr),
        .data_out_1(data_out_1),
        .data_out_2(data_out_2)
    );



    initial begin

        //Initialising lines 


        
        // First the reset fucntionality of the reset pin
        // For this a selection of random values are written to.
        for (int i = 0; i < DEPTH; i++) begin
            
            // Setup the data and addresses before write

            // Using random number for data
            data_in = $urandom;

            // Update write address
            write_addr[i] = 'b0;

            // Enable the write enable and commit write
            

        end
    end

endmodule