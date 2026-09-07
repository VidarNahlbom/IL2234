
// Import the register block module

// Module meant to simualte the registers of a RISC V processor. Coure nomenclature said this is to be called register.
// Not to be confused with register_block witch is a singular register.
module register #(parameter BW, parameter DEPTH) (
//--------------------INPUTS--------------------
    input logic clk,                            // Clock input
    input logic rst_n,                          // Asynchronous active low reset signal
    input logic write_en_n,                     // Active low write enable
    input logic chip_en,                        // Active high chip enable
    input logic [BW-1:0] data_in,               // Data input port
    input logic [$clog2(DEPTH)] read_addr_1,    // Address for output port 1
    input logic [$clog2(DEPTH)] read_addr_2,    // Address for output port 2
    input logic [$clog2(DEPTH)] write_addr,     // Address for input port
//--------------------OUTPUTS--------------------
    output logic [BW-1:0] data_out_1,           // Data output for port 1
    output logic [BW-1:0] data_out_2            // data output for port 2
);


// Usning generate I can tell the simulator to make a desiered number of copies from a given circuit/module
// Make a array from all the registers wirite_enables and outputs. This way data is easely routed.

logic write_enables [DEPTH];
logic [BW-1:0] outputs [DEPTH];

// Ensuring that reading from 0 always returns a 0 and not XS
assign outputs[0] = 'b0;

// Generate the desiered number of register instances
// Starting frrom i = 1 since address 0 is harwiered to 0.
// Remeber address = 0 is handled separately
generate
    for (genvar i = 1; i < DEPTH-1 ; i++ ) begin

        // A instance of  the singular register
        register_block #(.BW(BW)) internal_reg (
            .clk(clk),
            .reset(rst_n),
            .write(write_enables[i]),
            .data_in(data_in),
            .out(outputs[i])
        );
        
    end

endgenerate

// Now 

endmodule