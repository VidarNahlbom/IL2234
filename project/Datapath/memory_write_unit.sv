// ISA in PDF does not cover stores for the upper part of data in RF
// so theres no way to store x[rs2][31:16] for example
// it only takes the lowest part

module memory_write_unit (
    input logic mem_write, // control signal from controller for enabling or disabling writes
    input logic [1:0] addr_lo, // ALU result [1:0]: byte offset
    input logic [2:0] func3, // from decoder, 000 SB, 001 SH, 010 SW
    input logic [31:0] rs2_data, // store data from RF
    output logic [31:0] data_out, // lane-replicated data to memory
    output logic [3:0] write_en // control signal to memory
);
    always_comb begin
        write_en = 4'b0000;
        if (mem_write) begin
            case (func3)
                3'b000: case (addr_lo) 
                            2'd0: write_en = 4'b0001;
                            2'd1: write_en = 4'b0010;
                            2'd2: write_en = 4'b0100;
                            2'd3: write_en = 4'b1000;
                        endcase
                3'b001: write_en = addr_lo[1] ? 4'b1100 : 4'b0011; // Untested in milestone 2 
                3'b010: write_en = 4'b1111;
                default: write_en = 4'b0000; // if func3 is not correct, something has gone wrong, dont want to corrupt memory because of that
            endcase

            // This replicates the data found in the different regions of the data
            // So say we do a SH operation
            // And x[rs1]+imm adds up to us wanting to write byte 3 and 4 in the RF stored word
            // so x[rs2][31:16], currently the ISA in the PDF says that only 
            // x[rs2][15:0] is to written to memory
            // so if x[rs2] = AABBCCDD then CCDD is written to memory, but we wanted to write byte 3 and 4
            // which is AABB. So to do that we need to make sure that byte 1 and 2 are the same as 3 and 4
            // atleast from memories perspective, so we replicate the upper bytes onto the lower bytes
            case (func3)
                3'b000: data_out = {4{rs2_data[7:0]}}; // SB
                3'b001: data_out = {2{rs2_data[15:0]}}; // SH
                default: data_out = rs2_data; // SW
            endcase
        end
    end
endmodule