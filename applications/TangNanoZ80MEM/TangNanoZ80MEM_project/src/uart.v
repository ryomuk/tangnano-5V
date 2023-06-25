// simple UART module
// data 8bit, no parity, stop 1bit, no flow control
// by Ryo Mukai
// 2023/6/22

module uart_tx
  #(
    parameter CLK_FRQ   = 0, //clock frequency(Mhz)
    parameter BAUD_RATE = 0  //serial baud rate
    )
  (
   input       clk, //clock input
   input       reset_n,    //synchronous reset input, low active 
   input [7:0] tx_data,  //data to send
   input       tx_send,  // send data
   output reg  tx_ready, // tx module ready
   output      tx_pin    //serial data output
   );

  localparam   CYCLE = CLK_FRQ / BAUD_RATE;
  localparam   S_WAIT    = 1'd0; // wait for tx_send
  localparam   S_SEND    = 1'd1; // send bits

  reg	       state;
  reg [15:0]   cycle_cnt;  // baud counter
  reg [3:0]    bit_cnt;    // bit counter
  reg [8:0]    send_buf;
  reg	       tx_reg;     // serial data output

  assign tx_pin = tx_reg;

  always@(posedge clk)
    if(~reset_n)
      state <= S_WAIT;
    else
      case(state)
	S_WAIT: begin
	   tx_reg <= 1'b1;
	   tx_ready <= 1'b1;
	   if(tx_send) begin
	      send_buf <= {tx_data[7:0], 1'b0}; // data + startbit
	      tx_ready <= 0;
	      bit_cnt <= 0;
	      cycle_cnt <= 0;
	      state <= S_SEND;
	   end
	end
	S_SEND: begin
	   if(bit_cnt == 4'd10) begin
	      if(~tx_send) // wait for tx_send is negated
		state <= S_WAIT;
	   end
	   else begin
	      if(cycle_cnt == CYCLE - 1) begin
		 tx_reg <= send_buf[0];
		 bit_cnt <= bit_cnt + 1'b1;
		 // shift data and fill with stop bit
		 send_buf <= {1'b1, send_buf[8:1]};
		 cycle_cnt <= 0;
	      end
	      else
		cycle_cnt <= cycle_cnt + 1'b1;
	   end
	end
      endcase
endmodule 

module uart_rx
  #(
    parameter CLK_FRQ   = 0, //clock frequency(Hz)
    parameter BAUD_RATE = 0  //serial baud rate
    )
  (
   input	    clk, // clock input
   input	    reset_n, // synchronous reset input, low active 
   output reg [7:0] rx_data, // received serial data
   output reg	    rx_data_ready, // flag to indicate received data is ready
   input	    rx_clear, // clear the rx_data_ready flag
   input	    rx_pin          // serial data input
   );
  //calculates the clock cycle for baud rate 
  localparam	    CYCLE = CLK_FRQ / BAUD_RATE;
  //state machine code
  localparam	    S_WAIT      = 2'd0;
  localparam	    S_START     = 2'd1;
  localparam	    S_RECEIVE   = 2'd2;

  reg [1:0]	    state;
  reg [15:0]	    cycle_cnt; // baud counter
  reg [3:0]	    bit_cnt;   // bit counter
  reg [7:0]	    receive_buf;      // received data buffer
  
  always@(posedge clk)
    if(~reset_n | rx_clear) begin
       state <= S_WAIT;
       rx_data_ready <= 0;
    end
    else 
      case(state)
	S_WAIT: begin
	   if(rx_pin == 1'b0) begin // detect start bit
	      state <= S_START;
	      cycle_cnt <= 0;
	      bit_cnt <= 0;
	      receive_buf <= 8'h00;
	   end
	end
	S_START:
	  if( cycle_cnt == (CYCLE / 2)-1) begin
	     // wait 1/2 CYCLE for latch at the middle of data bits)
	     cycle_cnt <= 0;
	     state <= S_RECEIVE;
	     rx_data <= 8'h55; // for debug, can be omitted(?)
	  end
	  else
	    cycle_cnt <= cycle_cnt + 1'b1;
	S_RECEIVE:
	  if( cycle_cnt == CYCLE - 1) begin
	     if(bit_cnt == 4'd8) begin
		if(rx_pin == 1'b1) begin // detect stop bit
		   rx_data <= receive_buf;
		   rx_data_ready <= 1'b1;
		end
		state <= S_WAIT;
	     end
	     else begin
		receive_buf[7:0] <= {rx_pin, receive_buf[7:1]};
		bit_cnt <= bit_cnt + 1'b1;
		cycle_cnt <= 0;
	     end
	  end
	  else
	    cycle_cnt <= cycle_cnt + 1'b1;
      endcase
endmodule 
