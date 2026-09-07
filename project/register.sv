
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


// Declare the registers as a separate list of signals

// Implement memory fucntionality using always_ff block
// Alter lacth state on the rising clock edge or falling reset edge, so listen for those
always_ff @(posedge clk or negedge rst_n) begin



end


endmodule