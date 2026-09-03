vlog -sv ./test1.sv
vlog -sv ./decoder.sv
vlog -sv ./test1_tb.sv

vsim work.test1_tb -voptargs=+acc

add wave -position insertpoint  \
sim:/test1_tb/decoder_address \
sim:/test1_tb/decoder_output \
sim:/test1_tb/in1 \
sim:/test1_tb/in2 \
sim:/test1_tb/in3 \
sim:/test1_tb/out1 \
sim:/test1_tb/out2

add wave -position insertpoint  \
sim:/test1_tb/DUT1/in1 \
sim:/test1_tb/DUT1/in2 \
sim:/test1_tb/DUT1/in3 \
sim:/test1_tb/DUT1/out1 \
sim:/test1_tb/DUT1/out2

add wave -position insertpoint  \
sim:/test1_tb/DUT2/AA \
sim:/test1_tb/DUT2/II

run 50ns
