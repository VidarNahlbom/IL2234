module program_counter (
    input logic clk,
    input logic rst_n,
    input logic pc_write_en, // from controller, decides when PC updates
    input logic [1:0] pc_src, // from controller, decides PC input mux
    input logic [31:0] imm, // from decoder 
    input logic [31:0] alu_out, // out from ALU
    output logic [31:0] pc_out, // to memory addr mux
    output logic [31:0] pc_plus_4, // To RF input mux
    output logic [31:0] pc_plus_imm // To RF input mux
);
    logic [31:0] pc_next;

    // Dedicated adders 
    assign pc_plus_4 = pc_out + 32'd4;
    assign pc_plus_imm = pc_out + imm;

    // PC input mux(es)
    always_comb begin
        case (pc_src)
            2'b01: pc_next = pc_plus_imm; // JAL, taken branch
            2'b10: pc_next = {alu_out[31:2], 2'b00}; // JALR
            default: pc_next = pc_plus_4; // normal flow (pc_src = 2'b00)
        endcase
    end

    // PC register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) pc_out <= 32'd0;
        else if (pc_write_en) pc_out <= pc_next;
    end
endmodule