module Decoder (
    input logic [31:0] data_in,
    // Instruction parts
    output logic [6:0] opcode,
    output logic [11:7] rd,
    output logic [14:12] func3,
    output logic [19:15] rs1,
    output logic [24:20] rs2,
    output logic [31:25] func7, 
    output logic [31:0] imm,
    // Flag outputs
    output logic is_read,
    output logic is_store,
    // Control signals
    output logic rf_write_src,
    output logic ALU_b_src,
    output logic [3:0] ALU_opcode,
    output logic jmp_src,
    output logic PC_src,
    
);
always_comb begin
    // comb rule:
    opcode, rd, func3, rs1, rs2, func7, imm = '0;

    // All operations have opcode at the start
    opcode = data_in[6:0];

    // then we have if statements for each possible instruction type
    if (opcode === 0110011) begin // R-type
        rd = data_in[11:7];
        func3 = data_in[14:12];
        rs1 = data_in[19:15];
        rs2 = data_in[24:20];
        func7 = data_in[31:25];
    end else if (opcode === 0010011 | opcode === 1100111) begin // I-type
        rd = data_in[11:7];
        func3 = data_in[14:12];
        rs1 = data_in[19:15];
    // Parts of these could be collapsed together
    // So logic is something like if opcode[3] is high
    // then rd, func3 and rs1 all read from the same place, skipped for now
        imm[11:0] = data_in[31:20];
    end else if (opcode === 0100011) begin // S-type
        imm[4:0] = data_in[11:7];
        func3 = data_in[14:12];
        rs1 = data_in[19:15];
        rs2 = data_in[24:20];
        imm[11:5] = data_in[31:25];
    end else if (opcode === 1100011) begin // SB-type
        imm[11] = data_in[7];
        imm[4:1] = data_in[11:8];
        func3 = data_in[14:12];
        rs1 = data_in[19:15];
        rs2 = data_in[24:20];
        imm[10:5] = data_in[30:25];
        imm[12] = data_in[31];
    end else if (opcode === 0110111 | opcode === 0010111) begin // U-type
        rd = data_in[11:7];
        imm[31:12] = data_in[31:12];
    end else if (opcode === 1101111) begin // UJ-type
        rd = data_in[11:7];
        imm[19:12] = data_in[19:12];
        imm[11] = data_in[20];
        imm[10:1] = data_in[30:21];
        imm[20] = data_in[31];
    end
end