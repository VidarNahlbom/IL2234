module Decoder (
    input logic [31:0] data_in, // Instruction from IR
    
    // Instruction fields
    output logic [6:0] opcode, // to controller
    output logic [11:7] rd, // to RF write_addr
    output logic [14:12] func3, // to controller, memory write and read units
    output logic [19:15] rs1, // to RF read_addr_1
    output logic [24:20] rs2, // to RF read_addr_2
    output logic [31:25] func7, // to controller
    output logic [31:0] imm // sign-extended, to ALU b input mux and PC adder
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

    // Instruction slicing
    assign opcode = data_in[6:0];
    assign rd = data_in[11:7];
    assign func3 = data_in[14:12];
    assign rs1 = data_in[19:15];
    assign rs2 = data_in[24:20];
    assign func7 = data_in[31:25];

    // The decoder only splits the instruction and builds the immediate
    always_comb begin
        // Defaults
        imm = 32'b0;

        case (opcode)
        
            // I-type:
            // I-type, loads and JALR all have the same immediate format
            // R-type has no immediate, so imm is unused for it
            OP_I, OP_LOAD, OP_JALR: begin
                imm = {{20{data_in[31]}}, data_in[31:20]}; // sign-extended
            end

            // U-type:
            // LUI & AUIPC: imm[31:12] << 12
            // This notation in the PDF is simply confusing. So as i understood the instruction shifting had to be done with ALU
            // It does not. imm[31:12] << 12 is just a very confusing way they write to mean that
            // they add on zeros on the right, making it a both bitwise and artihmetic wise larger number
            // until the number becomes a 32 bit number.
            // So imm[31:12] << 12 is just the 20 bits of imm from the instruction, and then 12 zeros added on the right.
            OP_LUI, OP_AUIPC: begin
                imm = {data_in[31:12], 12'b0}; 
            end

            // S-type
            // Stores: imm is split in the instruction, rs2 is not part of it
            OP_STORE: begin
                imm = {{20{data_in[31]}}, data_in[31:25], data_in[11:7]};
            end
            
            // SB-type
            // Branches
            OP_BRANCH: begin
                // PDF does not describe what lowest bit should be, maybe it doesnt matter?
                // Currently assumed to be 0
                imm = {{19{data_in[31]}}, data_in[31], data_in[7], data_in[30:25], data_in[11:8], 1'b0}; // sign extended
            end

            // UJ-type
            // JAL
            // PDF does not say what imm[0] should be, assumed 0 for now
            OP_JAL: begin
                imm = {{11{data_in[31]}}, data_in[31], data_in[19:12], data_in[20], data_in[30:21], 1'b0};
            end

            default: ; // unknown opcode or opcode where imm stays 0
        endcase
    end
endmodule
