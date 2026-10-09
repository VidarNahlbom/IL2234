module controller (
    input logic clk,
    input logic rst_n,
    input logic mem_ready,
    input logic is_branch, // decoder signal for branch instructions
    input logic branch_inv, // decoder signal, branch is taken if zero is low instead of high
    input logic alu_zero, // zero flag from the ALU, flags[0] in {overflow, negative, zero}
    input logic writes_rf, // decoder signal for if instruction writes to rf
    input logic is_load, // decoder signal for load instructions
    input logic is_store, // decoder signal for store instructions
    output logic rf_chip_en,
    output logic rf_write_en_n,
    output logic mem_addr_src, // only mux control from controller, rest are handled by decoder
    output logic mem_write_unit_en, // goes to memory write unit, not directly to memory write_en
    output logic mem_read_en,
    output logic ir_write_en,
    output logic pc_write_en,
    output logic branch_taken // to PC input mux in datapath, high selects PC+imm over the decoder PC_src
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
    // sends control signals
    //

    typedef enum logic[1:0] {Fetch, Execute1, Execute2} state_t;
    state_t current_state, next_state;

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            current_state <= Fetch;
        end else begin
            current_state <= next_state;
        end
    end

    always_comb begin
        rf_chip_en = 1'b1; // USELESS CONTROL SIGNALS SO FAR, TIED TO 1 ALWAYS
        rf_write_en_n = 1'b1;
        mem_addr_src = 1'b0;
        mem_write_unit_en = 1'b0;
        mem_read_en = 1'b0;
        ir_write_en = 1'b0;
        pc_write_en = 1'b0;
        branch_taken = 1'b0;
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
                // branches finish in this state, ALU has compared x[rs1] and x[rs2] and the result is in the zero flag
                // taken if zero is high, or if zero is low when branch_inv is set
                branch_taken = is_branch & (alu_zero ^ branch_inv);
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
