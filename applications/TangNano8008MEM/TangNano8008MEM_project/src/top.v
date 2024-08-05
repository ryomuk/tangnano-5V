//---------------------------------------------------------------------------
// TangNano8008MEM 
// Memory system and peripherals on TangNano20K for Intel 8008
//
// by Ryo Mukai (https://github.com/ryomuk)
//
// 2024/08/04: - Initial version 
//---------------------------------------------------------------------------

//`define USE_RX_INTERRUPT

module top(
    input	 sw1,
    input	 sw2,
    input	 sys_clk, // 27MHz system clock
    input	 usb_rx,
    output	 usb_tx,
    input	 GPIO_RX,
    output	 GPIO_TX,

//    output	 sd_clk,
//    output	 sd_mosi, 
//    input	 sd_miso,
//    output	 sd_cs_n,
	   
    output	 CLK1,
    output	 CLK2,
    input	 SYNC,
    inout [7:0]	 D,
    input [2:0]	 S,
    output	 READY,
    output	 INTERRUPT,
	   
    output	 DBG_TRG2,
    output	 DBG_TRG,
    output [5:0] LED_n,
    output	 LED_RGB
    );

  parameter	 SYSCLK_FRQ  = 27_000_000; //Hz
  
//  parameter	 UART_BPS    =        110; //Hz (needs appropriate serial IF)
//  parameter	 UART_BPS    =        300; //Hz (minimum speed of FT232)
//  parameter	 UART_BPS    =       1200; //Hz (minimum speed of TangNano USB)
//  parameter	 UART_BPS    =       9600; //Hz
//  parameter	 UART_BPS    =      38400; //Hz
  parameter	 UART_BPS    =     115200; //Hz

//---------------------------------------------------------------------------
// 2 phase clock
//                  11111111112222222222333333333344444444445555
//        0123456789012345678901234567890123456789012345678901230123456
// CLK1 __~~~~~~~~~~~~~~~~~~~___________________________________~~~~~~
// CLK2 ___________________________~~~~~~~~~~~~~~~~~~___________
//        <-------------------------tcy------------------------->
//                           <----------tD1--------->
//        <-------tp1-------><tD3-><-----tp2--------><---tD2---->
//
// 8008: 333kHz-500kHz
//    (ns)      (ns) (cycle)            (ns)
//   2000<=tcy<=3000 (54.0-81)   54 = 2000.0
//    700<=tp1       (18.9-)     19 =  703.7
//    200<=tD3       ( 5.4-)      6 =  222.2
//    550<=tp2       (14.9-)     18 =  666.6
//    900<=tD1<=1100 (24.3-29.7) 24 =  888.8  (= tD3+tp2)
//    400<=tD2       (10.8-)     11 =  407.4
//
//                  11111111112222222222333333
//        012345678901234567890123456789012345012345
// CLK1 __~~~~~~~~~~__________________________~~~~~~
// CLK2 __________________~~~~~~~~~~________________
//        <--------------tcy----------------->
//                  <-----tD1------>
//        <--tp1---><-tD3><--tp2---><---tD2-->
//
// 8008-1: 333kHz-800kHz
//    (ns)      (ns)   (cycle)        (ns)
//   1250<=tcy<=3000 ( 33.75-81) 36 = 1333.3 = 750KHz
//         tD1<=1100 (-29.9)     16 =  592.6
//    350<=tp1       (  9.5-)    10 =  370.4
//    200<=tD3       (  5.4-)     6 =  222.2
//    350<=tp2       (  9.5-)    10 =  370.4
//         tD1<=1100 (-29.9)     16 =  592.6 (= tD3+tp2)
//    350<=tD2       ( 9.5-)     10 =  370.4
//
//---------------------------------------------------------------------------

`define CLOCK_500KHz (for 8008)
//`define CLOCK_750KHz (for 8008-1)
  
`ifdef CLOCK_500KHz
// for 8008  (500Hz clock)
  parameter  CLKWIDTH = 54;
  parameter  clk1_table =
	     54'b111111111111111111100000000000000000000000000000000000;
  parameter  clk2_table =
	     54'b000000000000000000000000011111111111111111100000000000;
//                         11111111112222222222333333333344444444445555
//               012345678901234567890123456789012345678901234567890123
`endif

