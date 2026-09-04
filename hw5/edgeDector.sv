module edgeDector(
	input clk_50M,
	input rst,
	input enc_filter,
	output logic enc_pos
);
	
	logic s_signal, d_signal;
	
	always_ff@(posedge clk_50M)
	begin
		if(!rst)begin
			s_signal <= 1'b1;
			d_signal <= 1'b1;
			enc_pos  <= 1'b0;
		end
		else begin
			{d_signal, s_signal} <= {s_signal, enc_filter};
			enc_pos <= s_signal & ~d_signal;
		end
	end
endmodule