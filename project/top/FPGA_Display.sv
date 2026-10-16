`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.10.2026 13:06:06
// Design Name: 
// Module Name: FPGA_Display
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module fpga_display(
    //Take clock and reset from Urbana board
    input logic clk,
    input logic rst_n,
//    input logic pc_write_en_debug,
    
    //Debug signals from processor and memory
    input logic [31:0] pc_debug,
    input logic [31:0] mem_debug_data,
    input logic [3:0] mem_debug_write,
    input logic read_en_debug,
    input logic mem_ready_debug,
    
    output logic [14:0] LED, //LED[0] is controlled by the existing urbana_top template
    
    //7-segment display 
    output logic [3:0] D0_AN,
    output logic [7:0] D0_SEG,
    output logic [3:0] D1_AN,
    output logic [7:0] D1_SEG
    );
    
    logic [31:0] latest_write;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            latest_write <=32'b0;
        else if (|mem_debug_write)
            latest_write <= mem_debug_data;
    end
    
    //To display four digits on each display
    logic [3:0][3:0] data_digits;
    logic [3:0][3:0] pc_digits;
    
    //Display 0 will display the lowest 16 bits of the latest write to the memory
    assign data_digits = {
        latest_write[3:0],
        latest_write[7:4],
        latest_write[11:8],
        latest_write[15:12]
    };
    
    assign pc_digits = {
        pc_debug[3:0],
        pc_debug[7:4],
        pc_debug[11:8],
        pc_debug[15:12]
    };
    
    //LED_status[0] connects to physical LED[1]
    //Physical LED[0] is still driven by urbana_top
    always_comb begin
        LED = '0;
        
        LED[0] = rst_n;
        LED[1] = read_en_debug;
        LED[5:2] = mem_debug_write;
        LED[6] = mem_ready_debug;
    end 
//logic read_seen;
//logic ready_seen;
//logic write_seen;
//logic pc_write_seen;


//always_ff @(posedge clk or negedge rst_n) begin
//    if (!rst_n) begin
//        read_seen     <= 1'b0;
//        ready_seen    <= 1'b0;
//        write_seen    <= 1'b0;
//        pc_write_seen <= 1'b0;
//    end else begin
//        if (read_en_debug)
//            read_seen <= 1'b1;

//        if (mem_ready_debug)
//            ready_seen <= 1'b1;

//        if (|mem_debug_write)
//            write_seen <= 1'b1;

//        if (pc_write_en_debug)
//            pc_write_seen <= 1'b1;
//    end
//end

//always_comb begin
//    LED = '0;
//    LED[0] = rst_n;
//    LED[1] = read_seen;
//    LED[2] = ready_seen;
//    LED[3] = pc_write_seen;
//    LED[4] = write_seen;
//end
    //Display data
    kw4281_driver data_display (
        .rst_n(rst_n),
        .clk(clk),
        .input_bcd(data_digits),
        .input_dots(4'b1111),
        .an(D0_AN),
        .seg(D0_SEG)
    );
    
    //Display the PC
    kw4281_driver pc_display (
        .rst_n(rst_n),
        .clk(clk),
        .input_bcd(pc_digits),
        .input_dots(4'b1111),
        .an(D1_AN),
        .seg(D1_SEG)
    );
endmodule