`ifdef CLOCK_750KHz
// for 8008-1 (750Hz clock)
  parameter  CLKWIDTH = 36;
  parameter  clk1_table = 36'b111111111100000000000000000000000000;
  parameter  clk2_table = 36'b000000000000000011111111110000000000;
//                                      11111111112222222222333333
//                            012345678901234567890123456789012345
`endif
  
  reg [(CLKWIDTH-1):0] clk1_reg;
  reg [(CLKWIDTH-1):0] clk2_reg;
  assign CLK1 = clk1_reg[0];
  assign CLK2 = clk2_reg[0];
  always @(posedge sys_clk or negedge reset_clk_n)
    if( ~reset_clk_n) begin
       clk1_reg <= clk1_table;
       clk2_reg <= clk2_table;
    end
    else begin
       clk1_reg[(CLKWIDTH-1):0]
	 <= {clk1_reg[(CLKWIDTH-2):0], clk1_reg[CLKWIDTH-1]};
       clk2_reg[(CLKWIDTH-1):0]
	 <= {clk2_reg[(CLKWIDTH-2):0], clk2_reg[CLKWIDTH-1]};
    end

//---------------------------------------------------------------------------
// for uart
//---------------------------------------------------------------------------
  reg [7:0]  tx_data;
  wire	     tx_ready;
  reg	     tx_send = 0;
  wire [7:0] rx_data;
  wire	     rx_data_ready;
  reg	     rx_clear;
  
  wire	     uart_tx;
  wire	     uart_rx;

  assign usb_tx  = uart_tx;
  assign GPIO_TX = uart_tx;
  assign uart_rx = GPIO_RX & usb_rx;
    
//---------------------------------------------------------------------------
// Aliases
//---------------------------------------------------------------------------
  
  // S[2:0]
  wire [2:0] STATE = {S[0], S[1], S[2]}; // inversed order
  parameter  S_T1      = 3'b010;
  parameter  S_T1I     = 3'b011;
  parameter  S_T2      = 3'b001;
  parameter  S_WAIT    = 3'b000;
  parameter  S_T3      = 3'b100;
  parameter  S_STOPPED = 3'b110;
  parameter  S_T4      = 3'b111;
  parameter  S_T5      = 3'b101;

  // D[7:6]
  wire [1:0] CYCLE = {D_T2[6], D_T2[7]}; // inversed order
  parameter  C_PCI   = 2'b00; // memory read (first byte of instruction)
  parameter  C_PCR   = 2'b01; // memory read (additional byte)
  parameter  C_PCC   = 2'b10; // command I/O operation
  parameter  C_PCW   = 2'b11; // memory write

  wire	     mem_read  = (CYCLE == C_PCI) | (CYCLE == C_PCR);
  wire	     mem_write = (CYCLE == C_PCW);
  wire	     io_cycle  = (CYCLE == C_PCC);
       
//---------------------------------------------------------------------------
// reset button and power on reset
//---------------------------------------------------------------------------
  wire	     reset_sw = sw1;

// reset for clock generator;
// clock starts before complete system reset
  reg		 reset_clk_n; // Reset for memory system
  reg [19:0]	 reset_clk_cnt = 0;
  parameter	 RESET_CLK_WIDTH = (SYSCLK_FRQ / 1000) * 10; // 10ms
  always @(posedge sys_clk)
    if( reset_sw ) 
      {reset_clk_n, reset_clk_cnt} <= 0;
    else if (reset_clk_cnt != RESET_CLK_WIDTH) begin
       reset_clk_n <= 0;
       reset_clk_cnt <= reset_clk_cnt + 1'd1;
    end
    else
      reset_clk_n <= 1;

// reset for memory system and UART
  reg		 reset_n; // Reset for memory system
  reg [27:0]	 reset_cnt = 0;
  parameter	 RESET_WIDTH = (SYSCLK_FRQ / 1000) * 100; // 100ms
  always @(posedge sys_clk)
    if( reset_sw ) 
      {reset_n, reset_cnt} <= 0;
    else if (reset_cnt != RESET_WIDTH) begin
       reset_n <= 0;
       reset_cnt <= reset_cnt + 1'd1;
    end
    else
      reset_n <= 1;
  
//---------------------------------------------------------------------------
// address bus
//---------------------------------------------------------------------------
  reg [7:0] D_T1;
  reg [7:0] D_T2;

  always @(posedge CLK2) begin
     if((STATE == S_T1) & ~SYNC) D_T1 <= D;
     if((STATE == S_T2) & ~SYNC) D_T2 <= D;
  end

//---------------------------------------------------------------------------
// address bus
//---------------------------------------------------------------------------
  wire [7:0] address_lo = D_T1;
  wire [7:0] address_hi = D_T2;
  wire [13:0] address = {address_hi[5:0], address_lo[7:0]};

//---------------------------------------------------------------------------
// READY and INTERRUPT
//---------------------------------------------------------------------------
  assign READY = 1'b1;  // always READY

  assign INTERRUPT  = INT_REQ;

  reg [7:0]   INT_CODE;
