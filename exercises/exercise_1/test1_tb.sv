module test1_tb;

logic in1, in2, in3, out1, out2;

logic [3:0] decoder_address;
logic [15:0] decoder_output;

test1 DUT1 (.in1(in1),
           .in2(in2),
           .in3(in3),
           .out1(out1),
           .out2(out2));

decoder DUT2 (.AA(decoder_address),
              .II(decoder_output));


initial begin
  in1 = 0;
  in2 = 0; 
  in3 = 0;
  decoder_address = 8'b0;
  #10ns;
  in1 = 1;
  decoder_address = 3;
  #10ns;
  in3 = 1;
  decoder_address = 8;
  #10ns;
  in2 = 1;
  decoder_address = 1;
end

endmodule