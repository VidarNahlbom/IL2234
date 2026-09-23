// Import the register block module

// Module meant to simualte the registers of a RISC V processor. Course nomenclature said this is to be called register_file.
// Not to be confused with register_block witch is a singular register.
module register_file #(parameter BW = 4, parameter DEPTH = 15) (
    //--------------------INPUTS--------------------
    input logic clk,                            // Clock input
    input logic rst_n,                          // Asynchronous active low reset signal
    input logic write_en_n,                     // Active low write enable
    input logic chip_en,                        // Active high chip enable
    input logic [BW-1:0] data_in,               // Data input port
    input logic [$clog2(DEPTH)-1:0] read_addr_1,    // Address for output port 1
    input logic [$clog2(DEPTH)-1:0] read_addr_2,    // Address for output port 2
    input logic [$clog2(DEPTH)-1:0] write_addr,     // Address for input port
    //--------------------OUTPUTS--------------------
    output logic [BW-1:0] data_out_1,           // Data output for port 1
    output logic [BW-1:0] data_out_2            // data output for port 2
);
    // Using generate I can tell the simulator to make a desiered number of copies from a given circuit/module
    // Make an array from all the registers with write_enables and outputs. This way data is easily routed.

    logic write_enables [DEPTH];
    logic [BW-1:0] outputs [DEPTH];
    // So these are effectively wires connected to the respective ports on the register_blocks.

    // Ensuring that reading from 0 always returns a 0 and not X or Z
    assign outputs[0] = 'b0;

    // Generate the desired number of register instances.
    // Starting from i = 1 since address 0 is hardwired to 0.
    // Remember address = 0 is handled separately.
    generate
        for (genvar i = 1; i < DEPTH; i++ ) begin

            // An instance of a singular register
            register_block #(.BW(BW)) internal_reg (
                .clk(clk),
                .rst_n(rst_n),
                .write_en_n(write_enables[i]),
                .data_in(data_in),
                .out(outputs[i])
            );
            
        end
    endgenerate

    // Since the routing of data does not depend on prior inputs the always_comb block is used.
    always_comb begin

        // As a default, write to all blocks is disabled
        // Since its active low, this means value is set to 1
        write_enables = '{default: 1'b1};

        // Reset function & Standby function
        // For the RF, both functions cause the same effect.
        // For the reset function, since rst has already been wired to each internal_reg
        // rst is handled internally by each. 
        // but we still need to reset the data_out
        // this is done combinationally and therefore async here
        // in the reg blocks, its activated by rst_n having negedge
        if (!rst_n | !chip_en) begin
            data_out_1 = 'b0;
            data_out_2 = 'b0;
        end

        // Write function & Read function
        // We handle write and read at the same time, as no matter what data is read to the outputs.
        else begin
            if (!write_en_n) begin 
                // overwrite 0 to enable write function of that specific internal reg.
                // Because write signals are active low its set to 0
                write_enables[write_addr] = '0;
            end
            // the outputs are determined by the corresponding address provided.
            data_out_1 = outputs[read_addr_1];
            data_out_2 = outputs[read_addr_2];
        end
    end
endmodule

