module decoder ( 
    input logic [3:0] binary,
    output logic [15:0] one_hot
);
/*
    assign one_hot = (binary==4'b0000) ? 16'b1 :
        (binary==4'b0001) ? 16'b0000000000000010 :
        (binary==4'b0010) ? 16'b0000000000000100 :
        (binary==4'b0011) ? 16'b0000000000001000 :
        (binary==4'b0100) ? 16'b0000000000010000 :
        (binary==4'b0101) ? 16'b0000000000100000 :
        (binary==4'b0110) ? 16'b0000000001000000 :
        (binary==4'b0111) ? 16'b0000000010000000 :
        (binary==4'b1000) ? 16'b0000000100000000 :
        (binary==4'b1001) ? 16'b0000001000000000 :
        (binary==4'b1010) ? 16'b0000010000000000 :
        (binary==4'b1011) ? 16'b0000100000000000 :
        (binary==4'b1100) ? 16'b0001000000000000 :
        (binary==4'b1101) ? 16'b0010000000000000 :
        (binary==4'b1110) ? 16'b0100000000000000 :
        (binary==4'b1111) ? 16'b1000000000000000 :
        16'b0;
*/
    always_comb begin : notLUT
        one_hot = 16'b0;
        one_hot[binary] = 1'b1;
    end


endmodule