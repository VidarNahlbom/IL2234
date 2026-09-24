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
    
    /*  always @(posedge clk) begin
    $display("[cyc t=%0t] sram: ena=%b wea=%b addra=%0d dina=%h",
               $time, dut.sram_inst.ena, dut.sram_inst.wea,
               dut.sram_inst.addra, dut.sram_inst.dina);
    end */

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


        /* $display("--- Isolated read-latency test: write 0x0050, then read with 2-cycle check ---");
        @(negedge clk);
        write_en = 4'b1111; addr = 16'h0050; data_in = 32'h55667788;
        @(posedge clk);
        @(negedge clk); write_en = 4'b0000;

        @(negedge clk); read_en = 1'b1; addr = 16'h0050;
        @(posedge clk); #1;
        $display("1 cycle after read request: data_out=%h", data_out);
        @(posedge clk); #1;
        $display("2 cycles after read request: data_out=%h", data_out);
         */
        
        $display("\n--- Test 1: Full word write to addr 0x0110 ---");
        @(negedge clk);
        write_en = 4'b1111;
        addr = 16'h0110;
        data_in = 32'haabbccdd;

        @(posedge clk); // Seems race conditions on these 3 are fine
        write_en = 4'b0000;
        addr = 16'h0011;
        data_in = 32'h000000aa;

        //@(posedge clk); // WRITE DELAY ADDED FOR TEST
        read_en = 1'b1;
        // but race condition on read is not okay. 
        @(posedge clk); // ADDED FOR TEST
        @(negedge clk);
        read_en = 1'b0;
        @(posedge clk); // ADDED FOR TEST

        $display("--- Test 2: Read back addr 0x0110, expect aabbccdd ---");
        @(posedge clk);
        read_en = 1'b1;
        addr = 16'h0110;
        @(posedge clk); // ADDED FOR TEST
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
        //@(posedge clk); // WRITE DELAY ADDED FOR TEST
        @(posedge clk);
        write_en = 4'b0000; // With this, the enable signal to the chip goes low
        // so we also check if its still able to write.

        $display("--- Test 4: Read back addr 0x0110, expect only byte 1 changed (aabb0fdd) ---");
        @(negedge clk);
        read_en = 1'b1;
        @(posedge clk); // ADDED FOR TEST
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
        //@(posedge clk); // WRITE DELAY ADDED FOR TEST
        @(posedge clk);
        @(negedge clk);
        write_en = 4'b0000;
        data_in = '0;

        $display("--- Test 6: Read addr 0x0110 again ---");
        @(negedge clk);
        read_en = 1'b1;
        addr = 16'h0110;
        @(posedge clk); // ADDED FOR TEST
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
        @(posedge clk); // ADDED FOR TEST
        @(posedge clk);
        #1;
        if (data_out === 32'h11223344) begin
            $display("PASS: data_out = %h", data_out);
        end else begin
            $display("FAIL: expected 11223344, got %h", data_out);
        end

        @(negedge clk);
        read_en = 1'b0;

        $display("\n--- Test 8: mem_ready timing check - should be high exactly 2 cycle after request ---");
        @(negedge clk);
        read_en = 1'b1;
        addr = 16'h0020;
        if (mem_ready !== 1'b0) begin
            $display("FAIL: mem_ready asserted too early (before request even sampled)");
        end
        @(posedge clk); // ADDED FOR TEST
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
        //@(posedge clk); // WRITE DELAY ADDED FOR TEST
        @(posedge clk);

        @(negedge clk);
        addr = 16'h0034;
        data_in = 32'habababab;
        @(posedge clk);
        //@(posedge clk); // WRITE DELAY ADDED FOR TEST
        @(negedge clk);
        write_en = 4'b0000;
 
        $display("--- Test 10: Verify both back-to-back writes ---");
        @(negedge clk);
        read_en = 1'b1;
        addr = 16'h0030;
        @(posedge clk); // ADDED FOR TEST
        @(posedge clk);
        #1;
        if (data_out === 32'hcdcdcdcd) begin
            $display("PASS: addr 0x0030 = %h", data_out);
        end else begin
            $display("FAIL: addr 0x0030 expected cdcdcdcd, got %h", data_out);
        end

        @(negedge clk);
        addr = 16'h0034;
        @(posedge clk); // ADDED FOR TEST
        @(posedge clk);
        #1;
        if (data_out === 32'habababab) begin
            $display("PASS: addr 0x0034 = %h", data_out);
        end else begin
            $display("FAIL: addr 0x0034 expected abababab, got %h", data_out);
        end

        @(negedge clk);
        read_en = 1'b0;

        $display("\n--- Test 11: Asynchronous reset mid-operation ---");
        // Start a read so the FSM is in its wait state, then
        // assert rst_n low without waiting for a clock edge
        @(negedge clk);
        read_en = 1'b1;
        addr    = 16'h0050;
 
        @(posedge clk);
 
        #2;             // partway through the cycle
        rst_n = 1'b0;   // assert reset asynchronously
 
        #1;
        if (mem_ready === 1'b0) begin
            $display("PASS: mem_ready deasserted immediately on async reset");
        end else begin
            $display("FAIL: mem_ready still high after async reset, mem_ready=%b", mem_ready);
        end 

        // Hold reset for a couple of cycles, then release
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n   = 1'b1;
        read_en = 1'b0;
        write_en = 4'b0000;
 
        $display("--- Test 12: Confirm normal operation resumes correctly after reset ---");
        @(negedge clk);
        write_en = 4'b1111;
        addr     = 16'h0060;
        data_in  = 32'h88888888;
        @(posedge clk);
        @(negedge clk);
        write_en = 4'b0000;
 
        @(negedge clk);
        read_en = 1'b1;
        addr    = 16'h0060;
        @(posedge clk);
        @(posedge clk); // one wait cycle for read latency
        #1;
        if (data_out === 32'h88888888)
            $display("PASS: post-reset write/read works, data_out=%h", data_out);
        else
            $display("FAIL: post-reset write/read broken, got %h", data_out);
 
        @(negedge clk);
        read_en = 1'b0;
 
        $display("\n--- Test 13: read_en and write_en both asserted simultaneously ---");
        // Per design notes: write_en should take priority over read_en
        // when both are high at once. Write NEW data to an address that
        // already holds a DIFFERENT known value, so we can distinguish
        // "write happened" from "stale read happened" in the result.
        @(negedge clk);
        write_en = 4'b1111;
        addr     = 16'h0070;
        data_in  = 32'h00000001;
        @(posedge clk);
        @(negedge clk);
        write_en = 4'b0000;
 
        // Now assert BOTH read_en and write_en at once, writing a NEW value
        @(negedge clk);
        read_en  = 1'b1;
        write_en = 4'b1111;
        addr     = 16'h0070;
        data_in  = 32'h66666666;
 
        @(posedge clk); // per priority rule, this should be treated as WRITE
        @(negedge clk);
        read_en  = 1'b0;
        write_en = 4'b0000;
        // We should therefore not see it enter WAIT state
 
        $display("--- Test 14: Read back addr 0x0070, expect 66666666 if write_en had priority ---");
        @(negedge clk);
        read_en = 1'b1;
        addr    = 16'h0070;
        @(posedge clk);
        @(posedge clk); // wait cycle for read latency
        #1;
        if (data_out === 32'h66666666)
            $display("PASS: write_en took priority as intended, data_out=%h", data_out);
        else
            $display("FAIL/NOTE: got %h - if this is 00000001, write_en was NOT prioritized (or was ignored while read_en also high)", data_out);
 
        @(negedge clk);
        read_en = 1'b0;


        repeat (3) @(posedge clk);
        $display("\n=== Testbench finished ===");


        $finish;
    end

endmodule
