module test_ram();
parameter TEST_COUNT = 8;
reg clk = 0, write = 1;
reg [11:0] count;
reg [13:0] addr1;
reg [13:0] addr2;
reg [13:0] addr3;
reg [13:0] addr4;
reg [31:0] data;
wire [31:0] out1;
wire [31:0] out2;
reg [31:0] test_stores [0:TEST_COUNT-1];
reg [31:0] test_loads [0:TEST_COUNT-1];

ram dut(
	.clk(clk),
	.w_en(write),
	.u_en(1'b1),
	.i_addr(14'd0),
	.i_out(out1),
	.d_addr(addr3),
	.d_out(out2),
	.d_in(data),
	.d_size(2'd1)
);

always #1 clk = !clk;
always #2 write = !write;
always #4 count = count + 1;
always #4 addr1 = addr1 + 4;
always #4 addr2 = addr2 + 4;
always #4 addr3 = addr3 + 4;
always #4 addr4 = addr4 + 4;

always @(negedge clk) begin
	if(count > 0)
		test_loads[count-1] <= out2;
	data <= test_stores[count];
end

initial begin
	test_stores[0] = 32'hfefe;
	test_stores[1] = 32'habba;
	test_stores[2] = 32'h1313;
	test_stores[3] = 32'hbadd;
	test_stores[4] = 32'heafd;
	test_stores[5] = 32'hbbbb;
	test_stores[6] = 32'h0000;
	test_stores[7] = 32'h6969;
	for(integer i = 0; i < TEST_COUNT; i++)
		test_loads[i] = 0;
	count = 0;
	addr1 = 0;
	addr2 = 1;
	addr3 = 2;
	addr4 = 3;
	data = test_stores[0];
	$dumpfile("test_bench_dump.vcd");
	$dumpvars(0,dut);
	#36
	for(integer i = 0; i < TEST_COUNT; i++) begin
		$display("test_stores[%0x] -> %x",i,dut.mem[i]);
	end
	for(integer i = 0; i < TEST_COUNT; i++) begin
		$display("test_loads[%0x] -> %x",i,test_loads[i]);
	end
	$finish;
end

endmodule
