module alu(
	input [31:0] x, y,
	input alt,
	input [3:0] op,
	output [31:0] out
);
parameter AS = 3'b000;
parameter SLL = 3'b001;
parameter SLT = 3'b010;
parameter SLTU = 3'b011;
parameter XOR = 3'b100;
parameter SR = 3'b101;
parameter OR = 3'b110;
parameter AND = 3'b111;
reg [31:0] result;

assign out = result;

always @(*) begin
	case(op)
		AS: result = alt ? x - y : x + y;
		SLL: result = x << y[4:0];
		SLT: result = {31'b0, $signed(x) < $signed(y)};
		SLTU: result = {31'b0, x < y};
		XOR: result = x ^ y;
		SR: result = alt ? x >>> y : x >> y;
		OR: result = x | y;
		AND: result = x & y;
	endcase
end
endmodule

module cmp(
	input [31:0] x, y,
	input [2:0] op,
	output out
);
parameter EQ = 3'b000;
parameter NE = 3'b001;
parameter LT = 3'b100;
parameter GE = 3'b101;
parameter LTU = 3'b110;
parameter GEU = 3'b111;

reg result;

always @(*) begin
	case(op)
		EQ: result = x == y;
		NE: result = x != y;
		LT: result = $signed(x) < $signed(y);
		GE: result = $signed(x) >= $signed(y);
		LTU: result = x < y;
		GEU: result = x >= y;
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
	output [4:0] alu_s2, alu_s1, alu_dest,
	output [4:0] cmp_s2, cmp_s1,
	output [2:0] funct,
	output [31:0] imm;
	output alu_alt,
	output regwrite_src, // if 0 then alu.out else ram.out
	output regwrite_en,
	output jump_en
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

reg [31:0] immediate;

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

assign funct = (opcode == JAL || opcode == JALR) ? funct3 : 3'b0;
assign {alu_s2, alu_s1} = (opcode == JAL || opcode == JALR) ? {5'd33, 5'b0} : {rs2, rs1};
assign {cmp_s2, cmp_s1} = (opcode == JAL || opcode == JALR) ? 10'b0 : {rs2, rs1};
assign alu_dest = rd;
assign imm = immediate;
assign alu_alt = funct7[5];
assign regwrite_src = opcode == LOAD;
assign regwrite_en = !(opcode == STORE || opcode == BRANCH || opcode == SYSTEM);
assign jump_en = opcode == BRANCH || opcode == JALR || opcode == JAL;

always @(*) begin
	immediate <= 0;
	case(opcode)
		JALR: OPIMM: immediate <= imm_i;
		STORE: immediate <= imm_s
		BRANCH: immediate <= imm_b;
		LUI: AUIPC: immediate <= imm_u;
		JAL: immediate <= imm_j;
	endcase
end
endmodule

module cpu(
	input clk, reset,
	output reg trap,
	output reg [31:0] pc
);

endmodule