//  parameter CODE_startup = 8'hC0; // LAA(=NOP)
  parameter CODE_startup = 8'h05; // RST0
  parameter CODE_rx      = 8'h0D; // RST1
  parameter CODE_sw2     = 8'h05; // RST0
	     
  reg	    INT_REQ;
  reg	    INT_startup; // startup on reset
  reg	    INT_rx_enable;
  reg	    INT_sw2_enable;
  always @(negedge CLK2 or negedge reset_n)
    if( ~reset_n) begin
       INT_REQ  <= 0;
       INT_CODE <= 0;
       INT_startup <= 1'b1;
       INT_sw2_enable <= 1'b1;
       INT_rx_enable <= 1'b1;
    end
    else if(INT_REQ) begin
       if( STATE == S_T1I )
	 INT_REQ <= 0;
    end
    else if( SYNC ) begin
       if( ~sw2 ) INT_sw2_enable <= 1'b1;
       if( ~rx_data_ready ) INT_rx_enable <= 1'b1;
    end       
    else begin
       if(sw2 & INT_sw2_enable) begin
	  INT_REQ  <= 1'b1;
	  INT_CODE <= CODE_sw2;
	  INT_sw2_enable <= 0;
       end
       else if( INT_startup ) begin
          if( STATE == S_STOPPED) begin
	     INT_REQ  <= 1'b1; 
	     INT_CODE <= CODE_startup;
	     INT_startup <= 0; // INT_strtup is activated only once
	  end
       end
`ifdef USE_RX_INTERRUPT
       else if( rx_data_ready & INT_rx_enable ) begin
	  INT_REQ  <= 1'b1;
	  INT_CODE <= CODE_rx;
	  INT_rx_enable <= 0;
       end
`endif // USE_RX_INTERRUPT
    end
  
  reg INT_ack_cycle;
  always @(negedge CLK2 or negedge reset_n)
    if(~reset_n)
      INT_ack_cycle <= 0;
    else if(STATE == S_T1I & SYNC)
      INT_ack_cycle <= 1'b1;
    else if(STATE == S_T3 & ~SYNC)
      INT_ack_cycle <= 0;
  

