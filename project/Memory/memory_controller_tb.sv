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
        .read_en   (read_en || |write_en),
        .mem_ready (mem_ready)
    );

    // Clock generation: 10ns period
    initial clk = 0;
    always #5 clk = ~clk;
    
    always @(posedge clk) begin
    $display("[cyc t=%0t] sram: ena=%b wea=%b addra=%0d dina=%h",
               $time, dut.sram_inst.ena, dut.sram_inst.wea,
               dut.sram_inst.addra, dut.sram_inst.dina);
    end

    initial begin
        // Init
        rst_n = 0;
        addr = '0;
        data_in = '0;
        write_en = '0;
        read_en = 1'b0;

        @(posedge clk);
        rst_n = 1;
        @(negedge clk);

        $display("=== SRAM Testbench ===");

        $display("\n--- Test 1: Full word write to addr 0x0110 ---");
        @(negedge clk);
        write_en = 4'b1111;
        addr = 16'h0110;
        data_in = 32'haabbccdd;

        @(posedge clk);
        write_en = 4'b0000;
        addr = 16'h0011;
        data_in = 32'h000000aa;

        repeat (2) @(posedge clk);

        $display("--- Test 2: Read back addr 0x0110, expect aabbccdd ---");
        @(negedge clk);
        read_en = 1'b1;
        addr = 16'h0110;

        @(posedge clk);
        #1;
        if (data_out === 32'haabbccdd) begin
            $display("PASS: data_out = %h", data_out);
        end else begin
            $display("FAIL: expected aabbccdd, got %h", data_out);
        end

        @(negedge clk);
        read_en = 1'b0;
        
        $display("\n--- Test 3: Byte-wise write - only byte 1 (bits 15:8) of addr 0x0110 ---");
        @(negedge clk);
        write_en = 4'b0010; 
        addr = 16'h0110;
        data_in = 32'h00ff0fff; // Should only care about stuff in parenthesis: 00ff(0f)ff

        @(posedge clk);
        write_en = 4'b0000; // With this, the enable signal to the chip goes low
        // so we also check if its still able to write.

        $display("--- Test 4: Read back addr 0x0110, expect only byte 1 changed (aabb0fdd) ---");
        @(negedge clk);
        read_en = 1'b1;

        @(posedge clk);
        #1;
        if (data_out === 32'haabb0fdd) begin
            $display("PASS: data_out = %h", data_out);
        end else begin
            $display("FAIL: expected aabb0fdd, got %h", data_out);
        end
        
        @(negedge clk);
        read_en = 1'b0;

        $display("\n--- Test 5: Write to a different address ---");
        @(negedge clk);
        write_en = 4'b1111;
        addr = 16'h0020;
        data_in = 32'h11223344;

        @(posedge clk);
        @(negedge clk);
        write_en = 4'b0000;
        data_in = '0;

        $display("--- Test 6: Read addr 0x0110 again ---");
        @(negedge clk);
        read_en = 1'b1;
        addr = 16'h0110;

        @(posedge clk);
        #1;
        if (data_out === 32'haabb0fdd) begin
            $display("PASS: addr 0x0110 unaffected, data_out = %h", data_out);
        end else begin
            $display("FAIL: addr 0x0110 was corrupted, got %h", data_out);
        end

        @(negedge clk);
        read_en = 1'b0;

        $display("--- Test 7: Read addr 0x0020, expect 11223344 ---");
        @(negedge clk);
        read_en = 1'b1;
        addr = 16'h0020;

        @(posedge clk);
        #1;
        if (data_out === 32'h11223344) begin
            $display("PASS: data_out = %h", data_out);
        end else begin
            $display("FAIL: expected 11223344, got %h", data_out);
        end

        @(negedge clk);
        read_en = 1'b0;

        $display("\n--- Test 8: mem_ready timing check - should be high exactly one cycle after request ---");
        @(negedge clk);
        read_en = 1'b1;
        addr = 16'h0020;
        if (mem_ready !== 1'b0) begin
            $display("FAIL: mem_ready asserted too early (before request even sampled)");
        end

        @(posedge clk);
        #1;
        if (mem_ready === 1'b1) begin
            $display("PASS: mem_ready high on expected cycle");
        end else begin
            $display("FAIL: mem_ready not high when expected, mem_ready=%b", mem_ready);
        end

        @(negedge clk);
        read_en = 1'b0;

        $display("\n--- Test 9: Back-to-back writes without a gap cycle ---");
        @(negedge clk);
        write_en = 4'b1111;
        addr = 16'h0030;
        data_in = 32'hcdcdcdcd;
        @(posedge clk);
 
        @(negedge clk);
        addr = 16'h0031;
        data_in = 32'habababab;
        @(posedge clk);
 
        @(negedge clk);
        write_en = 4'b0000;
 
        $display("--- Test 10: Verify both back-to-back writes ---");
        @(negedge clk);
        read_en = 1'b1;
        addr = 16'h0030;

        @(posedge clk);
        #1;
        if (data_out === 32'hcdcdcdcd) begin
            $display("PASS: addr 0x0030 = %h", data_out);
        end else begin
            $display("FAIL: addr 0x0030 expected cdcdcdcd, got %h", data_out);
        end

        @(negedge clk);
        addr = 16'h0031;
        @(posedge clk);
        #1;
        if (data_out === 32'habababab) begin
            $display("PASS: addr 0x0031 = %h", data_out);
        end else begin
            $display("FAIL: addr 0x0031 expected abababab, got %h", data_out);
        end

        @(negedge clk);
        read_en = 1'b0;
 
        repeat (3) @(posedge clk);
        $display("\n=== Testbench finished ===");


        $finish;
    end

endmodule
