module cpu_top (
    input logic clk,
    input logic rst_n,

    // Memory interface (from cpu perspective)
    input logic [31:0] data_in, // data read from memory
    input logic mem_ready, // memory access (read or write) is complete
    output logic [31:0] addr, // memory address, lower two bits used by memory write unit
    output logic [31:0] data_out, // data to write to memory
    output logic [3:0] write_en, // byte-wise write mask
    output logic read_en
);

    // Controller to datapath
    logic rf_chip_en;
    logic rf_write_en_n;
    logic mem_addr_src;
    logic mem_write_unit_en;
    logic ir_write_en;
    logic pc_write_en;
    logic [1:0] rf_write_src;
    logic alu_b_src;
    logic [3:0] alu_opcode;
    logic [1:0] pc_src;

    // Datapath to controller
    logic [6:0] opcode;
    logic [2:0] func3;
    logic [6:0] func7;
    logic alu_zero;

    controller controller_inst (
        .clk(clk),
        .rst_n(rst_n),
        .mem_ready(mem_ready),
        .opcode(opcode),
        .func3(func3),
        .func7(func7),
        .alu_zero(alu_zero),
        .rf_chip_en(rf_chip_en),
        .rf_write_en_n(rf_write_en_n),
        .mem_addr_src(mem_addr_src),
        .mem_write_unit_en(mem_write_unit_en),
        .mem_read_en(read_en), // goes straight to the CPU pin, datapath does not need it
        .ir_write_en(ir_write_en),
        .pc_write_en(pc_write_en),
        .rf_write_src(rf_write_src),
        .alu_b_src(alu_b_src),
        .alu_opcode(alu_opcode),
        .pc_src(pc_src)
    );

    datapath datapath_inst (
        .clk(clk),
        .rst_n(rst_n),
        .mem_data_out(data_in), // memory output is the CPU data_in
        .rf_chip_en(rf_chip_en),
        .rf_write_en_n(rf_write_en_n),
        .mem_addr_src(mem_addr_src),
        .mem_write_unit_en(mem_write_unit_en),
        .ir_write_en(ir_write_en),
        .pc_write_en(pc_write_en),
        .rf_write_src(rf_write_src),
        .alu_b_src(alu_b_src),
        .alu_opcode(alu_opcode),
        .pc_src(pc_src),
        .addr(addr),
        .mem_data_in(data_out), // memory input is the CPU data_out
        .mem_write_en(write_en),
        .opcode(opcode),
        .func3(func3),
        .func7(func7),
        .alu_zero(alu_zero)
    );

endmodule
