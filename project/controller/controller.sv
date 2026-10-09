module controller (
    input logic clk,
    input logic rst_n,
    input logic mem_ready,
    input logic [6:0] opcode, // decoder signal, instruction type
    input logic [2:0] func3, // decoder signal, instruction operation within type
    input logic [6:0] func7, // decoder signal, only func7[5] is used (SUB/SRA)
    input logic alu_zero, // zero flag from the ALU, flags[0] in {overflow, negative, zero}
    output logic rf_chip_en,
    output logic rf_write_en_n,
    output logic mem_addr_src, // mux control for memory address, 0: PC, 1: ALU result
    output logic mem_write_unit_en, // goes to memory write unit, not directly to memory write_en
    output logic mem_read_en,
    output logic ir_write_en,
    output logic pc_write_en,
    output logic [1:0] rf_write_src, // To RF input mux, 00: ALU result, 01: memory data, 10: PC+4, 11: PC+imm
    output logic alu_b_src, // 0: RF data_out_2, 1: imm
    output logic [3:0] alu_opcode, // To ALU, decides ALU operation
    output logic [1:0] pc_src // To PC input mux, 00: PC+4, 01: PC+imm (JAL & taken branches), 10: ALU result & ~3 (JALR)
);
    // Order of operations:
    // PC is at addr 0x
    // Send that addr to mem
    // mem reads data at addr 0x
    // sends that data directly to instruction register (not through mem load unit)
    // we have ir_write_en = mem_ready
    // so it reads instruction once data is valid
    // controller goes to execute1
    // decoder decodes instruction
    // controller reads opcode, func3 and func7 and sends control signals
    //

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

    // internal signals
    // Mostly redundant or can be programmed out, but here because or carry over from earlier logic iterations
    // where decoder sent these signals to the controller
    logic writes_rf; // Signifies that operation has to write to RF, defending against unknown opcodes and making branches not write to RF
    logic is_load; // makes controller go to execute-2, mem_addr_src to 1.
    logic is_store; // makes controller go to execute-2, among other things
    logic is_branch; // enables branching logic
    logic branch_inv; // Makes it so that the branch is taken if zero is low, instead of high

    typedef enum logic[1:0] {Fetch, Execute1, Execute2} state_t;
    state_t current_state, next_state;

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            current_state <= Fetch;
        end else begin
            current_state <= next_state;
        end
    end

    // Instruction control signals, depend only on the instruction (and zero flag for branches)
    // so they are held steady in all states while the instruction is in the IR
    always_comb begin
        // Defaults
        writes_rf = 1'b0;
        is_branch = 1'b0;
        is_load = 1'b0;
        is_store = 1'b0;
        alu_b_src = 1'b0;
        branch_inv = 1'b0;
        alu_opcode = 4'b0000;
        rf_write_src = 2'b00;
        pc_src = 2'b00; 

        case (opcode)
        
            // R-type & I-type
            // Differ only in ALU b input and SUB operation
            OP_R, OP_I: begin
                writes_rf = 1'b1;
                alu_b_src = (opcode == OP_I);

                case (func3)
                    3'b000: begin
                        // ADDI has no SUB form, only R-type uses func7[5] here
                        if (opcode == OP_R && func7[5]) alu_opcode = ALU_SUB;
                        else alu_opcode = ALU_ADD;
                    end
                    3'b001: alu_opcode = ALU_SLL;
                    3'b010: alu_opcode = ALU_SLT;
                    3'b011: alu_opcode = ALU_SLTU;
                    3'b100: alu_opcode = ALU_XOR;
                    3'b101: alu_opcode = func7[5] ? ALU_SRA : ALU_SRL; // SRL/SRA, SRLI/SRAI
                    3'b110: alu_opcode = ALU_OR;
                    3'b111: alu_opcode = ALU_AND;
                    default: alu_opcode = ALU_ADD;
                endcase
            end

            // LUI: x[rd] = imm[31:12] << 12, done with the ALU PASS_B
            // imm from the decoder is already shifted, so we just use pass_b to send that straight to the RF input mux. 
            OP_LUI: begin
                writes_rf = 1'b1;
                alu_b_src = 1'b1;
                alu_opcode = ALU_PASS_B;
            end

            // AUIPC: x[rd] = PC + (imm[31:12] << 12)
            // done via the RF input mux 
            // which has input PC_in
            OP_AUIPC: begin
                writes_rf = 1'b1;
                rf_write_src = 2'b11; // PC + imm from the dedicated adder
            end

            // Loads: address = rs1 + imm, data goes to rd in execute-2
            // The sign extension and bit amount is handled by memory_load_unit
            OP_LOAD: begin
                is_load = 1'b1;
                writes_rf = 1'b1;
                alu_b_src = 1'b1;
                alu_opcode = ALU_ADD; 
                rf_write_src = 2'b01; // data_out from memory
            end

            // Stores: address = rs1 + imm
            // addr sent to mem, on execute-2 mem_write has to go high so that it
            // stores x[rs2] in mem. 
            OP_STORE: begin
                is_store = 1'b1; // makes mem_addr_src = 1
                alu_b_src = 1'b1;
                alu_opcode = ALU_ADD;
            end
            
            // Branches: ALU compares x[rs1] & x[rs2], result is in the zero flag
            // Branch is taken if zero is high, or if zero is low when branch_inv is set
            // Taken branches load PC + imm
            OP_BRANCH: begin
                is_branch = 1'b1;
                case (func3)
                    3'b000: begin alu_opcode = ALU_SUB; branch_inv = 1'b0; end // BEQ
                    3'b001: begin alu_opcode = ALU_SUB; branch_inv = 1'b1; end // BNE
                    3'b100: begin alu_opcode = ALU_SLT; branch_inv = 1'b1; end // BLT
                    3'b101: begin alu_opcode = ALU_SLT; branch_inv = 1'b0; end // BGE
                    3'b110: begin alu_opcode = ALU_SLTU; branch_inv = 1'b1; end // BLTU
                    3'b111: begin alu_opcode = ALU_SLTU; branch_inv = 1'b0; end // BGEU
                    default: is_branch = 1'b0; // illegal: treat as no-op
                endcase
                if (is_branch & (alu_zero ^ branch_inv)) pc_src = 2'b01;
            end

            // JAL: x[rd] = PC + 4, PC = PC + imm
            OP_JAL: begin
                writes_rf = 1'b1;
                rf_write_src = 2'b10; // PC+4
                pc_src = 2'b01; // PC+imm
            end

            // JALR: x[rd] = PC + 4, PC = (x[rs1] + imm) & ~0b11
            // x[rs1] + imm is done via ALU, & ~0b11 via wires?
            // unsure for now
            OP_JALR: begin
                writes_rf = 1'b1;
                alu_b_src = 1'b1;
                alu_opcode = ALU_ADD;
                rf_write_src = 2'b10; // PC+4
                pc_src = 2'b10; // ALU result & ~3
            end

            default: ; // defaults to PC += 4;
        endcase
    end

    always_comb begin
        rf_chip_en = 1'b1; // USELESS CONTROL SIGNALS SO FAR, TIED TO 1 ALWAYS
        rf_write_en_n = 1'b1;
        mem_addr_src = 1'b0;
        mem_write_unit_en = 1'b0;
        mem_read_en = 1'b0;
        ir_write_en = 1'b0;
        pc_write_en = 1'b0;
        next_state = Fetch;

        case (current_state)
            Fetch: begin
                mem_addr_src = 1'b0; // make mem read PC addr
                mem_read_en = 1'b1; // enable reading from mem
                ir_write_en = mem_ready;
                if (mem_ready) next_state = Execute1;
            end
            Execute1: begin
                // if its a memory operation we need to wait for ALU to finish
                // 1 calculation atleast, in x[rs1] + imm, but all other instruction
                // use RF same cycle. 
                rf_write_en_n = ~(writes_rf & ~is_load); // if it is writing to RF and isnt a load, this sets it to 0 (enabled), otherwise we write in execute2
                pc_write_en = ~(is_store | is_load); // if its not a mem operation, we go to next instruction next state
                if (is_store | is_load) next_state = Execute2;
            end
            Execute2: begin
                mem_write_unit_en = is_store;
                mem_read_en = is_load;
                mem_addr_src = 1'b1;
                pc_write_en = mem_ready;
                rf_write_en_n = ~(is_load & mem_ready); // only write to RF if its load and mem has output valid data
                if (!mem_ready) next_state = Execute2; // loop until mem_ready to go back to Fetch
            end
            default: next_state = Fetch; // redundant but here for readability and linting
        endcase
    end
endmodule
