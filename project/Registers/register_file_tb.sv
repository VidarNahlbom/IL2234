
// Testbech used in order to validate the functionality of the register_file module
module register_file_tb;

    // Circuit parameters
    parameter BW = 4;                   // Bit width
    parameter DEPTH = 15;               // Number of registers_files

    // Inputs for registers
    logic clk;                          // Clock
    logic chip_en;                      // Chip enable active high
    logic write_en_n;                   // Write enable active low
    logic rst_n;                        // Chip reset active low
    
    logic [BW-1:0] data_in;             // Input line into registers_file
    logic [$clog2(DEPTH)-1:0] read_addr_1;  // Address for output line 1
    logic [$clog2(DEPTH)-1:0] read_addr_2;  // Address for output line 2
    logic [$clog2(DEPTH)-1:0] write_addr;   // Address to be written to

    // Outputs from register_file
    logic [BW-1:0] data_out_1;          // Data output line 1
    logic [BW-1:0] data_out_2;          // Data output line 2


    // Declaring the register_file
    register_file #(.BW(BW), .DEPTH(DEPTH)) DUT (
        .clk(clk),
        .rst_n(rst_n),
        .write_en_n(write_en_n),
        .chip_en(chip_en),
        .data_in(data_in),
        .read_addr_1(read_addr_1),
        .read_addr_2(read_addr_2),
        .write_addr(write_addr),
        .data_out_1(data_out_1),
        .data_out_2(data_out_2)
    );

    // clk at 10ns period
    initial begin 
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 0;
        write_en_n = 0;
        write_addr = 0;
        read_addr_1 = 0;
        read_addr_2 = 0;
        data_in = 0;
        chip_en = 0;
        write_addr = 0;

        @(negedge clk);
        rst_n = 1;

        @(negedge clk);
        write_en_n = 1;
        chip_en = 1; 

        @(negedge clk);
        write_en_n = 0;

        // The milestone seems to want a manual testbench, using random inputs at random addr
        // we then simply have to print to display the contents of the RF
        // and see that actual values follows as expected from 
        // the random inputs
        
        // First the reset functionality of the reset pin
        // For this a selection of random values are written to.
        for (int i = 0; i < 10; i++) begin
            @(negedge clk);
            data_in    = $urandom;
            write_addr = $urandom_range(1, DEPTH-1);  // see bug below for why not $random
            @(posedge clk);
            #1 // let the write settle combinationally/on the clock edge
            $display("t=%0t: wrote data_in=%0h to write_addr=%0d -> outputs[%0d]=%0h",
                    $time, data_in, write_addr, write_addr, DUT.outputs[write_addr]);
        end
    

        @(negedge clk);
        data_in = 'd3;
        write_addr = 'd4;

        @(posedge clk);
        #1 

        read_addr_2 = 'd4;

        @(negedge clk);
        write_en_n = 1;
        @(posedge clk);
        data_in = 'd8;
        write_addr = 'd7;

        @(posedge clk);
        #1 

        read_addr_1 = 'd7;

        @(posedge clk);
        @(posedge clk);

        #4 

        rst_n = 0;

        #10
         
        @(negedge clk);
        rst_n = 1;

        @(posedge clk);
        @(posedge clk);

    end

endmodule