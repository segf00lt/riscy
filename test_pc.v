module test_pc();
reg clk = 0, write = 1;
reg jump_en;
reg inc_en;
reg reset;
reg [13:0] in_addr;
wire [13:0] out_addr;
reg [11:0] count;

pc dut(
	.clk(clk),
	.jump_en(jump_en),
	.inc_en(inc_en),
	.reset(reset),
	.in_addr(in_addr),
	.out_addr(out_addr)
);

always #1 clk = !clk;
always #2 write = !write;
always #4 count = count + 1;

initial begin
	count = 0;
	$dumpfile("test_pc.vcd");
	$dumpvars(0,dut);
	in_addr = 14'bz;
	reset = 1;
	#2
	reset = 0;
	inc_en = 1;
	jump_en = 0;
	#36
	$finish;
end
endmodule
