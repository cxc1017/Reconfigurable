module spi_tx(
	input clk,
	input rst,
	input tx_req,
	input sclk,
	input ssn,
	input mosi,
	input [7:0] address,
	input [15:0] data,
	input [15:0] data_fifo,
	output logic miso
);
	
	logic rst_send_data_cnt, load_shift_data, shift_en, read_en, write_en;
	logic s_signal, d_signal, sclk_negedge;
	logic [31:0] send_data_cnt;
	logic [15:0] write_data, read_data, shift_data;
	logic [15:0] reg_file [255:0];
	//logic [7:0] address;
	
	
	//sclk_negedge edge_detector
	always_ff@(posedge clk)
	begin
		if(rst)
		begin
			s_signal <= 1'b0;
			d_signal <= 1'b0;
			sclk_negedge <= 1'b0;
		end
		else
		begin
			{d_signal, s_signal} <= {s_signal, sclk};
			sclk_negedge <= ~s_signal & d_signal;
		end
	end
	
	//cnt
	always_ff@(posedge clk)
	begin
		if(rst | rst_send_data_cnt)
			send_data_cnt <= 0;
		else if(sclk_negedge)
			send_data_cnt <= send_data_cnt + 1;
	end
	
	
	
	//shift_register
	always_ff@(posedge clk)
	begin
		if(rst)
			shift_data <= 0;
		else if(load_shift_data)
			if(address[7])
				shift_data <= data_fifo;
			else
				shift_data <= data;
		else if(shift_en) begin
			shift_data <= {shift_data[14:0], 1'b0};
			miso <= shift_data[15];
		end
	end
	
	//assign miso = shift_data[15];
	
	typedef enum {INIT, START_SPI_TX, SEND_DATA, FINISH}state_t;
	state_t ps, ns;
	
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
		load_shift_data = 0; shift_en = 0; ns = ps;
		rst_send_data_cnt = 0;
		case(ps)
			INIT:
			begin
				rst_send_data_cnt = 1;
				ns = START_SPI_TX;
			end
			START_SPI_TX:
			begin
				if(tx_req == 1)
				begin
					rst_send_data_cnt = 1;
					load_shift_data = 1;
					ns = SEND_DATA;
				end
				
			end
			SEND_DATA:
			begin
				if(send_data_cnt >= 16)
				begin
					rst_send_data_cnt = 1;
					//load_shift_data = 1;
					ns = FINISH;
				end
				else
				begin
					if(sclk_negedge)
						shift_en = 1;
					ns = SEND_DATA;
				end
			end
			FINISH:
			begin
				rst_send_data_cnt = 1;
				ns = INIT;
			end
		endcase
	end

endmodule