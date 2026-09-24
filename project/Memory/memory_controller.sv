// Depending on how many cycles read and writes takes IDLE state might be useless. Also read state might be useless
// If read takes just one cycle, so if read_en and addr are input at rising edge, and data can be read after rising edge then
// read state is redundant, it will go from IDLE directly to DONE. 
// We also need to figure out if the mem_ready should be tied to state?

// IF read or writes take longer than 1 cycle, then inputs have to be latched so that they 
// cannot be changed during the operations. this also includes read_en and such

// currently i just have a read_en signal simply because the PDF for milestone 2 has one, but i think
// it is up to us if we want to have it.

// With both a write_en and a read_en, we have to decide which one takes priority incase both are high
// We can also tie a chip_en to ena wire of sram_inst
// UPDATE: Made both read_en and write_en be required for writing
// read_en is now same as chip enable
// write_en has priority over read_en

// Byte-wise writes still have to be implemented
// Currently the last 2 bits of addr are just ignored.

// Read take just 1 rising edge, so if addr and read_en are high on falling edge
// data is available after rising edge
// as far as i can tell writes also take only 1 clock cycle. 

// seems then that basically all states are redudant, and we simply need 
// 2, maybe 3 states.
// one to start in, with mem_ready low
// one to say mem_ready and then possibly one more incase we find an operation that has latency.

module memory_controller (
    input   logic       clk,
    input   logic       rst_n,
    // Depth of 16384, but word-addressable so addr needs to access 64KiB
    // so clog2(65536) = 16, so 15:0
    input   logic[15:0] addr, 
    input   logic[31:0] data_in, 
    output  logic[31:0] data_out,
    input   logic[3:0]  write_en, // byte-wise write mask, if 0000 then read enable
    input   logic       read_en,
    output  logic       mem_ready
);
    // declaration
    typedef enum logic[1:0] {
        IDLE,
        READ,
        WRITE,
        DONE
    } state_t;
    state_t currenct_state, next_state;

    /* // Counter
    logic enable, co;
    logic [1:0] count; // Counter for when read and write output is ready, so for mem_ready
    // Unsure how long each operation takes, will have to be figured out later
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) count <= 2'b00;
        else if (enable) count <= count + 1;
        else count <= 2'b00;
    end
    assign co = &count; // reduction and */
    
    // Address dividing
    logic [13:0] sram_addr; // clog2(65536) = 16 bits, remove 2 bits because SRAM is word-addressable
    assign sram_addr = addr[15:2];

    // Init of SRAM
    SRAM sram_inst (
        .clka(clk), // input wire clka
        .ena(read_en), // input wire ena
        .wea(write_en), // input wire [3:0] wea
        .addra(sram_addr), // input wire [13:0] addra 
        .dina(data_in), // input wire [31:0] dina
        .douta(data_out) // output wire [31:0] douta
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            currenct_state <= IDLE;
        end else begin
            currenct_state <= next_state;
        end
    end

    always_comb begin
        next_state = IDLE;
        mem_ready = 1'b0;
        //enable = 1'b0;

        case(currenct_state)
            IDLE: begin
                // If any write_en bit is high we go to write state, so reduction or operation is used
                if (read_en) begin
                    if(|write_en) begin
                        next_state = WRITE;
                    end else begin
                        next_state = READ;
                    end
                end
                // if read_en is low, then next state is IDLE, like default so doesnt have to be updated.
            end
            READ: begin
                // Read takes one cycle, so addr and read_en input on rising edge
                // and next rising edge data is available on data_out.
                next_state = DONE; 
            end
            WRITE: begin
                // enable = 1'b1;
                // I DONT KNOW HOW MANY CYCLES THE WRITE TAKES
                // Counter needs to be adjusted
                // next_state = co ? DONE : WRITE;
                next_state = DONE; 

            end
            DONE: begin
                mem_ready = 1'b1;

                // and then same logic as IDLE:
                if (read_en) begin
                    if (|write_en) begin
                        next_state = WRITE;
                    end else begin
                        next_state = READ;
                    end
                end
            end
        endcase
    end
endmodule