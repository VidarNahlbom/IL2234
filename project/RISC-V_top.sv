module riscv_top (
    input logic clk,
    input logic rst_n,
    output logic [31:0] pc_debug,
    output logic [31:0] mem_debug_data,
    output logic [3:0] mem_debug_write,
    output logic read_en_debug,
    output logic mem_ready_debug
//    output logic pc_write_en_debug
);
    logic [31:0] cpu_data_in;
    logic mem_ready;
    logic [31:0] addr;
    logic [31:0] cpu_data_out;
    logic [3:0] write_en;
    logic read_en;
    
    assign mem_debug_data = cpu_data_out;
    assign mem_debug_write = write_en;
    assign read_en_debug = read_en;
    assign mem_ready_debug = mem_ready;

    cpu_top cpu_top_inst (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(cpu_data_in),
        .mem_ready(mem_ready),
        .addr(addr),
        .data_out(cpu_data_out),
        .write_en(write_en),
        .read_en(read_en),
//        .pc_write_en_debug(pc_write_en_debug),
        .pc_debug(pc_debug)
    );

    // Memory only has 16 address bits (64 KiB), upper CPU address bits are unused
    memory_controller mem_cont_inst (
        .clk(clk),
        .rst_n(rst_n),
        .addr(addr[15:0]),
        .data_in(cpu_data_out),
        .data_out(cpu_data_in),
        .write_en(write_en),
        .read_en(read_en),
        .mem_ready(mem_ready)
    );
endmodule