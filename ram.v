module george_ram (
	input clk,
	input w_en,
	input s_en,
	input [13:0] i_addr,
	input [13:0] d_addr,
	input [31:0] w_data,
	input [1:0] w_size,
	output reg [31:0] d_out,
	output reg [31:0] i_out
);

// 16 KB
reg [31:0] mem [0:4095];
wire [31:0] dt_data = mem[d_addr[13:2]];

initial begin
	for(integer i = 0; i<4096;i++)
		mem[i] = 0;
end

always @(posedge clk) begin
	// always aligned for instruction fetch
	i_out <= mem[i_addr[13:2]];
	if(w_en) begin
		d_out <= 32'bz;
		case (w_size)
			2'b10: mem[d_addr[13:2]] <= w_data;
			2'b01:
				case(d_addr[1])
					1'd0: mem[d_addr[13:2]] <= {dt_data[15:0], w_data[15:0]};
					1'd1: mem[d_addr[13:2]] <= {w_data[15:0], dt_data[15:0]};
				endcase
			2'b00:
				case(d_addr[1:0])
					2'd0: mem[d_addr[13:2]] <= {dt_data[31:8], w_data[7:0]};
					2'd1: mem[d_addr[13:2]] <= {dt_data[31:16], w_data[7:0], dt_data[7:0]};
					2'd2: mem[d_addr[13:2]] <= {dt_data[31:24], w_data[7:0], dt_data[15:0]};
					2'd3: mem[d_addr[13:2]] <= {w_data[7:0], dt_data[23:0]};
				endcase
		endcase
	end
	// misaligned data, but it's filled with 0s
	// support some unaligned loads, but can't break word boundary
	else begin
		case(d_addr)
			2'd0: d_out <= dt_data;
			2'd1: d_out <= s_en ? dt_data >>> 8 : dt_data >> 8;
			2'd2: d_out <= s_en ? dt_data >>> 16 : dt_data >> 16;
			2'd3: d_out <= s_en ? dt_data >>> 24 : dt_data >> 24;
		endcase
	end
end
endmodule

module ram(
	input clk,
	input write,
	input [11:0] addr,
	input [31:0] data,
	output [31:0] out
);
reg [31:0] mem[0:4095];
wire [31:0] w;

assign out = write ? 32'bz : mem[addr];
always @(posedge clk)
	if(write)
		mem[addr] <= data;
endmodule

module ram_tb();
parameter TEST_COUNT = 8;
reg clk = 0, write = 1;
reg [11:0] addr1;
reg [13:0] addr2;
reg [31:0] data;
wire [31:0] out1;
wire [31:0] out2;
wire [31:0] out3;
reg [31:0] tmp;
reg [31:0] test_values [0:TEST_COUNT-1];

ram r(
	.clk(clk),
	.write(write),
	.addr(addr1),
	.data(data),
	.out(out1)
);

george_ram gr(
	.clk(clk),
	.w_en(write),
	.i_addr(14'd0),
	.i_out(out2),
	.d_addr(addr2),
	.d_out(out3),
	.w_data(data),
	.w_size(2'd1)
);

always #1 clk = !clk;
always #2 write = !write;
always #4 addr1 = addr1 + 1;
always #4 addr2 = addr2 + 4;

always @(negedge clk) begin
	data <= test_values[addr1];
end

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
	addr1 = 0;
	addr2 = 2;
	data = test_values[0];
	$dumpfile("test_ram.vcd");
	$dumpvars(0,gr);
	#32
	for(integer i = 0; i < TEST_COUNT; i++) begin
		$display("RAM[%0x] -> %x",i,r.mem[i]);
	end
	for(integer i = 0; i < TEST_COUNT; i++) begin
		$display("george RAM[%0x] -> %x",i,gr.mem[i]);
	end
	$finish;
end

endmodule
