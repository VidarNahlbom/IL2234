// A single register with a bit width as a parameter, BW

module register_block #(parameter BW) (
    // ----------INPUTS-------------
    input logic clk,                // clock signal
    input logic rst_n,              // Resets the registers output to all 0, Active LOW
    input logic write_en_n,         // Write signal to read state, commonly also called enable, Active LOW
    input logic [BW-1:0] data_in,   // Input data to be read on the rising edge of the clock if write enabled
    // ----------OUTPUTS------------
    output logic [BW-1:0] out
);

    // Since this is a D flip flop the ciruit only reacts to a changing clock depending on what write has for value.
    // This means that a always_ff block is used

    always_ff @(posedge clk or negedge rst_n) begin
        // Handle reset, it takes precidence over writes
        if(!rst_n) begin
            out <= 'b0;
        // Handle a write event
        end else if (!write_en_n) begin
            out <= data_in;
        end
    end
endmodule