module alu(
	input [31:0] x, y,
	input alt,
	input [2:0] op,
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
	input [4:0] rd_addr, r1_addr, r2_addr,
	input w_en,
	output reg [31:0] r1_out, r2_out
);
reg [31:0] registers[0:31];

always @(posedge clk) begin
	registers[0] <= 0;
	if(w_en)
		registers[rd_addr] <= rd;
	else begin
		r1_out <= registers[r1_addr];
		r2_out <= registers[r2_addr];
	end
end
endmodule

module ctrl(
	input clk,
	input [31:0] inst,
	output reg [4:0] r2, r1, dest_reg,
	output reg [2:0] funct,
	output reg [31:0] imm,
	output reg alu_alt,
	output reg memrd_en,
	output reg memwr_en,
	output reg regw_en,
	output reg jump_en,
	output reg alupc_en
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

wire is_jal = opcode == JAL, is_jalr = opcode == JALR,
	is_auipc = opcode == AUIPC, is_opimm = opcode == OPIMM,
	is_store = opcode == STORE, is_load = opcode == LOAD,
	is_branch = opcode == BRANCH, is_lui = opcode == LUI,
	is_system = opcode == SYSTEM;

wire uncond_jump = is_jal | is_jalr;
wire add_to_pc = is_jal | is_jalr | is_auipc;
wire is_immediate =
	is_jalr | is_opimm | is_store | is_load |
	is_branch | is_lui | is_auipc | is_jal;

always @(posedge clk) begin
	funct = uncond_jump ? 3'b0 : funct3;
	r1 = rs1;
	r2 = is_immediate ? 5'b0 : rs2;
	dest_reg = rd;
	alu_alt = funct7[5];
	memrd_en = is_load;
	memwr_en = is_store;
	regw_en = !(is_store | is_branch | is_system);
	jump_en = is_branch | is_jalr | is_jal;
	alupc_en = add_to_pc;

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

module pc(
	input clk,
	input jump_en,
	input inc_en,
	input reset,
	input [13:0] in_addr,
	output reg [13:0] out_addr
);
reg [31:0] inst_addr;

initial inst_addr = 0;

always @(posedge clk) begin
	out_addr <= inst_addr;
	if(reset)
		inst_addr <= 0;
	if(inc_en)
		inst_addr <= inst_addr + 4;
	if(jump_en)
		inst_addr <= in_addr;
end
endmodule

module cpu(
	input clk, reset,
	output reg trap,
	output reg [31:0] pc
);
reg [13:0] data_addr;
reg [31:0] alu_x, alu_y;
reg [31:0] cmp_x, cmp_y;
reg [31:0] rd_data;

wire [31:0] inst;
wire [13:0] inst_addr;
wire [4:0] r1_addr, r2_addr;
wire [31:0] r1_data, r2_data;
wire [4:0] dest_reg;
wire [31:0] imm;
wire [31:0] ram_out;
wire [31:0] alu_out;
wire [2:0] funct;
wire alu_alt;
wire do_jump;
wire jump_cond;
wire alu_add_to_pc;
wire memread;
wire memwrite;
wire writeback;

alu a(
	.x(alu_x), .y(alu_y),
	.alt(alu_alt),
	.op(funct),
	.out(alu_out)
);

cmp c(
	.x(cmp_x), .y(cmp_y),
	.op(funct),
	.out(jump_cond)
);

ram r(
	.clk(clk),
	.w_en(memwrite),
	.u_en(funct[2]),
	.i_addr(inst_addr),
	.d_addr(data_addr),
	.d_in(r2_data),
	.d_size(funct[1:0]),
	.d_out(ram_out),
	.i_out(inst)
);

regfile rf(
	.clk(clk),
	.rd(rd_data),
	.rd_addr(dest_reg),
	.r1_addr(r1_addr),
	.r2_addr(r2_addr),
	.w_en(writeback),
	.r1_out(r1_data),
	.r2_out(r2_data)
);

ctrl ct(
	.clk(clk),
	.inst(inst),
	.r1(r1_addr),
	.r2(r2_addr),
	.dest_reg(dest_reg),
	.funct(funct),
	.imm(imm),
	.alu_alt(alu_alt),
	.memrd_en(memread),
	.memwr_en(memwrite),
	.regw_en(writeback),
	.jump_en(do_jump),
	.alupc_en(alu_add_to_pc)
);

// TODO write test benches for ctrl, regfile and pc
pc p(
	.clk(clk),
	.jump_en(do_jump & jump_cond),
	.inc_en(~(do_jump & jump_cond)),
	.reset(1'b0),
	//.in_addr(),
	.out_addr(inst_addr)
);

always @(posedge clk) begin
	rd_data <= memread ? ram_out : alu_out;
end

endmodule
