//---------------------------------------------------------------------------
// Tang Nano 20K Z80 Memory
// Memory System for Z80 using Tang Nano 20K
//
// by Ryo Mukai
// 2023/6/24
//---------------------------------------------------------------------------

`define USE_PLL
module top(
    input	 sw1,
    input	 sw2,
    input	 sys_clk, // 27MHz system clock
    input	 uart_rx,
    output	 uart_tx,
`ifdef USE_PLL
    output	 CLK, // clock for Z80 (PLL)
`else
    output reg	 CLK, // clock for Z80 (non PLL)
`endif
    output reg	 RESET_n,
    output	 INT_n,
    input	 M1_n,
    inout [7:0]	 D,
    input	 MREQ_n,
    input	 IORQ_n,
    input	 WR_n,
    input	 RD_n,
    input [15:0] A,
    output	 LED_RGB, 
    output 	 DBG_TRG
    );

  parameter	 SYSCLK_FRQ  = 27_000_000; //Hz

//  parameter	 Z80CLK_FRQ  =  2_250_000; //Hz
//  parameter	 Z80CLK_FRQ  =  2_700_000; //Hz
//  parameter	 Z80CLK_FRQ  =  3_375_000; //Hz
//  parameter	 Z80CLK_FRQ  =  4_500_000; //Hz
//  parameter	 Z80CLK_FRQ  =  6_750_000; //Hz
//  parameter	 Z80CLK_FRQ  =  9_000_000; //Hz
  parameter	 Z80CLK_FRQ  = 13_500_000; //Hz

    parameter	 UART_BPS    =     115200; //Hz
//  parameter	 UART_BPS    =      38400; //Hz
//  parameter	 UART_BPS    =       9600; //Hz
  parameter	 IOADDR_UART_DATA = 8'h00;
  parameter	 IOADDR_UART_CTRL = 8'h01;

// Int Vector for UART receive (hard coding)
  parameter	 IVECTOR_UART_RECV = 8'h6C; // SBC Z80 Grant BASIC
//  parameter	 IVECTOR_UART_RECV = 8'hFF; // SBC8080

  reg [7:0]	 mem[65535:0];
  reg [7:0]	 mem_data;
  reg [7:0]	 io_data;
  wire [15:0]	 address = A;
  wire [7:0]	 address_io = A[7:0];

  wire [7:0]	 int_vector;
    
  
  reg [7:0]	 tx_data;
  reg		 tx_send;
  wire		 tx_ready;
  wire [7:0]	 rx_data;
  wire		 rx_data_ready;
  reg		 rx_clear;

//---------------------------------------------------------------------------
// for debug
//---------------------------------------------------------------------------
  reg [7:0]		LED_R;
  reg [7:0]		LED_G;
  reg [7:0]		LED_B;
  
//  assign DBG_TRG = rx_data_ready;
//  assign DBG_TRG = (address == 16'h006C & ~M1_n);
//  assign DBG_TRG = ~M1_n & ~IORQ_n;
  assign DBG_TRG = D == 8'h6C;