//---------------------------------------------------------------------------
// Data bus
//---------------------------------------------------------------------------
  wire mem_enable = (STATE == S_T3)  & SYNC & mem_read & ~CLK1;
  wire io_enable  = (STATE == S_T3)  & SYNC & io_cycle & ~CLK1;

  assign D = mem_enable ?
	       (reset_n ?
	         (INT_ack_cycle ? INT_CODE : mem[address] ) :
	         8'h00): // HALT
	     io_enable ? io_data :
	     8'bzzzz_zzzz;
  
//---------------------------------------------------------------------------
// Memory
//---------------------------------------------------------------------------
  reg [7:0] mem[16383:0];
  always @(negedge CLK2)
    if((STATE == S_T3) & ~SYNC & mem_write)
      mem[address] <= D;
  
//---------------------------------------------------------------------------
// ROM DATA
//---------------------------------------------------------------------------
`include "rom.v"
  
//---------------------------------------------------------------------------
// I/O
//---------------------------------------------------------------------------
  // I/O address 00000-00111: input
  //             01000-11111: output
  parameter IO_ADDR_CSR = 5'h00;
  parameter IO_ADDR_RX  = 5'h01;
  parameter IO_ADDR_TX  = 5'h10;

  wire [7:0] IO_REG_CSR = {5'b0, tx_ready, 1'b0, rx_data_ready};
  wire [7:0] IO_REG_RX  = rx_data;

  wire [4:0] io_address = D_T2[5:1];
  wire [7:0] io_regA = D_T1;

  wire	     io_read  = io_cycle & (io_address[4:3] == 2'b0);
  wire	     io_write = io_cycle & (io_address[4:3] != 2'b0);

  // TX write
  always @(negedge CLK2)
    if(~tx_ready)
      tx_send <= 0;
    else if((STATE == S_T2) & ~SYNC)
      if((io_address == IO_ADDR_TX) & io_cycle ) begin
	 tx_data <= io_regA;
	 tx_send <= 1'b1;
      end
  
  // RX read
  always @(negedge CLK2)
    if( rx_data_ready ) begin
       if((STATE == S_T2) & ~SYNC)
	 if(io_address == IO_ADDR_RX & io_cycle)
	   rx_clear <= 1'b1;
    end
    else
      rx_clear <= 0;

  wire [7:0] io_data =
	     (io_address == IO_ADDR_RX)  ? IO_REG_RX:
	     (io_address == IO_ADDR_CSR) ? IO_REG_CSR:
	     0;

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
       .reset_n       (reset_n      ),
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
       .reset_n       (reset_n),
       .tx_data       (tx_data),
       .tx_send       (tx_send),
       .tx_ready      (tx_ready),
       .tx_out        (uart_tx)
       );

//---------------------------------------------------------------------------
// for debug
//---------------------------------------------------------------------------
  reg [7:0] LED_R;
  reg [7:0] LED_G;
  reg [7:0] LED_B;
  ws2812 onboard_rgb_led(.clk(sys_clk), .we(1'b1), .sout(LED_RGB),
			 .r(LED_R), .g(LED_G), .b(LED_B));

//  assign LED_n[5:0] = ~{CYCLE[1:0], STATE[2:0], INT_REQ};
    
  reg [15:0] dbg_a;
  always @(posedge SYNC)
    if(CYCLE == C_PCI)
      dbg_a[15:0] = {INT_REQ, (STATE == S_WAIT), address[13:0]};

  reg [1:0] led_cnt;
  always @(posedge clk_1Hz)
    led_cnt <= led_cnt + 1'b1;
  assign LED_n[5:0] = ~{led_cnt[1:0],
			(led_cnt == 2'b00) ? dbg_a[3:0]:
			(led_cnt == 2'b01) ? dbg_a[7:4]:
			(led_cnt == 2'b10) ? dbg_a[11:8]:
			(led_cnt == 2'b11) ? dbg_a[15:12]:
			4'b0000
			};
			
//  assign LED_n[5:0] = clk_1Hz ? ~{2'b10, tx_data[7:4]} :
//		      {2'b00, tx_data[3:0]};

//  assign LED_n[5:0] = ~{tx_data[5:0]};

  
  assign DBG_TRG =  mem_enable;
  assign DBG_TRG2 = dbg_tx;

  reg [1:0] CLK1s;
  wire	    posedge_CLK1 = CLK1s[0] & ~CLK1s[1];
  always @(posedge sys_clk)
    CLK1s[1:0] = {CLK1s[0], CLK1};

  always @(posedge sys_clk)
    if(posedge_CLK1 ) begin
       if(dbg_tx_ready) begin
	  dbg_tx_data <= {2'b0, CYCLE[1:0], 1'b0, STATE[2:0]};
//	  dbg_tx_data <= {address[7:0]};
	  dbg_tx_send <= 1'b1;
       end
    end
    else if(~dbg_tx_ready)
      dbg_tx_send <= 0;

  reg [25:0]		cnt_500ms;
  reg			clk_1Hz;
  always @(posedge sys_clk)
    if(cnt_500ms == SYSCLK_FRQ/2) begin
       cnt_500ms <= 0;
       clk_1Hz <= ~clk_1Hz;
    end else 
      cnt_500ms <= cnt_500ms + 1'b1;

  reg [23:0]		cnt_sync;
  reg			sync_monitor;
  parameter		SYNC_FRQ = SYSCLK_FRQ / CLKWIDTH / 2;
  always @(posedge sys_clk)
    if(cnt_sync == SYSCLK_FRQ/2) begin
       cnt_sync <= 0;
       sync_monitor <= ~sync_monitor;
    end else 
      cnt_sync <= cnt_sync + 1'b1;

  always @(posedge sys_clk)
    if(~reset_n) begin
      {LED_R, LED_G, LED_B} <= 24'h00_00_00;
    end
    else begin
       LED_R <= rx_data_ready ? 8'h10:
		8'h00;
       LED_G <= ~tx_ready ? 8'h10:
		(STATE == S_STOPPED) ?  8'h10:
		8'h00;
//       LED_B <= clk_1Hz ? 8'h10:
       LED_B <= sync_monitor ? 8'h10:
		8'h00;
    end

//---------------------------------------------------------------------------
// uart for debug
//---------------------------------------------------------------------------

//  parameter	 UART_BPS_DBG    =       115_200; // (for TeraTerm)
// the followings are for oscilloscope
//  parameter	 UART_BPS_DBG    =     1_700_000; // (27_000_000 / 10)
//  parameter	 UART_BPS_DBG    =     2_700_000; // (27_000_000 / 10)
//  parameter	 UART_BPS_DBG    =     6_750_000; // (27_000_000 / 4)
  parameter	 UART_BPS_DBG    =    13_500_000; // (27_000_000 / 2)
  reg [7:0]	 dbg_tx_data;
  reg		 dbg_tx_send;
  wire		 dbg_tx_ready;
  wire		 dbg_tx;
  uart_tx#
    (
     .CLK_FRQ(SYSCLK_FRQ),
     .BAUD_RATE(UART_BPS_DBG)
     ) uart_dbg_tx_inst
      (
       .clk           (sys_clk),
       .reset_n       (reset_n),
       .tx_data       (dbg_tx_data),
       .tx_send       (dbg_tx_send),
       .tx_ready      (dbg_tx_ready),
       .tx_out        (dbg_tx)
       );


endmodule
