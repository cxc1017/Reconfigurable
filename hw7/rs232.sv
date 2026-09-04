module rs232(
	input clk,
	input rst,
	input rx,
	output logic[7:0] rx_data,
	output logic rx_finish,
	output logic [7:0] head,
	output logic [7:0] addr,
	output logic [7:0] data,
	output logic [7:0] r_w,
	output logic [7:0] tail,
	output logic pkg_ready,
	output logic [7:0] tx_data,
	output logic tx
);
	
	logic shift_enable, load_tx_data, bitflag, load_rx_data, cnt_rst, tx_ack;
	logic BAUD_CNT_MAX, BAUD_CNT_MAX_HALF, rst_pkg_cnt, rst_chk_sum_temp;
	logic add_chk_sum, load_chk_sum, rst_tx_idx, tx_req, rst_baud_cnt, write, inc_tx_idx, shift, read;
	logic [5:0] cnt, pkg_cnt;
	logic [15:0] baud_cnt, baud_cnt_max, baud_cnt_max_half;
	logic [9:0] data_rx;
	logic [7:0] reg_file [255:0];
	logic [7:0] addr1, addr2, data1, data2, data_r, checksum;
	logic [7:0] tx_data_temp [3:0];
	logic [1:0] s_signal, d_signal, rx_neg, tx_idx;
	
	assign baud_cnt_max = 1302;
	assign baud_cnt_max_half = 651;
	
	//tx
	rs232_tx tx1(
		.clk		(clk),
	    .rst		(rst),
	    .tx_req		(tx_req),
	    .tx_data	(tx_data),
	    .tx			(tx),
	    .tx_ack		(tx_ack)
	);
	
	
	//cnt
	always_ff@(posedge clk) 
	begin
		if(rst | cnt_rst)
			cnt <= 0;
		else if(bitflag)
			cnt <= cnt + 1;
	end
	
	//pkg_cnt
	always_ff@(posedge clk)
	begin
		if(rst | rst_pkg_cnt)
			pkg_cnt <= 1;
		/*else if(rst_pkg_cnt)
			pkg_cnt <= 2;*/
		else if(shift)
			pkg_cnt <= pkg_cnt + 1;
	end
	
	//baud_cnt
	always_ff@(posedge clk)
	begin
		if(rst | rst_baud_cnt)
			baud_cnt <= 0;
		else if(baud_cnt < baud_cnt_max)
			baud_cnt <= baud_cnt + 1;
		
	end
	
	//BOUD_CNT_MAX = 1 -> rst_baud_cnt = 1(fsm), bitflag = 1
	assign BAUD_CNT_MAX = baud_cnt >= baud_cnt_max;
	
	assign BAUD_CNT_MAX_HALF = baud_cnt == baud_cnt_max_half;
	
	//edge_detector
	always_ff@(posedge clk)
	begin
		if(rst)
		begin
			s_signal = 1'b1;
			d_signal = 1'b1;
			rx_neg 	 = 1'b0;
		end	
		else 
		begin
			{d_signal, s_signal} <= {s_signal, rx};
			rx_neg <= ~s_signal & d_signal;
		end
	end	
	
	//addr
	assign addr = {addr1[3:0], addr2[3:0]};
	
	always_ff@(posedge clk)
	begin
		if(rst)
		begin
			tail <= 0;
			//checksum <= 0;
			r_w <= 0;
			data2 <= 0;
			data1 <= 0;
			addr1 <= 0;
			addr2 <= 0;
			head <= 0;
			addr1 <= 0;
			addr2 <= 0;
		end
		else if(shift)
		begin
			{tail, r_w, data2, data1, addr2, addr1, head} <=
			{rx_data, tail, r_w, data2, data1, addr2, addr1};
		end
	end
	
	//data
	assign data = {data1[3:0], data2[3:0]};

	
	//rx_shift_register
	always_ff@(posedge clk)
	begin
		if(rst)
			rx_data <= 0;
		else if(bitflag)
			rx_data <= {rx, rx_data[7:1]};
	end
	
	//Register File
	always_ff@(posedge clk)
	begin
		if(write)
			reg_file[addr] <= data;
	end
	
	assign data_r = reg_file[addr];
	
	
	assign tx_data_temp[0] = 8'h02;
	assign tx_data_temp[1] = {4'h3, data_r[7:4]};
	assign tx_data_temp[2] = {4'h3, data_r[3:0]};
	assign tx_data_temp[3] = 8'h03;
	
	//tx_data
	always_ff@(posedge clk)
	begin
		if(rst | rst_tx_idx)
		begin
			tx_data <= 8'h02;
			tx_idx <= 0;
		end
		else if(inc_tx_idx)
		begin
			tx_data <= tx_data_temp[tx_idx++];
		end
	end
	
	typedef enum {START, RX_START, NUM_BITS, COMPLETE, RECEIVE, RW_REG_F
				, TX_REQ_1, TX_ACK_1, TX_REQ_2, TX_ACK_2, TX_REQ_3, TX_ACK_3
				, TX_REQ_4, TX_ACK_4}state_t;
	state_t ps, ns;
	
	always_ff@(posedge clk)
	begin
		if(rst)
			ps <= START;
		else 
			ps <= ns;
	end
	
	
	//RX_FSM
	always_comb
	begin
		cnt_rst = 0; rx_finish = 0; bitflag = 0; rst_pkg_cnt = 0; pkg_ready = 0; write = 0; read = 0; ns = ps;
		rst_chk_sum_temp = 0; load_chk_sum = 0; rst_tx_idx = 0; shift = 0; rst_baud_cnt = 0; tx_req = 0; inc_tx_idx = 0;
		case(ps) 
			START:
			begin
				//rst_chk_sum_temp = 1;
				ns = RX_START;
			end
			RX_START:
			begin
				if(rx_neg)
					ns = NUM_BITS;
				else 
					ns = RX_START;
			end
			NUM_BITS:
			begin
				rst_baud_cnt = 1;
				if(cnt > 8)
					ns = COMPLETE;
				else 
					ns = RECEIVE;
			end
			RECEIVE:
			begin
				//cnt_rst = 1;
				//rx_finish = 1;
				
				if(BAUD_CNT_MAX_HALF)
				begin
					bitflag = 1;
				end
				else if(BAUD_CNT_MAX)
				begin
					ns = NUM_BITS;
				end
				else 
					ns = RECEIVE;
			end
			COMPLETE:
			begin
				rx_finish = 1;
				cnt_rst = 1;
				shift = 1;
				if(pkg_cnt == 7)
				begin
					rst_pkg_cnt = 1;
					pkg_ready = 1;
					rst_chk_sum_temp = 1;
					ns = RW_REG_F;
				end
				else if(pkg_cnt < 7)
				begin
					add_chk_sum = 1;
					ns = RX_START;
				end
				else if(pkg_cnt == 6)
				begin
					load_chk_sum = 1;
					ns = RX_START;
				end
				else
				begin
					ns = RX_START;
				end
			end
			RW_REG_F:
			begin
				rst_tx_idx = 1;
				if(r_w[0])
				begin
					write = 1;
					ns = RX_START;
				end
				else
				begin
					read = 1;
					ns = TX_REQ_1;
				end
			end
			TX_REQ_1:
			begin
				tx_req = 1;
				inc_tx_idx = 1;
				ns = TX_ACK_1;
			end
			TX_ACK_1:
			begin
				if(tx_ack)
					ns = TX_REQ_2;
				else 
					ns = TX_ACK_1;
			end
			TX_REQ_2:
			begin
				tx_req = 1;
				inc_tx_idx = 1;
				ns = TX_ACK_2;
			end
			TX_ACK_2:
			begin
				if(tx_ack)
					ns = TX_REQ_3;
				else 
					ns = TX_ACK_2;
			end
			TX_REQ_3:
			begin
				tx_req = 1;
				inc_tx_idx = 1;
				ns = TX_ACK_3;
			end
			TX_ACK_3:
			begin
				if(tx_ack)
					ns = TX_REQ_4;
				else 
					ns = TX_ACK_3;
			end
			TX_REQ_4:
			begin
				tx_req = 1;
				inc_tx_idx = 1;
				ns = TX_ACK_4;
			end
			TX_ACK_4:
			begin
				if(tx_ack)
					ns = TX_REQ_4;
				else 
					ns = START;
			end
		endcase
	end
	
endmodule