module instruction_register (
    input logic clk,
    input logic rst_n,
    input logic ir_write_en, // from controller
    input logic [31:0] ir_in, // from data_out from memory
    output logic [31:0] ir_out // to decoder input
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) ir_out <= 32'd0;
        else if (ir_write_en) ir_out <= ir_in;
    end
endmodule