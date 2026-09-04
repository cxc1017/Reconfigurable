module encoder
(
	input clk_50M,
	input rst,
	input enc,
	output logic [31:0]cnt_means,
	output logic step_col
);

	logic enc_filter, enc_pos, enable, load, rst1, load_mul_res;
	logic [31:0] cnt; 
	logic [15:0] r_distance, mul_res;

	Low_Pass_Filter_4ENC LowPassFilter0(
		.sig_filter				(enc_filter),	
	    .signal					(enc),	
	    .r_LPF_threshold_enc	(14'd20),
		.clk					(clk_50M), 
        .reset                  (rst)
	);
	
	edgeDector edgeDector0(
		.clk_50M		(clk_50M),
		.rst			(rst),
	    .enc_filter		(enc_filter),
	    .enc_pos        (enc_pos)
	);
	
	assign r_distance = 173;
	
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
	
	always_ff@(posedge clk_50M)
	begin
		if(!rst)
			mul_res <= 0;
		else if(load_mul_res)
			mul_res <= cnt_means*r_distance/4233;
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
		enable = 0; load = 0; rst1 = 0; ns = ps; load_mul_res = 0; step_col = 0;
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
				if(cnt >= mul_res)
				begin
					rst1 = 1;			//cnt = 0;
					load_mul_res = 1;
					step_col = 1;
				end
				ns = Count;
				
			end
		endcase
	end
endmodule