module test1 (
  input logic in1,
  input logic in2,
  input logic in3,
  output logic out1,
  output logic out2
);

  assign out2 = in3 | out1;
  assign out1 = in1 & in2;

endmodule