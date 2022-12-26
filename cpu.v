module alu(
	input [31:0] x, y,
	input alt,
	input [3:0] op,
	output reg [31:0] out
);
parameter AS = 3'b000;
parameter SLL = 3'b001;
parameter SLT = 3'b010;
parameter SLTU = 3'b011;
parameter XOR = 3'b100;
parameter SR = 3'b101;
parameter OR = 3'b110;
parameter AND = 3'b111;
always @(*) begin
	case(op)
		AS: out = alt ? x - y : x + y;
		SLL: out = x << y[4:0];
		SLT: out = {31'b0, $signed(x) < $signed(y)};
		SLTU: out = {31'b0, x < y};
		XOR: out = x ^ y;
		SR: out = alt ? x >>> y : x >> y;
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
	input clk,
	input [31:0] rd,
	input [4:0] rd_addr, rs1_addr, rs2_addr,
	input w_en,
	output reg [31:0] rs1_out, rs2_out
);
reg [31:0] registers[0:31];

always @(posedge clk) begin
	if(w_en)
		registers[rd_addr] <= rd;
	else begin
		rs1_out <= registers[rs1_addr];
		rs2_out <= registers[rs2_addr];
	end
end
endmodule

module ctrl(
	input [31:0] inst,
	output reg [4:0] alu_s2, alu_s1, alu_dest,
	output reg [4:0] cmp_s2, cmp_s1,
	output reg [2:0] funct,
	output reg [31:0] imm,
	output reg alu_alt,
	output reg regwrite_src, // if 0 then alu.out else ram.out
	output reg regwrite_en,
	output reg jump_en,
	output reg pcadd_en,
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

/* instruction decode */
wire [6:0] opcode = inst[6:0];
wire [6:0] funct7 = inst[31:25];
wire [2:0] funct3 = inst[14:12];
wire [4:0] rs2 = inst[24:20], rs1 = inst[19:15], rd = inst[11:7];
wire [31:0] imm_i = {{20{inst[31]}}, inst[31:20]};
wire [31:0] imm_s = {{20{inst[31]}}, inst[31:25], inst[11:7]};
wire [31:0] imm_b = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
wire [31:0] imm_u = {inst[31:12], 12'b0};
wire [31:0] imm_j = {{11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};

wire uncond_jump = opcode == JAL || opcode == JALR;
wire add_to_pc = opcode == JAL || opcode == JALR || opcode == AUIPC;
wire is_immediate =
	opcode == JALR || opcode == OPIMM || opcode == STORE || opcode == LOAD ||
	opcode == BRANCH || opcode == LUI || opcode == AUIPC || opcode == JAL;

always @(*) begin
	funct = uncond_jump ? 3'b0 : funct3;
	alu_s1 = add_to_pc ? 5'b0 : rs1;
	alu_s2 = (add_to_pc || is_immediate) 5'b0 : rs2;
	{cmp_s1, cmp_s2} = uncond_jump ? 10'b0 : {rs1, rs2};
	alu_dest = rd;
	alu_alt = funct7[5];
	regwrite_src = opcode == LOAD;
	regwrite_en = !(opcode == STORE || opcode == BRANCH || opcode == SYSTEM);
	jump_en = opcode == BRANCH || opcode == JALR || opcode == JAL;
	pcadd_en = add_to_pc;

	imm <= 0;
	case(opcode)
		JALR, OPIMM, LOAD: imm <= imm_i;
		STORE: imm <= imm_s;
		BRANCH: imm <= imm_b;
		LUI, AUIPC: imm <= imm_u;
		JAL: imm <= imm_j;
	endcase
end
endmodule

module cpu(
	input clk, reset,
	output reg trap,
	output reg [31:0] pc
);
endmodule
