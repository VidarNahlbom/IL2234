`timescale 1ns/1ps

// Hierarchical paths inside riscv_top
`define PC        dut.cpu_top_inst.datapath_inst.pc_inst.pc_out
`define MEM_ADDR  dut.mem_cont_inst.addr
`define MEM_DATA  dut.mem_cont_inst.data_in
`define MEM_WE    dut.mem_cont_inst.write_en

module riscv_top_tb;

    logic clk;
    logic rst_n;

    riscv_top dut (
        .clk(clk),
        .rst_n(rst_n)
    );
    
    // Generate clock: 10 ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // Remember the latest write seen on the memory bus
    logic [15:0] last_addr;
    logic [31:0] last_data;

    always @(posedge clk) begin
        if (|`MEM_WE) begin
            last_addr <= `MEM_ADDR;
            last_data <= `MEM_DATA;
        end
    end

    int cycles;

    initial begin
        $display("================================");
        $display(" TEST 1: System top test with course firmware");
        $display("================================");

        // Hold reset for a few clock edges so everything sees it
        rst_n = 1'b0;
        repeat (3) @(posedge clk);
        #1 rst_n = 1'b1;

        // Program is done when the PC reaches the final loop at 0xC4
        cycles = 0;
        while (`PC !== 32'h000000C4 && cycles < 100000) begin
            @(posedge clk);
            cycles++;
        end
        repeat (2) @(posedge clk);

        if (cycles >= 100000) begin
            $display("FAIL: timeout, PC = %08h", `PC);
        end else begin
            $display("Program finished after %0d cycles", cycles);
            // sum of 0..99 = 4950+25 from counter already, the final store goes to address 0xA000
            if (last_addr === 16'ha000 && last_data === 32'd4975)
                $display("PASS: wrote %0d to 0x%04h", last_data, last_addr);
            else
                $display("FAIL: last write was 0x%08d to 0x%04h, expected 4975 to 0xa000", last_data, last_addr);
        end

        $finish;
    end
endmodule