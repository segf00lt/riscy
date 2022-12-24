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
//integer count = 0;
//reg tick = 0;

ram r(
	.clk(clk),
	.write(write),
	.addr(addr),
	.data(data),
	.out(out)
);

always #1 clk = !clk;
always #2 write = !write;
always #4 addr = addr + 1;
//always #1 tick = clk & !write;

always @(negedge clk) begin
	//addr <= count;
	data <= test_values[addr];
end

//always @(tick) begin
//	$display("testing RAM[%x] -> %x",addr,out);
//end

/* NOTE
* When testing sequetial logic circuits we have
* to generate various square waves to stimulate
* the dut
* Depending on the complexity of the dut I guess
* it's useful to write a whole other device (likeley
* some kind of state machine) to generate the stimulus
* To verify the test passed we can then either
* - $dumpvars to a vcd file and diff (or view in gtkwave)
* - or $display some stuff
* the former is probably better, $display and $monitor seem
* more useful as quick and dirty debug outputs
*/
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
	$dumpfile("test_ram.vcd");
	$dumpvars;
	#32
	for(integer i = 0; i < TEST_COUNT; i++)
		$display("RAM[%0x] -> %x",i,r.mem[i]);
	$finish;
end

endmodule
