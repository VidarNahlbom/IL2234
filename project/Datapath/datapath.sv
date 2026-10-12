module datapath (
    input logic clk,
    input logic rst_n,

    // From memory
    input logic [31:0] mem_data_out, // data read from memory (CPU data_in pin), goes to IR and memory load unit
    
    // To memory
    output logic [31:0] addr, // memory address, PC or ALU result
    output logic [31:0] mem_data_in, // data to write to memory, lanes already replicated by memory write unit
    output logic [3:0] mem_write_en, // byte-wise write mask to memory

    // From controller
    input logic rf_chip_en,
    input logic rf_write_en_n,
    input logic mem_addr_src, // mux control for memory address, 0: PC, 1: ALU result
    input logic mem_write_unit_en, // goes to memory write unit, not directly to memory write_en
    input logic ir_write_en,
    input logic pc_write_en,
    input logic [1:0] rf_write_src, // To RF input mux, 00: ALU result, 01: memory data, 10: PC+4, 11: PC+imm
    input logic alu_b_src, // 0: RF data_out_2, 1: imm
    input logic [3:0] alu_opcode, // To ALU, decides ALU operation
    input logic [1:0] pc_src, // To PC input mux, 00: PC+4, 01: PC+imm (JAL & taken branches), 10: ALU result & ~3 (JALR)

    // To controller
    output logic [6:0] opcode,
    output logic [2:0] func3, // also goes to memory load and write units
    output logic [6:0] func7,
    output logic alu_zero // zero flag from the ALU

);
    // internal signals
    logic [31:0] ir_out; // instruction from IR to decoder
    logic [4:0] rd;
    logic [4:0] rs1;
    logic [4:0] rs2;
    logic [31:0] imm;
    logic [31:0] rf_data_in; // output of RF input mux
    logic [31:0] rf_data_out_1;
    logic [31:0] rf_data_out_2;
    logic [31:0] in_a; // ALU inputs
    logic [31:0] in_b;
    logic [31:0] alu_out;
    logic [2:0] alu_flags; // {overflow, negative, zero}
    logic [31:0] load_data; // formatted data from memory load unit
    logic [31:0] pc_out;
    logic [31:0] pc_plus_4;
    logic [31:0] pc_plus_imm;
 
    ALU #(.BW(32)) alu_inst (
        .in_a(in_a),
        .in_b(in_b),
        .opcode(alu_opcode),
        .out(alu_out),
        .flags(alu_flags)
    );
 
    Decoder decoder_inst (
        .data_in(ir_out),
        .opcode(opcode),
        .rd(rd),
        .func3(func3),
        .rs1(rs1),
        .rs2(rs2),
        .func7(func7),
        .imm(imm)
    );
 
    instruction_register ir_inst (
        .clk(clk),
        .rst_n(rst_n),
        .ir_write_en(ir_write_en),
        .ir_in(mem_data_out), // straight from memory, not through load unit
        .ir_out(ir_out)
    );
 
    memory_load_unit mem_load_unit_inst (
        .mem_data(mem_data_out),
        .addr_lo(addr[1:0]),
        .func3(func3),
        .load_data(load_data)
    );
 
    memory_write_unit mem_write_unit_inst (
        .mem_write(mem_write_unit_en),
        .addr_lo(addr[1:0]),
        .func3(func3),
        .rs2_data(rf_data_out_2),
        .data_out(mem_data_in),
        .write_en(mem_write_en)
    );
 
    program_counter pc_inst (
        .clk(clk),
        .rst_n(rst_n),
        .pc_write_en(pc_write_en),
        .pc_src(pc_src),
        .imm(imm),
        .alu_out(alu_out),
        .pc_out(pc_out),
        .pc_plus_4(pc_plus_4),
        .pc_plus_imm(pc_plus_imm)
    );
 
    register_file #(.BW(32), .DEPTH(32)) rf_inst (
        .clk(clk),
        .rst_n(rst_n),
        .write_en_n(rf_write_en_n),
        .chip_en(rf_chip_en),
        .data_in(rf_data_in),
        .read_addr_1(rs1),
        .read_addr_2(rs2),
        .write_addr(rd),
        .data_out_1(rf_data_out_1),
        .data_out_2(rf_data_out_2)
    );
 
    // ALU input a is always x[rs1], AUIPC uses the PC+imm adder instead
    assign in_a = rf_data_out_1;
 
    // ALU input b mux, 0: x[rs2], 1: imm
    assign in_b = alu_b_src ? imm : rf_data_out_2;
 
    // Memory address mux, 0: PC (fetch), 1: ALU result (loads and stores in execute-2)
    assign addr = mem_addr_src ? alu_out : pc_out;
 
    // RF input mux
    always_comb begin
        case (rf_write_src)
            2'b00: rf_data_in = alu_out; // ALU result
            2'b01: rf_data_in = load_data; // memory data, through load unit
            2'b10: rf_data_in = pc_plus_4; // JAL & JALR
            2'b11: rf_data_in = pc_plus_imm; // AUIPC
            default: rf_data_in = alu_out;
        endcase
    end
 
    // Zero flag to controller, used for branches
    assign alu_zero = alu_flags[0];

endmodule


