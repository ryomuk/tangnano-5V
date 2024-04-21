//---------------------------------------------------------------------------
// Tang Nano Z80 Memory on 9K
// Memory System for Z80 using Tang Nano 9K
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
// 2024/4/21
// -  ported from 20K to 9K
//---------------------------------------------------------------------------

//`define USE_PLL_CLK  // CLK = PLL clock (defined by IP Core Generator)
//`define USE_SYS_CLK  // CLK = sys_clk (27MHz)
`define USE_DIV_CLK  // CLK = divided sys_clk (defined by Z80CLK_FRQ)

module top(
	   input	sw1_n,
	   input	sw2_n,
	   output [5:0]	led,
	   input	sys_clk, // 27MHz system clock
	   input	uart_rx,
	   output	uart_tx,
	   output	CLK,
	   output reg	RESET_n,
	   output	INT_n,
//	   output       NMI_n,
	   input	M1_n,
	   inout [7:0]	D,
	   input	MREQ_n,
	   input	IORQ_n,
	   input	WR_n,
	   input	RD_n,
	   input [15:0]	A,
	   output [1:0]	DBG_TX,
	   output	DBG_TRG
	   );

  parameter     SYSCLK_FRQ  = 27_000_000; //Hz

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
//  parameter	 IVECTOR_UART_RECV = 8'h3C; // SBC Z80 PaloAlto BASIC
//  parameter	 IVECTOR_UART_RECV = 8'hFF; // SBC8080

  reg [7:0]	 mem[16383:0]; // 16K ROM
  reg [7:0]	 ram[32768:0]; // 32K RAM

  wire		 sw1 = ~sw1_n;
  wire		 sw2 = ~sw2_n;

//  reg [7:0]	 mem[65535:0];

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
	     (~MREQ_n & ~RD_n) ? 
	       (address[15] ? ram[address[14:0]] :  // RAM on (8000H-FFFFH)
 		              mem[address[13:0]]) : // ROM on (0000H-3FFFH)
	     (~IORQ_n & ~RD_n) ? io_data      :
	     8'bzzzz_zzzz;
  
//---------------------------------------------------------------------------
// Memory
//---------------------------------------------------------------------------
// always @(posedge CLK)
//  always @(posedge CLK or negedge CLK)
//    if(~MREQ_n)
//      address <= A;
  always @(negedge MREQ_n) begin
     address     <= A;
  end
  
  wire write_memory = (~MREQ_n & ~WR_n);
  always @(posedge write_memory)
    if(address[15] == 1'b1) begin // 8000H-FFFFH RAM Area
//    if(address[15:14] == 2'b10) begin // 8000H-BFFFH RAM Area
//     mem[address] <= D;
       ram[address[14:0]] <= D;
    end
  
//---------------------------------------------------------------------------
// I/O
//---------------------------------------------------------------------------
  always @(negedge IORQ_n)
    address_io <= A[7:0];

  // UART SEND
  always @(posedge CLK)
    if(~IORQ_n & ~WR_n & address_io == IOADDR_UART_DATA) begin
       tx_data[7:0] <= D[7:0];
       tx_send <= 1'b1;
    end
//    else if(sw2) begin
//       tx_data[7:0] <= 8'h23; // for debug
//       tx_send <= 1'b1;
//    end
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

//---------------------------------------------------------------------------
// for debug
//---------------------------------------------------------------------------
  reg [25:0]		cnt_500ms;
  reg			clk_1Hz;

//  assign DBG_TRG = rx_data_ready;
  assign DBG_TRG = INT_n;

//  parameter	 UART_BPS_DBG    =     2_700_000; //Hz (27_000_000 / 10)
//  parameter	 UART_BPS_DBG    =     6_750_000; //Hz (27_000_000 / 4)
  parameter	 UART_BPS_DBG    =    13_500_000; //Hz (27_000_000 / 2)

  reg [7:0]	 dbg_tx_data[0:1];
  reg [1:0]	 dbg_tx_send;
  wire [1:0]     dbg_tx_ready;
  wire [1:0]	 dbg_tx;

  assign DBG_TX = dbg_tx;
  assign led[5:0] = ~{address[13:10], tx_ready, rx_data_ready};
  reg  last_RD_n;
  always @(posedge sys_clk) begin
     if(last_RD_n & ~RD_n) begin // negedge of RD
	if(dbg_tx_ready == 2'b11) begin
	   if(~sw2) begin
	      dbg_tx_data[0] <= address[7:0];
	      dbg_tx_data[1] <= address[15:8];
	   end
	   else begin
	      dbg_tx_data[0] <= address[7:0];
	      dbg_tx_data[1] <= mem[address];
	   end
	   dbg_tx_send <= 2'b11;
	end
     end
     else begin
	dbg_tx_send <= 2'b0;
     end
     last_RD_n <= RD_n;
  end

  uart_tx#
    (
     .CLK_FRQ(SYSCLK_FRQ),
     .BAUD_RATE(UART_BPS_DBG)
     ) uart_tx_inst_dbg0
      (
       .clk           (sys_clk),
       .reset_n       (RESET_n),
       .tx_data       (dbg_tx_data[0]),
       .tx_send       (dbg_tx_send[0]),
       .tx_ready      (dbg_tx_ready[0]),
       .tx_out        (dbg_tx[0])
       );

  uart_tx#
    (
     .CLK_FRQ(SYSCLK_FRQ),
     .BAUD_RATE(UART_BPS_DBG)
     ) uart_tx_inst_dbg1
      (
       .clk           (sys_clk),
       .reset_n       (RESET_n),
       .tx_data       (dbg_tx_data[1]),
       .tx_send       (dbg_tx_send[1]),
       .tx_ready      (dbg_tx_ready[1]),
       .tx_out        (dbg_tx[1])
       );

endmodule

