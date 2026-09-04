module encoder
(
	input clk_50M,
	input rst,
	input enc,
	output logic [31:0]cnt_means
);

	logic enc_filter, enc_pos, enable, load, rst1;
	logic [31:0] cnt; 

	Low_Pass_Filter_4ENC LowPassFilter0(
		.sig_filter				(enc_filter),	
	    .signal					(enc),	
	    .r_LPF_threshold_enc	(200),
		.clk					(clk_50M), 
        .reset                  (rst)
	);
	
	edgeDector edgeDector0(
		.clk_50M		(clk_50M),
		.rst			(rst),
	    .enc_filter		(enc_filter),
	    .enc_pos        (enc_pos)
	);
	
	always_ff@(posedge clk_50M)
	begin
		if(rst1)
			cnt <= 0;
		else if(enable)
			cnt <= cnt + 1;
	end
	
	always_ff@(posedge clk_50M)
	begin
		if(!rst)
			cnt_means <= 0;
		else if(load)
			cnt_means <= cnt;
	end
	
	typedef enum logic [1:0]{Start, Count, Posedge} state_t;
	state_t ps, ns;
	
	always_ff@(posedge clk_50M)
	begin
		if(!rst)
			ps <= Start;
		else
			ps <= ns;
	end
	
	always_comb
	begin
		enable = 0; load = 0; rst1 = 0; ns = ps;
		case(ps)
			Start:
			begin
				rst1 = 1;
				ns = Count;
			end
			Count:
			begin
				if(enc_pos)
					ns = Posedge;
				else
					enable = 1;
			end
			Posedge:
			begin
				load = 1;
				rst1 = 1;
				ns = Count;
			end
		endcase
	end
endmodule