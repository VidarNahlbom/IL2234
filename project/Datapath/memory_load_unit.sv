module memory_load_unit (
    input logic [31:0] mem_data, // full word from memory
    input logic [1:0] addr_lo, // ALU result [1:0]: byte offset
    input logic [2:0] func3, // 000 LB, 001 LH, 010 LW, 100 LBU, 101 LHU
    output logic [31:0] load_data
);
    logic [7:0]  byte_sel;
    logic [15:0] half_sel;

    always_comb begin
        // same one-hot decode as the writes
        case (addr_lo) 
            2'd0: byte_sel = mem_data[7:0];
            2'd1: byte_sel = mem_data[15:8];
            2'd2: byte_sel = mem_data[23:16];
            2'd3: byte_sel = mem_data[31:24];
        endcase
        half_sel = addr_lo[1] ? mem_data[31:16] : mem_data[15:0];


        case (func3)
            3'b000: load_data = {{24{byte_sel[7]}},  byte_sel}; // LB
            3'b001: load_data = {{16{half_sel[15]}}, half_sel}; // LH
            3'b010: load_data = mem_data;                       // LW
            3'b100: load_data = {24'b0, byte_sel};              // LBU
            3'b101: load_data = {16'b0, half_sel};              // LHU
            default: load_data = mem_data;
        endcase
    end
endmodule