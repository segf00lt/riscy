module test_regfile();
parameter TEST_COUNT = 7;
reg clk = 0, write = 1, read = 0;
reg [11:0] count;
reg [4:0] rd_addr;
reg [4:0] r1_addr;
reg [4:0] r2_addr;
reg [31:0] data;
wire [31:0] out1;
wire [31:0] out2;
reg [31:0] test_writes [0:TEST_COUNT-1];
reg [31:0] test_reads_r1 [0:TEST_COUNT-1];
reg [31:0] test_reads_r2 [0:TEST_COUNT-1];

regfile dut(
	.clk(clk),
	.rd(data),
	.rd_addr(rd_addr),
	.r1_addr(r1_addr),
	.r2_addr(r2_addr),
	.w_en(write ^ read),
	.r1_out(out1),
	.r2_out(out2)
);

always #1 clk = !clk;
always #2 write = !write;
always #4 count = count + 1;
always #4 rd_addr = rd_addr + (1 ^ read);

always @(negedge clk) begin
	data <= test_writes[count];
end

initial begin
	test_writes[0] = 32'hfefe;
	test_writes[1] = 32'habba;
	test_writes[2] = 32'h1313;
	test_writes[3] = 32'hbadd;
	test_writes[4] = 32'heafd;
	test_writes[5] = 32'hbbbb;
	test_writes[6] = 32'h6969;
	for(integer i = 0; i < TEST_COUNT; i++) begin
		test_reads_r1[i] = 32'bz;
		test_reads_r2[i] = 32'bz;
	end
	rd_addr = 1;
	r1_addr = 0;
	r2_addr = 0;
	count = 0;
	data = test_writes[0];
	$dumpfile("test_regfile.vcd");
	$dumpvars(0,dut);
	#36
	for(integer i = 0; i < TEST_COUNT; i++) begin
		$display("test_writes[%0x] -> %x",i,dut.registers[i]);
	end
	read = 1;
	r1_addr = 1;
	r2_addr = 2;
	#4
	$display("registers[%0d] -> %x\nregisters[%0d] -> %x", r1_addr, out1, r2_addr, out2);
	r1_addr = 3;
	r2_addr = 4;
	#4
	$display("registers[%0d] -> %x\nregisters[%0d] -> %x", r1_addr, out1, r2_addr, out2);
	$finish;
end
endmodule
