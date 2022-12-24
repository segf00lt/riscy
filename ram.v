module ram(
	input clk,
	input write,
	input [11:0] addr,
	input [31:0] data,
	output reg [31:0] out
);
reg [31:0] mem[0:4095];

always @(posedge clk) begin
	if(write)
		mem[addr] <= data;
	out <= write ? {32{1'bz}} : mem[addr];
end
endmodule

module ram_tb();
parameter TEST_COUNT = 8;
reg clk = 0, write = 1;
reg [11:0] addr;
reg [31:0] data;
wire [31:0] out;
reg [31:0] tmp;
reg [31:0] test_values [0:TEST_COUNT-1]; // 3 test values
integer count = 0;
reg tick = 0;

ram r(
	.clk(clk),
	.write(write),
	.addr(addr),
	.data(data),
	.out(out)
);


always #1 clk = !clk;
always #2 write = !write;
always #4 count = count + 1;
always #1 tick = clk & !write;

initial begin
	test_values[0] = 32'hfefe;
	test_values[1] = 32'habba;
	test_values[2] = 32'h1313;
	test_values[3] = 32'hbadd;
	test_values[4] = 32'heafd;
	test_values[5] = 32'hbbbb;
	test_values[6] = 32'h0000;
	test_values[7] = 32'h6969;
	addr = 0;
	data = test_values[0];
	$dumpfile("test_ram_x.vcd");
	$dumpvars;
	#32
	//for(integer i = 0; i < TEST_COUNT; i++) begin
	//	addr = count;
	//	data = test_values[count];
	//	#4 $display("RAM[%x] -> %x",addr,out);
	//end
	$finish;
end

always @(negedge clk) begin
	addr <= count;
	data <= test_values[count];
end

always @(negedge tick) begin
	$display("testing RAM[%x] -> %x",addr,out);
end

//initial begin
//	#16
//	$finish;
//end
//
//always @(posedge clk) begin
//	addr <= i;
//	data <= test_values[i];
//end
//
//always @(posedge write)
//	$display("RAM[%x] -> %x",addr,out);

/*
initial begin
	addr = 0;
	write = 1;
	data = 32'hfefe;
	#2 // tick
	$display("%1d",clk);
	write = 0; // disable write
	#2 // tock
	$display("%1d",clk);
	$display("RAM[%x] -> %x",addr,out);
	#2
	$display("%1d",clk);
	$display("RAM[%x] -> %x",addr,out);
	addr = 1;
	write = 1;
	data = 32'h1313;
	#2
	$display("%1d",clk);
	write = 0;
	#2
	$display("RAM[%x] -> %x",addr,out);
	#2
	addr = 0;
	#2
	$display("RAM[%x] -> %x",addr,out);
	tmp = out;
	#2
	addr = 1;
	write = 1;
	data = tmp;
	#2
	write = 0;
	#2
	$display("RAM[%x] -> %x",addr,out);
	$finish;
end
*/

endmodule
