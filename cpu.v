module alu(
	input [31:0] x, y,
	input [3:0] op,
	output reg [31:0] out
);
parameter ADD = 4'b0000;
parameter SUB = 4'b1000;
parameter SLL = 4'b0001;
parameter SLT = 4'b0010;
parameter SLTU = 4'b0011;
parameter XOR = 4'b0100;
parameter SRL = 4'b0101;
parameter SRA = 4'b1101;
parameter OR = 4'b0110;
parameter AND = 4'b0111;

always @(*) begin
	case(op)
		ADD: out = x + y;
		SUB: out = x - y;
		SLL: out = x << y[4:0];
		SLT: out = {31'b0, $signed(x) < $signed(y)};
		SLTU: out = {31'b0, x < y};
		XOR: out = x ^ y;
		SRL: out = x >> y;
		SRA: out = x >>> y;
		OR: out = x | y;
		AND: out = x & y;
	endcase
end
endmodule

module cmp(
	input [31:0] x, y,
	input [2:0] op,
	output reg out
);
parameter EQ = 3'b000;
parameter NE = 3'b001;
parameter LT = 3'b100;
parameter GE = 3'b101;
parameter LTU = 3'b110;
parameter GEU = 3'b111;

always @(*) begin
	case(op)
		EQ: out = x == y;
		NE: out = x != y;
		LT: out = $signed(x) < $signed(y);
		GE: out = $signed(x) >= $signed(y);
		LTU: out = x < y;
		GEU: out = x >= y;
	endcase
end
endmodule

module ram(
	input clk,
	input w_en,
	input u_en, // enable unsigned load
	input [13:0] i_addr,
	input [13:0] d_addr,
	input [31:0] d_in,
	input [1:0] d_size,
	output reg [31:0] d_out,
	output reg [31:0] i_out
);
parameter BYTE = 2'b00;
parameter HALF = 2'b01;
parameter WORD = 2'b10;

reg [31:0] mem [0:4095]; // 16KB
wire [31:0] d = mem[d_addr[13:2]];
wire [31:0] sb, sh, sw, lb, lh, lw;
wire [31:0] store, load;
wire [31:0] sb_mux [0:3];
wire [31:0] sh_mux [0:3];
wire [31:0] lb_mux [0:3];
wire [31:0] lh_mux [0:3];

initial begin
	d_out = 32'b0;
	i_out = 32'b0;
	for(integer i = 0; i < 4096; i++)
		mem[i] = 0;
end

// setup store
assign sb_mux[3] = {d_in[7:0], d[23:0]};
assign sb_mux[2] = {d[31:24], d_in[7:0], d[15:0]};
assign sb_mux[1] = {d[31:16], d_in[7:0], d[7:0]};
assign sb_mux[0] = {d[31:8], d_in[7:0]};

assign sh_mux[3] = 32'bz;
assign sh_mux[2] = {d_in[15:0], d[15:0]};
assign sh_mux[1] = 32'bz;
assign sh_mux[0] = {d[31:16], d_in[15:0]};

assign sb = sb_mux[d_addr[1:0]];
assign sh = sh_mux[d_addr[1:0]];
assign sw = d_in;

assign store = ({32{~|d_size}} & sb) | ({32{d_size[0]}} & sh) | ({32{d_size[1]}} & sw);

// setup load
assign lb_mux[3] = {{24{~u_en & d[31]}}, d[31:24]};
assign lb_mux[2] = {{24{~u_en & d[23]}}, d[23:16]};
assign lb_mux[1] = {{24{~u_en & d[15]}}, d[15:8]};
assign lb_mux[0] = {{24{~u_en & d[7]}}, d[7:0]};

assign lh_mux[3] = 32'bz;
assign lh_mux[2] = {{16{~u_en & d[31]}}, d[31:16]};
assign lh_mux[1] = 32'bz;
assign lh_mux[0] = {{16{~u_en & d[15]}}, d[15:0]};

assign lb = lb_mux[d_addr[1:0]];
assign lh = lh_mux[d_addr[1:0]];
assign lw = d;

assign load = ({32{~|d_size}} & lb) | ({32{d_size[0]}} & lh) | ({32{d_size[1]}} & lw);

always @(posedge clk) begin
	i_out <= mem[i_addr[13:2]];
	if(w_en)
		mem[d_addr[13:2]] <= store;
	else
		d_out <= load;
end
endmodule

module regfile(
	input [31:0] in,
	input [3:0] addr,
	input write,
	output reg [31:0] out
);
reg [31:0] registers[0:31];
endmodule

module ctrl(
);
endmodule

module cpu(
);
parameter LOAD = 7'b00000_11;
parameter STORE = 7'b01000_11;
parameter BRANCH = 7'b11000_11;
parameter JALR = 7'b11001_11;
parameter JAL = 7'b11011_11;
parameter OPIMM = 7'b01100_11;
parameter OP = 7'b00100_11;
parameter AUIPC = 7'b00101_11;
parameter LUI = 7'b01101_11;
parameter SYSTEM = 7'b11100_11;
parameter MISCMEM = 7'b00011_11;

endmodule
