all:
	iverilog cpu.v test_benches.v
test: all
	vvp a.out
