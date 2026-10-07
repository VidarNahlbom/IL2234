
// Testbech used in order to validate the functionality of the register_file module
`timescale 1ns / 1ps
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
        
        // Definign a dynamic array to hold 10 random values for validatio
        logic [BW-1:0] random_values [0:DEPTH-1];
        logic [$clog2(DEPTH)-1:0] tmp_addr_1;        
        // Set all inputs to 0 state
        rst_n = 0;
        write_en_n = 0;
        write_addr = 0;
        read_addr_1 = 0;
        read_addr_2 = 0;
        data_in = 0;
        chip_en = 0;
        write_addr = 0;
        
        // Disable reset
        @(negedge clk);
        rst_n = 1;
        
        // Enable chip and disbale write
        @(negedge clk);
        write_en_n = 1;
        chip_en = 1; 
    
        // The milestone seems to want a manual testbench, using random inputs at random addr
        // we then simply have to print to display the contents of the Registers
        // and see that the actual values follow the random inputs
        
        // Prepare for write, enable
        @(negedge clk);
        write_en_n = 0;
        
        $display("Begining read and write test");
        
        // Fill register with random values and save said values for validation
        for (int i = 0; i < DEPTH; i++) begin
        
            @(negedge clk); // On the next negiative edge, prepare inputs
            random_values[i] = $urandom;
            data_in = random_values[i];
            write_addr = i;
            
            @(posedge clk); // On the following positive edge, commit the write
            #1; // Let the write happen
        end

        // Disble the wirte functionality
        write_en_n = 1;
        
        // Testing read fucntinality for both address inputs at once
        
        @(negedge clk); // On the negative clk edge prepare addresses
        read_addr_1 = 0;
        read_addr_2 = 0;
            
        #1; // Wait one clock cucle to allow for read
               
        $display("Addr: %0d | Expected: %0d | Actual_1: %0d | Actual_2: %0d | %s", 0, random_values[0], data_out_1, data_out_2, 
                  (data_out_1 === 0 && data_out_2 === 0) ? "true" : "false" );
                        
        for (int i = 1; i < DEPTH; i++) begin
            
            @(negedge clk); // On the negative clk edge prepare addresses
            read_addr_1 = i;
            read_addr_2 = i;
            
            #1; // Wait one clock cucle to allow for read
               
            $display("Addr: %0d | Expected: %0d | Actual_1: %0d | Actual_2: %0d | %s", i, random_values[i], data_out_1, data_out_2, 
                        (data_out_1 === random_values[i] && data_out_2 === random_values[i]) ? "true" : "false" );
                      
        end
       
        $display("Begining reset test");
        // Validate reset
        // Reset the register
        rst_n = 0;
        #1; // Wait for reset to take place
        @(negedge clk);
        rst_n = 1;
        
        // Ensure all outputs are 0
        for (int i = 0; i < DEPTH; i++) begin
            
            @(negedge clk); // On the negative clk edge prepare addresses
            read_addr_1 = i;
            read_addr_2 = i;
            
            #1; // Wait one clock cucle to allow for read
               
            $display("Addr: %0d | Expected: 0 | Actual_1: %0d | Actual_2: %0d | %s", i, data_out_1, data_out_2,
                       (data_out_1 === 0 && data_out_2 === 0) ? "true" : "false");
                      
        end
        
        
        $display("Begining the test of the wirte disable");
        
        // Now to test that write enable even disables
        // Attemp to wirite without enable.
        for (int i = 0; i < DEPTH; i++) begin
        
            @(negedge clk); // On the next negiative edge, prepare inputs
            random_values[i] = $urandom;
            data_in = random_values[i];
            write_addr = i;
            
            @(posedge clk); // On the following positive edge, commit the write
            #1; // Let the write happen
        end
        
        // Should till be all 0
         for (int i = 0; i < DEPTH; i++) begin
            
            @(negedge clk); // On the negative clk edge prepare addresses
            read_addr_1 = i;
            read_addr_2 = i;
            
            #1; // Wait one clock cucle to allow for read
               
            $display("Addr: %0d | Expected: 0 | Actual_1: %0d | Actual_2: %0d | %s", i, data_out_1, data_out_2,
                       (data_out_1 === 0 && data_out_2 === 0) ? "true" : "false");
                      
        end
        
        $display("Beggining random write-read test");
        
        // Random read writes as requiered by the labb PM
        for (int i = 0; i < 20; i++) begin
            
            // Select two reitsers at random.
            tmp_addr_1 = $urandom_range(DEPTH-1, 0);
            
            // If one of them is addr = 0 then set the expected value to 0 else something at random
            if(tmp_addr_1 === 0) begin
                random_values[0] = 0;
            end else begin
                random_values[0] = $urandom;
            end
            
            // Now preform a write
            // Prepare for write
            write_addr = tmp_addr_1;
            data_in = random_values[0];
            
            @(negedge clk); // At the next negative clock edge enable writing
            write_en_n = 0;
            
            #1; // Wait for write to take place
            
            // Disable write
            @(negedge clk);
            write_en_n = 1;
            
            // Validate with read
            // prepare for read
            read_addr_1 = tmp_addr_1;
            
            @(posedge clk); // At the next positive edge read the value at addr_1
            $display("Addr: %d | Expected: %d | Actual: %d | %s", tmp_addr_1, random_values[0], data_out_1, 
                        (data_out_1 === random_values[0])? "true" : "false" );
           
        end        
        
        $finish; // Here to tell the simualtor to stop.
        
    end
    
endmodule
