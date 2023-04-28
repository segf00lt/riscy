module test_ctrl();
reg clk = 0;
reg [31:0] inst;

always #1 clk = !clk;

ctrl dut(.clk(clk), .inst(inst));

initial begin
	$dumpfile("test_ctrl.vcd");
	$dumpvars(0,dut);
	inst = 32'b11111111111111111111_00001_0110111;
	#4
	inst = 32'b11111111111111111111_00101_0010111;
	#4
	inst = 32'b01111111111100000111_00110_1101111;
	#4
	inst = 32'b000000000000_00110_000_00001_0000011;
	#4
	$finish;
end
endmodule
