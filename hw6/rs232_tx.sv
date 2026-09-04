module rs232_tx(
	input clk,
	input rst,
	//input baud_setting,
	input tx_req,
	input [7:0] tx_data,
	output logic tx,
	output logic tx_ack
);
	
	logic shift_enable, load_tx_data;
	logic [3:0] cnt;
	logic [10:0] baud_cnt, baud_cnt_max;
	logic [9:0] data;
	
	assign baud_cnt_max = 1302;
	
	always_ff@(posedge clk) 
	begin
		if(rst || cnt == 10)
			cnt <= 0;
		else if(shift_enable)
			cnt <= cnt + 1;
	end
	
	always_ff@(posedge clk)
	begin
		if(rst || baud_cnt == baud_cnt_max)
		begin
			baud_cnt <= 0;
		end
		else if(baud_cnt < baud_cnt_max)
			baud_cnt <= baud_cnt + 1;
	end
	
	always_ff @(posedge clk)
	begin
		if (rst)
			data <= 0;
		else if (load_tx_data)
			data <= {1'b1, tx_data[7:0], 1'b0};
		else if (shift_enable)
			//data <= data >> 1;
			data <= {1'b1, data[9:1]};

	end

	
	always_ff@(posedge clk)
	begin
		if(rst)
			tx <= 1;
		else if(shift_enable)
			tx <= data[0];
	end
	
	typedef enum {IDLE, CHK_REQ, LD_TX_DATA, CHK_BIT_CNT, TRAns_tx, COMP}state_tx;
	state_tx ps_tx, ns_tx;
	
	always_ff@(posedge clk)
	begin
		if(rst)
			ps_tx <= IDLE;
		else 
			ps_tx <= ns_tx;
	end
	
	always_comb
	begin
		shift_enable = 0; load_tx_data = 0; tx_ack = 0;
		case(ps_tx)
			IDLE:
			begin
				ns_tx = CHK_REQ;
			end
			CHK_REQ:
			begin
				if(tx_req == 1)
					ns_tx = LD_TX_DATA;
				else
					ns_tx = CHK_REQ;
			end
			LD_TX_DATA:
			begin
				load_tx_data = 1;
				//shift_enable = 1;
				ns_tx = CHK_BIT_CNT;
			end
			CHK_BIT_CNT:
			begin
				if(cnt == 10)
					ns_tx = COMP;
				else 
					ns_tx = TRAns_tx;
			end
			TRAns_tx:
			begin
				if(baud_cnt < baud_cnt_max)
					ns_tx = TRAns_tx;
				else 
				begin
					shift_enable = 1;
					ns_tx = CHK_BIT_CNT;
				end
			end
			COMP:
			begin
				if(tx_req == 0)
				begin
					tx_ack = 1;
					ns_tx = CHK_REQ;
				end
				else
					ns_tx = COMP;
			end
		endcase
	end
endmodule