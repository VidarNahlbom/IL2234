module program_counter (
    input logic clk,
    input logic rst_n,
    input logic pc_en,
    input logic [1:0] PC_src,
    input logic [31:0] imm,
    input logic [31:0] alu_out,
    output logic [31:0] pc_out,
    output logic [31:0] pc_plus_4,
    output logic [31:0] pc_plus_imm
);
    logic [31:0] pc_next;

    // Dedicated adders 
    assign pc_plus_4 = pc_out + 32'd4;
    assign pc_plus_imm = pc_out + imm;

    // PC input mux(es)
    always_comb begin
        case (PC_src)
            2'b01: pc_next = pc_plus_imm; // JAL, taken branch
            2'b10: pc_next = {alu_out[31:2], 2'b00}; // JALR
            default: pc_next = pc_plus_4; // normal flow (PC_src = 2'b00)
        endcase
    end

    // PC register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) pc_out <= 32'd0;
        else if (pc_en) pc_out <= pc_next;
    end
endmodule