module handshaking(
	input clk,
	input rst,
	output logic [3:0]c1,
	output logic [3:0]c2
);
	logic cp1, cp2, trigger1, trigger2;
	
	//cnt1
	always_ff@ (posedge clk)
	begin
		if(rst)
			c1 <= 0;
		else if(cp1)
			c1 <= c1+1;
	end
	//cnt2
	always_ff@ (posedge clk)
	begin
		if(rst)
			c2 <= 0;
		else if(cp2)
			c2 <= c2+1;
	end
	
	typedef enum {start1, plus1, trg2, Wait1} state_t1;
	state_t1 ps1, ns1;
	typedef enum {start2, plus2, trg1, Wait2} state_t2;
	state_t2 ps2, ns2;
	always_ff@(posedge clk)
	begin
		if(rst) ps1 <= start1;
		else ps1 <= ns1;
	end
	always_ff@(posedge clk)
	begin
		if(rst) ps2 <= Wait2;
		else ps2 <= ns2;
	end
	
	//FSM1
	always_comb
	begin
		cp1 = 0; trigger2 = 0;
		case(ps1)
			start1:
			begin
				ns1 = plus1;
			end
			plus1:
			begin
				if(c1 == 5)
					ns1 = trg2;
				else
				begin
					cp1 = 1;
					ns1 = plus1;
				end
			end
			trg2:
			begin
				trigger2 = 1;
				ns1 = Wait1;
			end
			Wait1:
			begin
				if(trigger1 == 1)begin
					cp1 = 1;
					ns1 = plus1;
				end
				else
					ns1 = Wait1;
			end
		endcase
	end
	
	//FSM2
	always_comb
	begin
		cp2 = 0; trigger1 = 0;
		case(ps2)
			start2:
			begin
				ns2 = plus2;
			end
			plus2:
			begin
				if(c2 == 6)begin
					ns2 = trg1;
				end
				else
				begin
					cp2 = 1;
					ns2 = plus2;
				end
			end
			trg1:
			begin
				trigger1 = 1;
				ns2 = Wait2;
			end
			Wait2:
			begin
				if(trigger2 == 1)begin
					cp2 = 1;
					ns2 = plus2;
				end
				else
					ns2 = Wait2;
			end
		endcase
	end
endmodule