module spi_rx(
	input clk,
	input rst,
	input sclk,
	input mosi,
	input ssn,
	output logic [7:0] address,
	output logic [15:0] data,
	output logic read_en,
	output logic write_en,
	output logic tx_req
);
	
	logic shift_en, load_rw, load_addr, rx_finish, rst_data_cnt, load_data;
	logic s_signal, d_signal, s_signal1, d_signal1, ssn_negedge, sclk_posedge, rw;
	logic [31:0] receive_data_cnt;
	logic [15:0] shift_data;
	logic [15:0] read_data;
	logic [15:0] reg_file [255:0];
	
	//ssn_negedge edge_dectector
	always_ff@(posedge clk)
	begin
		if(rst)
		begin
			s_signal <= 1'b0;
			d_signal <= 1'b0;
			ssn_negedge <= 1'b0;
		end
		else
		begin
			{d_signal, s_signal} <= {s_signal, ssn};
			ssn_negedge <= ~s_signal & d_signal;
		end
	end
	//sclk_posedge edge_dectector
	always_ff@(posedge clk)
	begin
		if(rst)
		begin
			s_signal1 <= 1'b0;
			d_signal1 <= 1'b0;
			sclk_posedge <= 1'b0;
		end
		else
		begin
			{d_signal1, s_signal1} <= {s_signal1, sclk};
			sclk_posedge <= s_signal1 & ~d_signal1;
		end
	end

	
	//cnt
	always_ff@(posedge clk)
	begin
		if(rst | rst_data_cnt)
			receive_data_cnt <= 0;
		else if(sclk_posedge)
			receive_data_cnt <= receive_data_cnt + 1;
	end
	
	//shift_register
	always_ff@(posedge clk)
	begin
		if(rst)
			shift_data <= 0;
		if(ssn)
			shift_data <= 0;
		else if(shift_en)
			shift_data <= {shift_data[14:0], mosi};			
	end
	
	//rw register
	always_ff@(posedge clk)
	begin
		if(rst)
			rw <= 0;
		else if(load_rw)
			rw <= shift_data[0];
	end
	//address
	always_ff@(posedge clk)
	begin
		if(rst)
			address <= 0;
		else if(load_addr)
			address <= shift_data[7:0];
	end
	//data
	always_ff@(posedge clk)
	begin
		if(rst)
			data <= 0;
		else if(load_data)
			data <= shift_data;
	end
	
	//register_file
	always_ff@(posedge clk)
	begin
		if(write_en)
			reg_file[address] <= data;
		else if(read_en)
			read_data <= reg_file[address];
	end
	
	typedef enum {INIT, START_SPI_RX, RECEIVE_ADDRESS, DUMMY
				, CHECK_RW, RECEIVE_DATA, TX_REQ, FINISH, WRITE, RECEIVE_COMMAND}state_rx;
	state_rx ps, ns;
	
	always_ff@(posedge clk)
	begin
		if(rst)
			ps <= INIT;
		else 
			ps <= ns;
	end
	
	//FSM
	always_comb
	begin
		shift_en = 0; load_rw = 0; load_addr = 0; load_data = 0; rst_data_cnt = 0;
		ns = ps; read_en = 0; write_en = 0; tx_req = 0; rx_finish = 0;
		case(ps)
			INIT:
			begin
				ns = START_SPI_RX;
			end
			START_SPI_RX:
			begin
				if(ssn_negedge)
				begin
					//shift_en = 1;
					rst_data_cnt = 1;
					ns = RECEIVE_ADDRESS;
				end
				else
					ns = START_SPI_RX;
			end
			RECEIVE_ADDRESS:
			begin
				if(receive_data_cnt > 7)	//傳完後載入address
				begin
					load_addr = 1;
					ns = RECEIVE_COMMAND;
				end
				else 				//0~7bit傳address
				begin
					if(sclk_posedge)
						shift_en = 1;
					ns = RECEIVE_ADDRESS;
				end
			end
			RECEIVE_COMMAND:
			begin
				if(receive_data_cnt == 9)		//第9bit載入
				begin
					load_rw = 1;
					ns = DUMMY;
				end
				else 							//第8bit傳rw
				begin
					if(sclk_posedge)
						shift_en = 1;
				end
			end
			DUMMY:
			begin
				if(receive_data_cnt > 15)	
				begin
					rst_data_cnt = 1;
					ns = CHECK_RW;
				end
				else 					//9-15bit don't care
				begin
					
					ns = DUMMY;
				end
			end
			CHECK_RW:
			begin
				if(rw)				//rw = 1 -> read
					ns = TX_REQ;
				else 
				begin				//rw = 0 -> write
					rst_data_cnt = 1;	//16bit結束, 要重算
					ns = RECEIVE_DATA;
				end
			end
			TX_REQ:
			begin
				tx_req = 1;
				read_en = 1;
				ns = FINISH;
			end
			RECEIVE_DATA:
			begin
				if(receive_data_cnt > 15)	//16bit傳完, 要載入
				begin
					load_data = 1;
					ns = WRITE;
				end
				else 
				begin						//0~15bit傳資料
					if(sclk_posedge)
						shift_en = 1;
					ns = RECEIVE_DATA;
				end
			end
			WRITE:
			begin
				write_en = 1;
				ns = FINISH;
			end
			FINISH:
			begin
				rst_data_cnt = 1;
				rx_finish = 1;
				ns = INIT;
			end
		endcase
	end
	
endmodule