//---------------------------------------------------------------------------
// Tang Nano 20K Z80 Memory
// Memory System for Z80 using Tang Nano 20K
//
// by Ryo Mukai
// 2023/7/6
// - initial version
// 2024/4/7
// - some port names for uart.v changed
// - default clock changed to USE_DIV_CLK(13.5MHz)
// 2024/4/17
// - bug fix (memory write timing)
// - indicate state of UART and heartbeat on RGB LED
// - rx_data_ready in IOADDR_UART_CTRL moved from bit1 to bit0
// 2024/4/27
// - tx_send timing fixed for fast CPU clock
//---------------------------------------------------------------------------

//`define USE_PLL_CLK  // CLK = PLL clock (defined by IP Core Generator)
`define USE_SYS_CLK  // CLK = sys_clk (27MHz)
//`define USE_DIV_CLK  // CLK = divided sys_clk (defined by Z80CLK_FRQ)

module top(
    input	 sw1,
    input	 sw2,
    input	 sys_clk, // 27MHz system clock
    input	 uart_rx,
    output	 uart_tx,
    output	 CLK,
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

`ifdef USE_DIV_CLK
// CLK=SYSCLK/n (n must be even number)
//  parameter	 Z80CLK_FRQ  =    500_000; //Hz (SYSCLK/54)
//  parameter	 Z80CLK_FRQ  =  4_500_000; //Hz (SYSCLK/6)
//  parameter	 Z80CLK_FRQ  =  6_750_000; //Hz (SYSCLK/4)
  parameter	 Z80CLK_FRQ  = 13_500_000; //Hz (SYSCLK/2)
`endif
  
    parameter	 UART_BPS    =     115200; //Hz
//  parameter	 UART_BPS    =       9600; //Hz
  parameter	 IOADDR_UART_DATA = 8'h00;
  parameter	 IOADDR_UART_CTRL = 8'h01;

// Int Vector for UART receive (hard coding)
  parameter	 IVECTOR_UART_RECV = 8'h6C; // SBC Z80 Grant BASIC
//  parameter	 IVECTOR_UART_RECV = 8'h3C; // SBC Z80 PaloAlot BASIC
//  parameter	 IVECTOR_UART_RECV = 8'hFF; // SBC8080

  reg [7:0]	 mem[65535:0];
  reg [7:0]	 io_data;
  reg [15:0]	 address; // address or data of memory should be latched to infer BSRAM
  reg [7:0]	 address_io;

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
  
  reg [25:0]		cnt_500ms;
  reg			clk_1Hz;

//  assign DBG_TRG = rx_data_ready;
  assign DBG_TRG = ((address == 16'h0073) & (~M1_n | sw2));

//`define USE_RGBLED_FOR_DEBUG
`ifdef  USE_RGBLED_FOR_DEBUG
  // output debug signal to RGB_LED pin
  assign LED_RGB = ~M1_n & ~IORQ_n;
`else
  // indicate state of UART and heartbeat on RGB LED
  ws2812 onboard_rgb_led(.clk(sys_clk), .we(1'b1), .sout(LED_RGB),
			 .r(LED_R), .g(LED_G), .b(LED_B));
  always @(posedge sys_clk)
    if(cnt_500ms == SYSCLK_FRQ/2) begin
       cnt_500ms <= 0;
       clk_1Hz = ~clk_1Hz;
    end else 
      cnt_500ms <= cnt_500ms + 1'b1;

  always @(posedge CLK)
    if(~RESET_n)
      {LED_R, LED_G, LED_B} <= 24'h00_00_00;
    else begin
       LED_R <= ( rx_data_ready ) ? 8'h10: 8'h00;
       LED_G <= ( tx_ready      ) ? 8'h10: 8'h00;
       LED_B <= ( clk_1Hz       ) ? 8'h10: 8'h00;
    end
`endif

//---------------------------------------------------------------------------
// ROM DATA
//---------------------------------------------------------------------------
`include "rom.v"
  
  wire		 reset_sw;
  assign reset_sw = sw1;
  
//---------------------------------------------------------------------------
// clock for Z80
//---------------------------------------------------------------------------
`ifdef USE_PLL_CLK
  Gowin_rPLL PLL(
		 .clkout(CLK), //output clkout
		 .clkin(sys_clk) //input clkin
		 );
`endif

`ifdef USE_SYS_CLK
  assign CLK = sys_clk; 
`endif

`ifdef USE_DIV_CLK
  reg [7:0]	 clk_cnt = 0;
  reg		 CLK_div;
  assign CLK = CLK_div; 
  always @(posedge sys_clk)
    if(clk_cnt == ((SYSCLK_FRQ / Z80CLK_FRQ)/2 - 1)) begin
       CLK_div = ~CLK_div;
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
  assign D = (~M1_n & ~IORQ_n) ? int_vector   :
	     (~MREQ_n & ~RD_n) ? mem[address] :
	     (~IORQ_n & ~RD_n) ? io_data      :
	     8'bzzzz_zzzz;
  
//---------------------------------------------------------------------------
// Memory
//---------------------------------------------------------------------------
// always @(posedge CLK)
//  always @(posedge CLK or negedge CLK)
//    if(~MREQ_n)
//      address <= A;
  always @(negedge MREQ_n)
    address <= A;

  wire write_memory = (~MREQ_n & ~WR_n);
  always @(posedge write_memory)
//  always @(negedge write_memory) // this is wrong (2024/4/17)
    if(address[15] == 1'b1) begin // 0000H to 7FFFH is ROM
       mem[address] <= D;
//	  DBG_TRG = ~DBG_TRG;
    end
  
//---------------------------------------------------------------------------
// I/O
//---------------------------------------------------------------------------
  always @(negedge IORQ_n)
    address_io <= A[7:0];

  // UART SEND
//  always @(posedge CLK)
  always @(negedge CLK) // for fast CPU clock (I'm not sure, but it works)
    if(~IORQ_n & ~WR_n & address_io == IOADDR_UART_DATA) begin
       tx_data[7:0] <= D[7:0];
       tx_send <= 1'b1;
    end
//    else // for slow CPU clock
    else if(~M1_n) // for fast CPU clock
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
	  // for SBCZ80 Grant's BASIC and universal monitor
	  io_data <= {5'b00000, tx_ready, 1'b0, rx_data_ready};
      endcase
    else
      if(rx_data_ready == 1'b0)
	rx_clear <= 0;  // disable rx_clear after rx_data_ready is cleared

//---------------------------------------------------------------------------
// Interrupt
//---------------------------------------------------------------------------
  assign int_vector = IVECTOR_UART_RECV;

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
       .rx_in         (uart_rx      )
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
       .tx_out        (uart_tx)
       );

endmodule

