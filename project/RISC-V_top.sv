module riscv_top (
    input logic clk,
    input logic rst_n
);
    logic [31:0] cpu_data_in;
    logic mem_ready;
    logic [31:0] addr;
    logic [31:0] cpu_data_out;
    logic [3:0] write_en;
    logic read_en;

    cpu_top cpu_top_inst(
        .clk(clk),
        .rst_n(rst_n),
        .data_in(cpu_data_in),
        .mem_ready(mem_ready),
        .addr(addr),
        .data_out(cpu_data_out),
        .write_en(write_en),
        .read_en(read_en)
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