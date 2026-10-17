module clock_divider #(
    parameter int DIVISOR
    ) (
    input  logic rst_n,
    input  logic clk_in,
    output logic clk_out
    );


//    logic [$clog2(DIVISOR)-1:0] counter;
    logic [$clog2(DIVISOR+1)-1:0] counter;

     always_ff @(posedge clk_in or negedge rst_n) begin
       if (!rst_n) begin
         counter <= DIVISOR;
         clk_out <= 0;
       end else begin
         if (counter == 0) begin
           counter <= DIVISOR;
           clk_out <= ~clk_out;
         end else begin
           counter <= counter - 1;
         end
       end
     end
endmodule
module urbana_top (
    output logic [15:0]LED,
    input  logic [3:0]BTN, //Push buttons on the board
    input  logic CLK_100MHZ,
    
    //
    output logic [3:0] D0_AN,
    output logic [7:0] D0_SEG,
    output logic [3:0] D1_AN,
    output logic [7:0] D1_SEG
    );
   
    logic rst_n;
    assign rst_n = ~BTN[0];
    // counter signal
    logic cpu_clk;
       logic pc_write_en_debug;
    
    //Info from CPU through debug signals
    logic [31:0] pc_debug;
    logic [31:0] mem_debug_data;
    logic [3:0] mem_debug_write;
    logic read_en_debug;
    logic mem_ready_debug;
    
    //LED controlled by fpga_diaplsy
    logic[14:0] LED_status;
    clock_divider #(
    .DIVISOR(5000000)
) cpu_clock_divider (
    .rst_n(rst_n),
    .clk_in(CLK_100MHZ),
    .clk_out(cpu_clk)
);
    //connect CPU and memory design
    riscv_top riscv_top_inst(
//        .clk(CLK_100MHZ),
        .clk(cpu_clk),
        .rst_n(rst_n),
        .pc_debug(pc_debug),
        .mem_debug_data(mem_debug_data),
        .mem_debug_write(mem_debug_write),
        .read_en_debug(read_en_debug),
        .pc_write_en_debug(pc_write_en_debug),
        .mem_ready_debug(mem_ready_debug)
    );
    
    //Connecting the display module
    fpga_display displa_inst(
        .clk(CLK_100MHZ),
        .rst_n(rst_n),
        .pc_debug(pc_debug),
        .mem_debug_data(mem_debug_data),
        .mem_debug_write(mem_debug_write),
        .read_en_debug(read_en_debug),
        .mem_ready_debug(mem_ready_debug),
        .pc_write_en_debug(pc_write_en_debug),
        .LED(LED_status),
        .D0_AN(D0_AN),
        .D0_SEG(D0_SEG),
        .D1_AN(D1_AN),
        .D1_SEG(D1_SEG)
        
    );   
    
    assign LED[15:1] = LED_status;

    // instantiate clock divider
    clock_divider #(
        .DIVISOR(100000000)
        ) clock_divider_inst (
        .rst_n(~BTN[0]),
        .clk_in(CLK_100MHZ),
        .clk_out(LED[0])
    );
endmodule