//  assign LED_RGB = (~sw2) ? uart_rx : rx_data_ready;
  ws2812 onboard_rgb_led(.clk(sys_clk), .we(1'b1), .sout(LED_RGB),
			 .r(LED_R), .g(LED_G), .b(LED_B));

  always @(posedge CLK)
    if(~RESET_n)
      {LED_R, LED_G, LED_B} <= 24'h00_00_00;
    else begin
       LED_R <= ( ~INT_n )        ? 8'h10: 8'h00;
       LED_G <= ( rx_data_ready ) ? 8'h10: 8'h00;
       LED_B <= ( tx_ready )      ? 8'h10: 8'h00;
    end

//---------------------------------------------------------------------------
// ROM DATA
//---------------------------------------------------------------------------
`include "rom.v"
  
  wire		 reset_sw;
  assign reset_sw = sw1;
  
//---------------------------------------------------------------------------
// clock for Z80
//---------------------------------------------------------------------------

`ifdef USE_PLL
  Gowin_rPLL PLL(
		 .clkout(CLK), //output clkout
		 .clkin(sys_clk) //input clkin
		 );
`else
  reg [7:0]	 clk_cnt = 0;
  always @(posedge sys_clk)
    if(clk_cnt == ((SYSCLK_FRQ / Z80CLK_FRQ)/2 - 1)) begin
       CLK = ~CLK;
       clk_cnt <= 0;
    end
    else
      clk_cnt <= clk_cnt + 1'd1;
`endif
//---------------------------------------------------------------------------
// reset button and power on reset
//---------------------------------------------------------------------------
  reg [7:0]	 reset_cnt = 0;
  parameter	 RESET_WIDTH = 8'd128; // clock count
  always @(posedge CLK)
    if(reset_sw) begin
       RESET_n <= 0;
       reset_cnt <= 0;
    end
    else if (reset_cnt != RESET_WIDTH) begin
       RESET_n <= 0;
       reset_cnt <= reset_cnt + 1'd1;
    end
    else
      RESET_n <= 1;
       
//---------------------------------------------------------------------------
// Memory and IO
//---------------------------------------------------------------------------
  assign D = (~RD_n & ~MREQ_n) ? mem_data :
	     (~M1_n & ~IORQ_n) ? int_vector   :
	     (~RD_n & ~IORQ_n) ? io_data      :
	     8'bzzzz_zzzz;
  
//---------------------------------------------------------------------------
// Memory
//---------------------------------------------------------------------------
 always @(posedge CLK)
   if(~MREQ_n & ~RD_n) begin
      mem_data <= mem[address];
   end
  always @(posedge CLK)
     if(~MREQ_n & ~WR_n)
       if(address[15] == 1'b1) begin // 0000H to 7FFFH is ROM
	  mem[address] <= D;
//	  DBG_TRG = ~DBG_TRG;
       end
  
//---------------------------------------------------------------------------
// I/O
//---------------------------------------------------------------------------
  // UART SEND
  always @(posedge CLK)
    if(~IORQ_n & ~WR_n & address_io == IOADDR_UART_DATA) begin
       tx_data[7:0] <= D[7:0];
       tx_send <= 1'b1;
    end
    else
      tx_send <= 1'b0;

  // READ UART registers
  always @(posedge CLK)
    if(~IORQ_n & ~RD_n)
      case(address_io)
	IOADDR_UART_DATA: begin // Data register
	   io_data <= rx_data;
	   rx_clear <= 1;
	end
	IOADDR_UART_CTRL: // Control register
//	  io_data <= {6'b000000, rx_data_ready, tx_ready};// for SBC8080
	  // for SBCZ80 Grant's BASIC
	  io_data <= {5'b00000, tx_ready, rx_data_ready, 1'b0};
      endcase
    else
      if(rx_data_ready == 1'b0)
	rx_clear <= 0;  // disable rx_clear after rx_data_ready is cleared

//---------------------------------------------------------------------------
// Interrupt
//---------------------------------------------------------------------------
  assign int_vector = IVECTOR_UART_RECV;

// Set and Reset INT_n
//  UART_int UART_int_module(.clk(CLK),
//			   .reset_n(RESET_n),
//			   .set(rx_data_ready), 
//			   .clear(~M1_n & ~IORQ_n),
//			   .int_n(INT_n));

  assign INT_n = ~rx_data_ready;
//---------------------------------------------------------------------------
// UART
//---------------------------------------------------------------------------
  
  uart_rx#
    (
     .CLK_FRQ(SYSCLK_FRQ),
     .BAUD_RATE(UART_BPS)
     ) uart_rx_inst
      (
       .clk           (sys_clk      ),
       .reset_n       (RESET_n      ),
       .rx_data       (rx_data      ),
       .rx_data_ready (rx_data_ready),
       .rx_clear      (rx_clear),
       .rx_pin        (uart_rx      )
       );

  uart_tx#
    (
     .CLK_FRQ(SYSCLK_FRQ),
     .BAUD_RATE(UART_BPS)
     ) uart_tx_inst
      (
       .clk           (sys_clk),
       .reset_n       (RESET_n),
       .tx_data       (tx_data),
       .tx_send       (tx_send),
       .tx_ready      (tx_ready),
       .tx_pin        (uart_tx)
       );

endmodule

//module UART_int(
//		input	   clk,
//		input	   reset_n,
//		input	   set,
//		input	   clear,
//		output reg int_n
//		);
//  localparam		   S_WAIT_FOR_START  = 0;
//  localparam		   S_WAIT_FOR_SET    = 1;
//  localparam		   S_WAIT_FOR_CLEAR  = 2;
//
//  reg	[1:0]		   state;
//  always @(posedge clk)
//    if(~reset_n) begin
//       state <= S_WAIT_FOR_START;
//       int_n <= 1'b1;
//    end
//    else
//      case (state)
//	S_WAIT_FOR_START:
//	  if(~set)
//	    state <= S_WAIT_FOR_SET;
//	S_WAIT_FOR_SET:
//	  if(set) begin
//	     int_n <= 1'b0;
//	     state <= S_WAIT_FOR_CLEAR;
//	  end
//	S_WAIT_FOR_CLEAR:
//	  if(clear) begin
//	     int_n <= 1'b1;
//	     state <= S_WAIT_FOR_START;
//	  end
//      endcase
//endmodule
