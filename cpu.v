/*
* NOTE all instructions have 0b11 in the rightmost bits
* the opcode follows this bit pattern
*/

/* opcodes */
`define LOAD 5'b00000_11;
`define STORE 5'b01000_11;
`define BRANCH 5'b11000_11;
`define JALR 5'b11001_11;
`define JAL 5'b11011_11;
`define OPIMM 5'b01100_11;
`define OP 5'b00100_11;
`define AUIPC 5'b00101_11;
`define LUI 5'b01101_11;
`define SYSTEM 5'b11100_11;
`define MISCMEM 5'b00011_11;

/* integer operations */
`define ALU_ADD 4'b0000;
`define ALU_SUB 4'b1000;
`define ALU_SLL 4'b0001;
`define ALU_SLT 4'b0010;
`define ALU_SLTU 4'b0011;
`define ALU_XOR 4'b0100;
`define ALU_SRL 4'b0101;
`define ALU_SRA 4'b1101;
`define ALU_OR 4'b0110;
`define ALU_AND 4'b0111;

/* comparisons */
`define CMP_EQ 3'b000;
`define CMP_NE 3'b001;
`define CMP_LT 3'b100;
`define CMP_GE 3'b101;
`define CMP_LTU 3'b110;
`define CMP_GEU 3'b111;

/* memory operations */
`define RAM_LB 4'b0000;
`define RAM_LH 4'b0001;
`define RAM_LW 4'b0010;
`define CMP_GE 4'b101;
`define CMP_LTU 3'b110;
`define CMP_GEU 3'b111;

module alu(
	input [31:0] x, [31:0] y,
	input [3:0] op,
	output [31:0] out
);
always @(*) begin
	case(op)
		`ALU_ADD: out = x + y;
		`ALU_SUB: out = x - y;
		`ALU_SLL: out = x << y[4:0];
		`ALU_SLT: out = {31'b0, $signed(x) < $signed(y)};
		`ALU_SLTU: out = {31'b0, x < y};
		`ALU_XOR: out = x ^ y;
		`ALU_SRL: out = x >> y;
		`ALU_SRA: out = x >>> y;
		`ALU_OR: out = x | y;
		`ALU_AND: out = x & y;
	endcase
end
endmodule

module cmp(
	input [31:0] x, [31:0] y,
	input [2:0] op,
	output out
);
always @(*) begin
	case(op)
		`CMP_EQ: out = x == y;
		`CMP_NE: out = x != y;
		`CMP_LT: out = $signed(x) < $signed(y);
		`CMP_GE: out = $signed(x) >= $signed(y);
		`CMP_LTU: out = x < y;
		`CMP_GEU: out = x >= y;
	endcase
end
endmodule

/* for 16KB of RAM we only need a 12 bit address */
module ram(
	input clk,
	input [13:0] inst_addr, [13:0] data_addr,
	input [31:0] data_in,
	input [1:0] data_size,
	input write, sign,
	output reg [31:0] inst_out, reg [31:0] data_out
);
reg [31:0] memory[0:4095];
wire [31:0] wd;
wire [31:0] rd;
wire [31:0] data = memory[data_addr[13:2]];

always @(posedge clk) begin
	inst_out <= memory[inst_addr[13:2]]; // why [13:2]????

	wd <= write ? data_in : data;

	// load
	case(data_addr[1:0])
		2'b00: rd <= data;
		2'b01: rd <= {8'b0, data[31:8]};
		2'b10: rd <= {16'b0, data[31:16]};
		2'b11: rd <= {24'b0, data[31:24]};
	endcase

	case({sign, data_size})
		2'b000: data_out <= {24'b0, rd[7:0]}; // byte
		2'b001: data_out <= {16'b0, rd[15:0]}; // half
		2'b100: data_out <= {{24{rd[7]}}, rd[7:0]}; // signed byte
		2'b101: data_out <= {{16{rd[15]}}, rd[15:0]}; // signed half
		2'b010: data_out <= rd; // word
		2'b110: data_out <= rd; // signed word (same as word)
	endcase

	// store
	if(write) begin
		case(data_size)
			2'b00: memory[data_addr[13:2]] <=
				data_addr[1] ?
				// top half
				(data_addr[0] ? {wd[7:0], data[23:0]} : {data[31:24], wd[7:0], data[15:0]}) :
					// bottom half
		       (data_addr[0] ? {data[31:16], wd[7:0], data[7:0]} : {data[31:8], wd[7:0]}); // byte
		       2'b01: memory[data_addr[13:2]] <=
			       data_addr[1] ? {wd[15:0], data[15:0]} : {data[31:16], wd[15:0]}; // half
		       2'b10: memory[data_addr[13:2]] <= wd; // word
	       endcase
       end
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
endmodule
