// Currently not working: Loads

module Decoder (
    input logic [31:0] data_in, // Instruction from IR
    input logic zero, // zero flag from ALU
    
    // Instruction fields
    output logic [6:0] opcode,
    output logic [11:7] rd,
    output logic [14:12] func3,
    output logic [19:15] rs1,
    output logic [24:20] rs2,
    output logic [31:25] func7, 
    output logic [31:0] imm, // sign-extended

    // Flag outputs
    output logic writes_rf, // Signifies that operation has to write to RF, defending against unknown opcodes and making branches not write to RF
    output logic is_load, // makes controller go to execute-2, mem_addr_src to 1.
    output logic is_store, // makes controller go to execute-2, among other things

    // Control signals for datapath
    output logic [1:0] rf_write_src, // 00: ALU result, 01: memory data, 10: PC+4, 11: PC+imm
    output logic ALU_b_src, // 0: RF data_out_2, 1: imm
    output logic [3:0] ALU_opcode,
    output logic [1:0] PC_src, // 00: PC+4, 01: PC+imm (JAL & branches), 10: ALU result & ~3 (JALR)
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
        writes_rf = 1'b0;
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
                writes_rf = 1'b1;
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

            // LUI: x[rd] = imm[31:12] << 12, done with the ALU PASS_B
            // This notation in the PDF is simply confusing. So as i understood the instruction shifting had to be done with ALU
            // It does not. imm[31:12] << 12 is just a very confusing way they write to mean that
            // they add on zeros on the right, making it a both bitwise and artihmetic wise larger number
            // until the number becomes a 32 bit number.
            // So imm[31:12] << 12 is just the 20 bits of imm from the instruction, and then 12 zeros added on the right.
            // So we just use pass_b to send that straight to the RF input mux. 
            OP_LUI: begin
                imm = {data_in[31:12], 12'b0}; 
                writes_rf = 1'b1;
                ALU_b_src = 1'b1;
                ALU_opcode = ALU_PASS_B;
            end

            // AUIPC: x[rd] = PC + (imm[31:12] << 12)
            // done via the RF input mux 
            // which has input PC_in
            OP_AUIPC: begin
                imm = {data_in[31:12], 12'b0};
                writes_rf = 1'b1;
                rf_write_src = 2'b11; // PC + imm from the dedicated adder
            end

            // Loads: address = rs1 + imm, data goes to rd in execute-2
            // The sign extension is handled by NOTHING, and the bit amount is handled by NOTHING
            // Currently not working then, as the previously made memory is incorrect, as it now reads only full words
            // this is not compliant with what these instructions need. 
            // MIght need a multi signal read too then, as currently it has just a single bit input
            // this would however be weird, as the previous milestone it was made in needed nothing of the sort. 
            // Most likely a new module should be used for loads, one that does both sign extenstion and zero extension
            // and also splices to correct bit length.
            OP_LOAD: begin
                imm = {{20{data_in[31]}}, data_in[31:20]};
                is_load = 1'b1; // is_load = 1 causes controller to swap mem_addr_src to 1.
                ALU_b_src = 1'b1;
                ALU_opcode = ALU_ADD; 
                rf_write_src = 2'b01; // data_out from memory
            end

            // Stores: address = rs1 + imm
            // addr sent to mem, on execute-2 mem_write has to go high so that it
            // stores x[rs2] in mem. 
            OP_STORE: begin
                imm = {{20{data_in[31]}}, data_in[31:25], data_in[11:7]};
                is_store = 1'b1; // makes mem_addr_src = 1
                ALU_b_src = 1'b1;
                ALU_opcode = ALU_ADD;
            end
            
            // Branches: ALU compares x[rs1] & x[rs2], taken path decided in datapath
            // Evaluates based on the zero flag from the ALU.
            // I dont know if its allowed for the decoder to use that flag as input
            // if it is, we only need to make it so that the PC input mux used the PC_out + imm input if zero flag is high
            // during this operation
            // If that is not allowed, we have the signal is_branch sent to controller, which will control PC_src
            // but currently PC_src is controller by decoder, so lets use the first option. 
            
            // We could use direct if statements here, so like if(!flags[2]) PC_in = PC_out + imm; 
            // By giving the decoder direct control over these things.
            // But this is not the way we have done things in other parts of the circuit
            // There we only control muxes that control the inputs to different parts
            // So to stay in life with this behaviour we will keep to just controlling a mux here too
            // But the mux behaviour and inputs has to be defined before hand
            // So the PC schematic is being redesigned to have:
            // 3 input mux: 0: PC_out + 32'd4, 1: PC_out + imm, 2: ALU_out & ~32'd3 (where ALU_out is x[rs1] + imm)
            // The addition has to be done with dedicated adders.
            // This has to be defined in the PC module later. 

            // Another option, if we want to keep "decoder" pure and only use the data_in input
            // is to have this branching logic sent signals to another little gate in the datapath that implements the same logic
            // that datapath would have to be something like 
            //assign branch_taken = is_branch & (zero ^ branch_inv);
            //assign PC_sel = branch_taken ? 2'b01 : PC_src;
            // Where is_branch is just a signal from decoder that current instruction is a branch operation
            // and branch_inv informs the gate in the datapath it the branch should be taken if the zero flag is high or low. 
            OP_BRANCH: begin
                // PDF does not describe what lowest bit should be, maybe it doesnt matter?
                // Currently assumed to be 0
                imm = {{19{data_in[31]}}, data_in[31], data_in[7], data_in[30:25], data_in[11:8], 1'b0}; // sign extended
                case (func3)
                    3'b000: begin ALU_opcode = ALU_SUB;  if ( zero) PC_src = 2'b01; end // BEQ
                    3'b001: begin ALU_opcode = ALU_SUB;  if (!zero) PC_src = 2'b01; end // BNE
                    3'b100: begin ALU_opcode = ALU_SLT;  if (!zero) PC_src = 2'b01; end // BLT
                    3'b101: begin ALU_opcode = ALU_SLT;  if ( zero) PC_src = 2'b01; end // BGE
                    3'b110: begin ALU_opcode = ALU_SLTU; if (!zero) PC_src = 2'b01; end // BLTU
                    3'b111: begin ALU_opcode = ALU_SLTU; if ( zero) PC_src = 2'b01; end // BGEU
                    default: ; // illegal: treat as no-op
                endcase
            end

            // JAL: x[rd] = PC + 4, PC = PC + imm
            // PDF does not say what imm[0] should be, assumed 0 for now
            OP_JAL: begin
                imm = {{11{data_in[31]}}, data_in[31], data_in[19:12], data_in[20], data_in[30:21], 1'b0};
                writes_rf = 1'b1;
                rf_write_src = 2'b10; // PC+4
                PC_src = 2'b01; // PC+imm
            end

            // JALR: x[rd] = PC + 4, PC = (x[rs1] + imm) & ~0b11
            // x[rs1] + imm is done via ALU, & ~0b11 via wires?
            // unsure for now
            OP_JALR: begin
                imm = {{20{data_in[31]}}, data_in[31:20]};
                writes_rf = 1'b1;
                ALU_b_src = 1'b1;
                ALU_opcode = ALU_ADD;
                rf_write_src = 2'b10; // PC+4
                PC_src = 2'b10; // ALU result & ~3
            end

            default: ; // defaults to PC += 4;
        endcase
    end
endmodule