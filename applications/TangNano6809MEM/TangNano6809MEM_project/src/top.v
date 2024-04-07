//---------------------------------------------------------------------------
// Tang Nano 20K 6809 Memory
// Memory System for 6809 using Tang Nano 20K
//
// by Ryo Mukai
// 2023/7/19
// 2024/4/7
//---------------------------------------------------------------------------

`define USE_PLL_CLK  // CLK = PLL clock (defined by IP Core Generator)
//`define USE_SYS_CLK  // CLK = sys_clk (27MHz)
//`define USE_DIV_CLK  // CLK = divided sys_clk (defined by CPUCLK_FRQ)

module top(
    input	 sw1,
    input	 sw2,
    input	 sys_clk, // 27MHz system clock
    input	 uart_rx,
    output	 uart_tx,
    output	 CLK,
    input	 E,
    output reg	 RESET_n,
    output	 IRQ_n,
    input	 RW_n,
    inout [7:0]	 D,
    input [15:0] A,
    output	 HALT_n,
    output	 NMI_n,
    output	 FIRQ_n,
    output	 LED_RGB, 
    output	 DBG
    );

  parameter	 SYSCLK_FRQ  = 27_000_000; //Hz

`ifdef USE_DIV_CLK
  parameter	 CPUCLK_FRQ  =    800_000; //Hz // for debug
//  parameter	 CPUCLK_FRQ  =  5_400_000; //Hz (27M/5)
//  parameter	 CPUCLK_FRQ  =  6_750_000; //Hz (27M/4)
//  parameter	 CPUCLK_FRQ  =  9_000_000; //Hz (27M/3)
//  parameter	 CPUCLK_FRQ  = 13_500_000; //Hz (27M/2)
`endif
  
    parameter	 UART_BPS    =     115200; //Hz
//  parameter	 UART_BPS    =       9600; //Hz
  parameter	 ADDR_UART_STAT = 16'h8018; // memory mapped I/O
  parameter	 ADDR_UART_DATA = 16'h8019; // memory mapped I/O


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
  reg		 rx_clear = 0;

  wire [7:0]	 uart_data;
  wire [7:0]	 uart_stat;
  
//---------------------------------------------------------------------------
// for debug
//---------------------------------------------------------------------------
  parameter	 UART_BPS_DBG    =     2_700_000; //Hz
  reg [7:0]	 tx_data_dbg;
  reg		 tx_send_dbg;
  wire		 tx_ready_dbg;
  wire		 uart_tx_dbg;

  reg [7:0]		LED_R;
  reg [7:0]		LED_G;
  reg [7:0]		LED_B;
  
//  assign DBG = uart_tx_dbg;
  assign DBG =  sw2 ? 1: 0;

  ws2812 onboard_rgb_led(.clk(sys_clk), .we(1'b1), .sout(LED_RGB),
			 .r(LED_R), .g(LED_G), .b(LED_B));

  always @(posedge sys_clk)
    if(~RESET_n)
      {LED_R, LED_G, LED_B} <= 24'h00_00_00;
    else begin
       LED_R <= ( ~IRQ_n )        ? 8'h10: 8'h00;
       LED_G <= ( rx_data_ready ) ? 8'h10: 8'h00;
       LED_B <= ( tx_ready )      ? 8'h10: 8'h00;
    end

  reg lastE;
  always @(posedge  sys_clk) begin
     lastE <= E;
     if( ~lastE & E) begin
	if(tx_ready_dbg) begin
	   tx_data_dbg <= sw2 ? A[7:0]: D;
	   tx_send_dbg <= 1;
	end
     end
     else if(~tx_ready_dbg)
       tx_send_dbg <= 0;
  end
  uart_tx#
    (
     .CLK_FRQ(SYSCLK_FRQ),
     .BAUD_RATE(UART_BPS_DBG)
     ) uart_tx_inst_dbg
      (
       .clk           (sys_clk),
       .reset_n       (RESET_n),
       .tx_data       (tx_data_dbg),
       .tx_send       (tx_send_dbg),
       .tx_ready      (tx_ready_dbg),
       .tx_out        (uart_tx_dbg)
       );

//---------------------------------------------------------------------------
// unimplemented signals
//---------------------------------------------------------------------------
  assign  HALT_n = 1'b1;
  assign  NMI_n  = 1'b1;
  assign  FIRQ_n = 1'b1;

//---------------------------------------------------------------------------
// ROM DATA
//---------------------------------------------------------------------------
`include "rom.v"
  
  wire	 reset_sw;
  assign reset_sw = sw1;
  
//---------------------------------------------------------------------------
// clock for CPU
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
    if(clk_cnt == ((SYSCLK_FRQ / CPUCLK_FRQ)/2 - 1)) begin
       CLK_div = ~CLK_div;
       clk_cnt <= 0;
    end
    else
      clk_cnt <= clk_cnt + 1'd1;
`endif
//---------------------------------------------------------------------------
// reset button and power on reset
//---------------------------------------------------------------------------
  reg [15:0]	 reset_cnt = 0;
  parameter	 RESET_WIDTH = 16'd27000; // 1ms
  always @(posedge sys_clk)
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
  assign D = RW_n ?
	     ((address == ADDR_UART_DATA) ? uart_data :
	      (address == ADDR_UART_STAT) ? uart_stat :
	      mem[address]
	      ) :
	     8'bzzzz_zzzz;
  
//---------------------------------------------------------------------------
// Memory
//---------------------------------------------------------------------------
  always @(posedge E)
    address <= A;

  always @(negedge E)
    if( ~RW_n ) // write
      if(address[15] == 0) // 0000H to 7FFFH is RAM
	mem[address] <= D;
  
//---------------------------------------------------------------------------
// I/O (Memory Mapped)
//---------------------------------------------------------------------------
  assign uart_data = rx_data;
  assign uart_stat = {6'b0000_00, tx_ready, rx_data_ready};

  // UART SEND
  always @(negedge E)
    if(~RW_n & address == ADDR_UART_DATA) begin
       tx_data[7:0] <= D[7:0];
       tx_send <= 1'b1;
    end
    else if(~tx_ready)
      tx_send <= 1'b0;
  
  // READ UART registers
  always @(posedge E)
    if(RW_n & address == ADDR_UART_DATA)
      rx_clear <= 1;
    else
      if(rx_data_ready == 1'b0)
	rx_clear <= 0;  // disable rx_clear after rx_data_ready is cleared

//---------------------------------------------------------------------------
// Interrupt
//---------------------------------------------------------------------------
  // assign INT_n = ~rx_data_ready;
  assign IRQ_n = 1'b1;

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
