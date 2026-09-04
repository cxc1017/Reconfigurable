module freq_divider(
	input clk, 
	input rst, 
	input [1:0] sel,
	output logic clk_out
);

	logic [23:0] count;
	
	always_ff@(posedge clk)
	begin
		if(rst)
			count <= 0;
		else 
			count <= count + 1;
	end
	
	always_comb
	begin
		unique case(sel)
			0:	clk_out = count[9];
			1:	clk_out = count[10];
			2:  clk_out = count[11];
			3:  clk_out = count[12];
		endcase
	end
	
endmodule