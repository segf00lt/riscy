#!/bin/sh

for tb in test_*.v
do
	script="${tb%.v}.out"
	iverilog cpu.v $tb -o $script
	./$script
	rm $script
done

mv *.vcd 'test/'
