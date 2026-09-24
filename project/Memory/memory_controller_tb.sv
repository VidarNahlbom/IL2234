`timescale 1ns / 1ps

module memory_controller_tb;

    logic        clk;
    logic        rst_n;
    logic [15:0] addr;
    logic [31:0] data_in;
    logic [31:0] data_out;
    logic [3:0]  write_en;
    logic        read_en;
    logic        mem_ready;

    // Instantiate DUT
    memory_controller dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .addr      (addr),
        .data_in   (data_in),
        .data_out  (data_out),
        .write_en  (write_en),
        .read_en   (read_en),
        .mem_ready (mem_ready)
    );

    // Clock generation: 10ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // Cycle counter, just for readable log timestamps
    int cycle_count;
    always @(posedge clk) cycle_count <= cycle_count + 1;

    // ---------------------------------------------------------------
    // Helper task: pulse a request for one cycle, then wait and count
    // how many clock edges pass until mem_ready goes high.
    // ---------------------------------------------------------------
    task automatic measure_latency(
        input string      op_name,
        input logic [15:0] t_addr,
        input logic [31:0] t_data,
        input logic [3:0]  t_write_en,
        input logic        t_read_en
    );
        int latency;
        begin
            // Drive the request on this rising edge
            @(negedge clk); // change inputs away from the clock edge
            addr      = t_addr;
            data_in   = t_data;
            write_en  = t_write_en;
            read_en   = t_read_en;

            @(posedge clk); // request is now sampled by the FSM
            $display("[%0t] %s request issued: addr=%0d write_en=%b read_en=%b",
                       $time, op_name, t_addr, t_write_en, t_read_en);

            // Deassert request lines after one cycle, so we only measure
            // the latency of this single request, not a held/continuous one
            @(negedge clk);
            read_en  = 1'b0;
            write_en = 4'b0000;

            latency = 0;
            while (mem_ready !== 1'b1) begin
                @(posedge clk);
                latency++;
                if (latency > 20) begin
                    $display("[%0t] %s: mem_ready never asserted after 20 cycles - aborting", $time, op_name);
                    disable measure_latency;
                end
            end

            $display("[%0t] %s: mem_ready asserted after %0d cycle(s). data_out=%0d",
                       $time, op_name, latency, data_out);
        end
    endtask

    initial begin
        // Init
        rst_n     = 0;
        addr      = '0;
        data_in   = '0;
        write_en  = '0;
        read_en   = 1'b0;
        cycle_count = 0;

        // Hold reset for a few cycles
        repeat (3) @(posedge clk);
        rst_n = 1;
        @(negedge clk);

        $display("\n=== Measuring WRITE latency ===");
        measure_latency("WRITE", 16'h0010, 32'hAABBCCDD, 4'b1111, 1'b1);

        // Give a gap cycle before next op so waveforms are easy to read
        repeat (2) @(posedge clk);

        $display("\n=== Measuring READ latency ===");
        measure_latency("READ", 16'h0010, 32'h0, 4'b0000, 1'b1);

        repeat (2) @(posedge clk);

        $display("\n=== Measuring BYTE WRITE latency (single byte) ===");
        measure_latency("BYTE_WRITE", 16'h0020, 32'h000000FF, 4'b0001, 1'b1);

        repeat (2) @(posedge clk);

        $display("\n=== Measuring READ-after-BYTE-WRITE (check byte lanes) ===");
        measure_latency("READ_CHECK", 16'h0020, 32'h0, 4'b0000, 1'b1);

        repeat (5) @(posedge clk);

        $display("\n=== Testbench finished ===");
        $finish;
    end

    // Optional: dump waves for visual inspection in Vivado simulator
    initial begin
        $dumpfile("memory_controller_tb.vcd");
        $dumpvars(0, memory_controller_tb);
    end

endmodule
