module memory_write_unit (
    input logic mem_write, // control signal from controller for enabling or disabling writes
    input logic [1:0] addr_lo, // ALU result [1:0]: byte offset
    input logic [2:0] func3, // 000 SB, 001 SH, 010 SW
    output logic [3:0] write_en 
);
    always_comb begin
        if (mem_write) begin
            case (func3)
                3'b000: case (addr_lo) 
                            2'd0: write_en = 4'b0001;
                            2'd1: write_en = 4'b0010;
                            2'd2: write_en = 4'b0100;
                            2'd3: write_en = 4'b1000;
                        endcase
                3'b001: write_en = addr_lo[1] ? 4'b1100 : 4'b0011; // Untested in milestone 2 
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