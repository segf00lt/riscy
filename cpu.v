/* weekcore */

module alu();
endmodule

module cond();
endmodule

/* for 16K of RAM we only need a 14 bit address */
module ram(
	input clk,
	input [13:0] i_addr, [13:0] d_addr,
	input [31:0] w_data,
	input [1:0] w_size,
	output reg [31:0] i_out, reg [31:0] d_out,
);
endmodule

module cpu();
endmodule
