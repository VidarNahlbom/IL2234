module hw1_tb;

logic [3:0] decoder_address;
logic [15:0] decoder_output;

logic [7:0] csa_a, csa_b;
logic       csa_cin;
logic [7:0] csa_sum;
logic       csa_carry;

decoder DUT1 (decoder_address, decoder_output);
    
CSA_8 DUT2 (
    .A    (csa_a),
    .B    (csa_b),
    .cin  (csa_cin),
    .sum  (csa_sum),
    .carry(csa_carry)
  );

initial begin
    for (int i = 0; i < 16; i++) begin
        decoder_address = i[3:0]; 
        #10ns;      
    end

    // Initialisera alla insignaler
    csa_a   = 8'd0;
    csa_b   = 8'd0;
    csa_cin = 1'b0;
    #10ns;

    // Testfall 1: Enkel addering utan carry
    csa_a   = 8'd12;
    csa_b   = 8'd30;
    csa_cin = 1'b0;
    #10ns;

    // Testfall 2: Prova carry mellan nedre och övre 4 bitarna (triggar carry-select)
    csa_a   = 8'h0F; // 15
    csa_b   = 8'h01; // 1 -> ger carry från nedre adderaren
    csa_cin = 1'b0;
    #10ns;

    // Testfall 3: Överrinning på hela 8-bitars adders (carry out)
    csa_a   = 8'hFF; // 255
    csa_b   = 8'h01; // 1
    csa_cin = 1'b0;
    #10ns;

    // Testfall 4: Test av cin = 1
    csa_a   = 8'd100;
    csa_b   = 8'd50;
    csa_cin = 1'b1;
    #10ns;
end
endmodule