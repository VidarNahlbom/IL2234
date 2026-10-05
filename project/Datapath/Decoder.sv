module Decoder (
    input logic [31:0] data_in, // Instruction from IR
    
    // Instruction fields
    output logic [6:0] opcode,
    output logic [11:7] rd,
    output logic [14:12] func3,
    output logic [19:15] rs1,
    output logic [24:20] rs2,
    output logic [31:25] func7, 
    output logic [31:0] imm, // sign-extended

    // Flag outputs
    output logic is_load,
    output logic is_store,

    // Control signals for datapath
    output logic [1:0] rf_write_src, // 00: ALU result, 01: memory data, 10: PC+4
    output logic ALU_b_src, // 0: RF data_out_2, 1: imm
    output logic [3:0] ALU_opcode,
    output logic [1:0] PC_src, // 00: PC+4, 01: PC+imm (JAL), 10: ALU result & ~3 (JALR)
);
    // Opcodes
    localparam logic [6:0] OP_R      = 7'b0110011;
    localparam logic [6:0] OP_I      = 7'b0010011;
    localparam logic [6:0] OP_LOAD   = 7'b0000011;
    localparam logic [6:0] OP_STORE  = 7'b0100011;
    localparam logic [6:0] OP_BRANCH = 7'b1100011;
    localparam logic [6:0] OP_LUI    = 7'b0110111;
    localparam logic [6:0] OP_AUIPC  = 7'b0010111;
    localparam logic [6:0] OP_JAL    = 7'b1101111;
    localparam logic [6:0] OP_JALR   = 7'b1100111;

    // ALU opcodes
    localparam logic [3:0] ALU_ADD    = 4'b0000;
    localparam logic [3:0] ALU_SUB    = 4'b0001;
    localparam logic [3:0] ALU_SLL    = 4'b0010;
    localparam logic [3:0] ALU_SLT    = 4'b0100;
    localparam logic [3:0] ALU_SLTU   = 4'b0110;
    localparam logic [3:0] ALU_XOR    = 4'b1000;
    localparam logic [3:0] ALU_SRL    = 4'b1010;
    localparam logic [3:0] ALU_SRA    = 4'b1011;
    localparam logic [3:0] ALU_OR     = 4'b1100;
    localparam logic [3:0] ALU_AND    = 4'b1110;
    localparam logic [3:0] ALU_PASS_B = 4'b1111;

    // Instruction slicing
    assign opcode = data_in[6:0];
    assign rd = data_in[11:7];
    assign func3 = data_in[14:12];
    assign rs1 = data_in[19:15];
    assign rs2 = data_in[24:20];
    assign func7 = data_in[31:25];

    always_comb begin
        // Defaults
        imm = 32'b0;
        is_load = 1'b0;
        is_store = 1'b0;
        ALU_b_src = 1'b0;
        ALU_opcode = 4'b0000;
        rf_write_src = 2'b00;
        PC_src = 2'b00; 

        case (opcode)
        
            // R-type & I-type
            // Differ only in ALU b input and SUB operation
            OP_R, OP_I: begin
                ALU_b_src = (opcode == OP_I);
                imm = {{20{data_in[31]}}, data_in[31:20]}; // sign-extended

                case (func3)
                    3'b000: begin
                        // ADDI has no SUB form, only R-type uses func7[5] here
                        if (opcode == OP_R && func7[5]) ALU_opcode = ALU_SUB;
                        else ALU_opcode = ALU_ADD;
                    end
                    3'b001: ALU_opcode = ALU_SLL;
                    3'b010: ALU_opcode = ALU_SLT;
                    3'b011: ALU_opcode = ALU_SLTU;
                    3'b100: ALU_opcode = ALU_XOR;
                    3'b101: ALU_opcode = func7[5] ? ALU_SRA : ALU_SRL; // SRL/SRA, SRLI/SRAI
                    3'b110: ALU_opcode = ALU_OR;
                    3'b111: ALU_opcode = ALU_AND;
                    default: ALU_opcode = ALU_ADD;
                endcase
            end

            // Loads: address = rs1 + imm, data goes to rd in execute-2
            OP_LOAD: begin
                imm = {{20{data_in[31]}}, data_in[31:20]};
                is_load = 1'b1;
                ALU_b_src = 1'b1;
                ALU_opcode = ALU_ADD;
                rf_write_src = 2'b01; // data_out from memory
            end

            // Stores: address = rs1 + imm
            OP_STORE: begin
                imm = {{20{data_in[31]}}, data_in[31:25], data_in[11:7]};
                is_store = 1'b1;
                ALU_b_src = 1'b1;
                ALU_opcode = ALU_ADD;
            end
            
            // Branches: ALU compares x[rs1] & x[rs2], taken decided in datapath
            OP_BRANCH: begin
                imm = {{19{data_in[31]}}, data_in[31], data_in[7], data_in[30:25], data_in[11:8], 1'b0};
                ALU_b_src = 1'b0;
                case (func3)
                    3'b000: begin ALU_opcode = ALU_SUB;  branch_inv = 1'b0; end // BEQ  taken if zero
                    3'b001: begin ALU_opcode = ALU_SUB;  branch_inv = 1'b1; end // BNE  taken if !zero
                    3'b100: begin ALU_opcode = ALU_SLT;  branch_inv = 1'b1; end // BLT  taken if result=1
                    3'b101: begin ALU_opcode = ALU_SLT;  branch_inv = 1'b0; end // BGE  taken if result=0
                    3'b110: begin ALU_opcode = ALU_SLTU; branch_inv = 1'b1; end // BLTU
                    3'b111: begin ALU_opcode = ALU_SLTU; branch_inv = 1'b0; end // BGEU
                    default: is_branch = 1'b0;                                  // illegal: treat as no-op
                endcase
            end

            // JAL: x[rd] = PC + 4, PC = PC + imm
            OP_JAL: begin
                // SUPER WEIRD THIS ONE, PDF HAS NO DESCRIPTION OF WHAT LOWEST VALUE SHOULD BE
                imm = {{11{data_in[31]}}, data_in[31], data_in[19:12], data_in[20], data_in[30:21], 1'b0};
                rf_write_src = 2'b10; // PC+4
                PC_src = 2'b01; // PC+imm
            end

            // JALR: x[rd] = PC + 4, PC = (x[rs1] + imm) & ~0b11
            OP_JALR: begin
                imm = {{20{data_in[31]}}, data_in[31:20]};
                writes_rd = 1'b1;
                ALU_b_src = 1'b1;
                ALU_opcode = ALU_ADD;
                rf_write_src = 2'b10; // PC+4
                PC_src = 2'b10; // ALU result & ~3
            end

            // LUI: x[rd] = imm[31:12] << 12, done with the ALU PASS_B
            OP_LUI: begin
                imm = {data_in[31:12], 12'b0};
                // DONT UNDERSTAND THIS ONE
                // HOW TO DO THE LEFT SHIFT? 
                // DO WE JUST PUT IMM DATA TO THE LOWER 12 BITS INSTEAD THE UPPER BITS LIKE NOW?
                ALU_b_src = 1'b1;
                rf_write_src = 2'b00;
                ALU_opcode = ALU_PASS_B;
            end

            // AUIPC: x[rd] = PC + (imm[31:12] << 12)
            // NOT POSSIBLE CURRENTLY, NEED TO CHANGE A INPUT SO NEED TO CHANGE SCHEMATIC
            OP_AUIPC: begin
                imm = {data_in[31:12], 12'b0};
                writes_rd = 1'b1;
                ALU_a_src = 1'b1; // PC
                ALU_b_src = 1'b1; // imm
                ALU_opcode = ALU_ADD; // SHIFT?
            end

            default: ; // defaults to PC += 4;
        endcase
    end
endmodule