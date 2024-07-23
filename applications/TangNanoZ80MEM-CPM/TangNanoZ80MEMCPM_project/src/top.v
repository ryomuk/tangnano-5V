//---------------------------------------------------------------------------
// Tang Nano 20K Z80 Memory for CP/M
// Memory System for Z80 using Tang Nano 20K
// with floppy/hard disk emulator using SD memory card
//
// by Ryo Mukai
// 2023/07/06
//  - initial version
// 2024/04/07
//  - some port names for uart.v changed
//  - default clock changed to USE_DIV_CLK(13.5MHz)
// 2024/04/17
//  - bug fix (memory write timing)
//  - indicate state of UART and heartbeat on RGB LED
//  - rx_data_ready in IOADDR_UART_CTRL moved from bit1 to bit0
// 2024/04/27
//  - tx_send timing fixed for fast CPU clock
// 2024/07/23
//  - implemented some features for CP/M
//---------------------------------------------------------------------------

`define USE_DIV_CLK  // CLK = divided sys_clk (defined by Z80CLK_FRQ)

// PLL_CLK and SYS_CLK have not been tested for TangNanoZ80MEM-CPM
//`define USE_PLL_CLK  // CLK = PLL clock (defined by IP Core Generator)
//`define USE_SYS_CLK  // CLK = sys_clk (27MHz)

module top(
    input	 sw1,
    input	 sw2,
    input	 sys_clk, // 27MHz system clock
    input	 uart_rx,
    output	 uart_tx,

    output	 sd_clk,
    output	 sd_mosi, 
    input	 sd_miso,
    output	 sd_cs_n,

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
  parameter	 Z80CLK_FRQ  =  6_750_000; //Hz (SYSCLK/4)
//  parameter	 Z80CLK_FRQ  = 13_500_000; //Hz (SYSCLK/2)
`endif
  
  parameter UART_BPS    =     115200; //Hz
//  parameter	 UART_BPS    =       9600; //Hz

//       I/O ports
//  parameter	 IOADDR_UART_DATA = 8'h00;
//  parameter	 IOADDR_UART_CTRL = 8'h01;

  parameter IOADDR_CONDAT  = 8'h00; // console data port
  parameter IOADDR_CONSTA  = 8'h01; // console status port
  
  parameter IOADDR_PRTSTA = 8'h02; // printer status port (not implemented)
  parameter IOADDR_PRTDAT = 8'h03; // printer data port   (not implemented)
  parameter IOADDR_AUXDAT = 8'h05; // auxiliary data port (not implemented)
  parameter IOADDR_FDCD   = 8'h0A; // fdc-port: # of drive
  parameter IOADDR_FDCT   = 8'h0B; // fdc-port: # of track
  parameter IOADDR_FDCS   = 8'h0C; // fdc-port: # of sector
  parameter IOADDR_FDCOP  = 8'h0D; // fdc-port: command
  parameter IOADDR_FDCST  = 8'h0E; // fdc-port: status
  parameter IOADDR_DMAL   = 8'h0F; // dma-port: dma address low
  parameter IOADDR_DMAH   = 8'h10; // dma-port: dma address high

  parameter FDCOP_READ  = 8'h00;
  parameter FDCOP_WRITE = 8'h01;
  parameter FDCST_ERROR = 8'h01;

// for unimon
  wire [7:0] REG_CONSTA = {5'b00000, tx_buf_ready, 1'b0, rx_data_ready};
  wire [7:0] REG_CONDAT = rx_data;

//  reg [7:0] rx_data_latched;
//  always @(posedge cpu_read_io)
//  rx_data_latched = rx_data_ready ? rx_data : 8'hff;
  
  reg [7:0] REG_FDCD;
  reg [7:0] REG_FDCT;
  reg [7:0] REG_FDCS;
  reg [7:0] REG_FDCOP;
  wire [7:0] REG_FDCST  = 0; // not implemented
  reg [7:0] REG_DMAL;
  reg [7:0] REG_DMAH;
  
  reg [7:0]	 mem[65535:0];
  reg [15:0]	 address; // address or data of memory should be latched to infer BSRAM
  reg [7:0]	 io_addr;
  wire [7:0]	 io_data;

  wire [7:0]	 int_vector;
    
  wire		 BUSREQ_n;
  assign DBG_TRG = BUSREQ_n;
  
  reg [7:0]	 tx_data;
  reg		 tx_send;
  wire		 tx_ready;
  wire [7:0]	 rx_data;
  wire		 rx_data_ready;
  reg		 rx_clear;
  
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
  wire reset_sw = sw1 | sw2;

// reset for CPU
  reg [27:0]	 reset_cnt = 0;
  parameter	 RESET_WIDTH = (SYSCLK_FRQ / 1000) * 500; // 500ms
  always @(posedge sys_clk)
    if( reset_sw ) 
      {RESET_n, reset_cnt} <= 0;
    else if (reset_cnt != RESET_WIDTH) begin
       RESET_n <= 0;
       reset_cnt <= reset_cnt + 1'd1;
    end
    else
      RESET_n <= 1;
  
// reset for SD memory
// It will take max 1sec after reset to start up SD memory 
  reg RESET_SD_n;
  reg [27:0]	 reset_sd_cnt = 0;
  parameter	 RESET_SD_WIDTH = (SYSCLK_FRQ / 1000) * 50; // 50ms
  always @(posedge sys_clk)
    if( reset_sw )
      {RESET_SD_n, reset_sd_cnt} <= 0;
    else if (reset_sd_cnt != RESET_SD_WIDTH) begin
       RESET_SD_n <= 0;
       reset_sd_cnt <= reset_sd_cnt + 1'd1;
    end
    else
      RESET_SD_n <= 1;

//---------------------------------------------------------------------------
// IPL loader
//---------------------------------------------------------------------------
  reg [7:0]  rom[255:0];
  reg [8:0]  ipl_cnt = 0;
  wire [15:0] ipl_address = {8'h00, ipl_cnt[7:0]};
  reg	      load_ipl;
  parameter   IPL_WIDTH = 256;
  always @(posedge sys_clk)
    if( sw2 )
      {ipl_cnt, load_ipl} <= 0;
    else if (ipl_cnt != IPL_WIDTH) begin
       load_ipl <= 1'b1;
       ipl_cnt <= ipl_cnt + 1'd1;
    end
    else
      load_ipl <= 0;
      
//---------------------------------------------------------------------------
// Memory and IO
//---------------------------------------------------------------------------
  assign D = (~M1_n & ~IORQ_n) ? int_vector   :
	     (~MREQ_n & ~RD_n) ? d_ram_to_cpu :
	     (~IORQ_n & ~RD_n) ? io_data      :
	     8'bzzzz_zzzz;
  
  assign io_data = (io_addr == IOADDR_CONDAT) ? REG_CONDAT :
		   (io_addr == IOADDR_CONSTA) ? REG_CONSTA :
		   (io_addr == IOADDR_FDCD)   ? REG_FDCD:
		   (io_addr == IOADDR_FDCT)   ? REG_FDCT:
		   (io_addr == IOADDR_FDCS)   ? REG_FDCS:
		   (io_addr == IOADDR_DMAL)   ? REG_DMAL:
		   (io_addr == IOADDR_DMAH)   ? REG_DMAH:
		   (io_addr == IOADDR_FDCST)  ? REG_FDCST:
		   0;

//---------------------------------------------------------------------------
// Memory
//---------------------------------------------------------------------------
  always @(negedge MREQ_n)
    address <= A;

  wire cpu_write_mem = ~MREQ_n & ~WR_n;
  wire cpu_write_io  = ~IORQ_n & ~WR_n;
  wire cpu_read_io   = ~IORQ_n & ~RD_n;
       
//  always @(posedge cpu_write_mem)
//    mem[address] <= D;
  
  wire [7:0] d_dma_to_ram; // dma data is from sdhd module
  reg [7:0]  d_cpu_to_ram;
  always @(posedge cpu_write_mem)
    d_cpu_to_ram <= D;

  wire [7:0] d_ram_to_cpu = mem[mem_address];
  wire [7:0] d_ram_to_dma = mem[mem_address];

  reg [15:0] mem_address;  // address for RAM
  always @(negedge sys_clk)
    mem_address <= load_ipl   ? ipl_address: 
		   dma_busreq ? dma_address:
		   address;

  always @(posedge sys_clk)
    if( load_ipl )
      mem[mem_address] <= rom[mem_address[7:0]];
    else if( cpu_write_mem )
      mem[mem_address] <= d_cpu_to_ram;
    else if( dma_write )
      mem[mem_address] <= d_dma_to_ram;

//---------------------------------------------------------------------------
// ROM DATA
//---------------------------------------------------------------------------
`include "rom.v"
  
//---------------------------------------------------------------------------
// I/O
//---------------------------------------------------------------------------
  always @(negedge IORQ_n)
    io_addr <= A[7:0];

// UART SEND
//  always @(posedge CLK)
  always @(negedge CLK) // for fast CPU clock (I'm not sure, but it works)
    if(cpu_write_io  & (io_addr == IOADDR_CONDAT)) begin
//       tx_data <= D;
//       tx_send <= 1'b1;
       tx_buf_data <= D;
       tx_buf_write <= 1'b1;
    end
    else
      tx_buf_write <= 0;
//    else // for slow CPU clock
//    else if(~M1_n) // for fast CPU clock
//      tx_send <= 1'b0;

  // clear rx_ready
  always @(posedge CLK)
    if(cpu_read_io & (io_addr == IOADDR_CONDAT))
      rx_clear <= 1;
    else if(rx_data_ready == 1'b0)
      rx_clear <= 0;  // disable rx_clear after rx_data_ready is cleared

//---------------------------------------------------------------------------
// TX buffer
//---------------------------------------------------------------------------
  reg tx_buf_write0;
  reg tx_buf_write1;
  wire posedge_tx_buf_write = tx_buf_write0 & ~tx_buf_write1;
  always @(posedge sys_clk) begin
     tx_buf_write0 <= tx_buf_write;
     tx_buf_write1 <= tx_buf_write0;
  end
    
  reg [7:0] tx_buf[127:0];
  reg [6:0] tx_head;
  reg [6:0] tx_tail;
  reg [7:0] tx_buf_data;
  reg	    tx_buf_write;
  wire [6:0] tx_tail_next = tx_tail + 1'b1;
  wire [6:0] tx_head_next = tx_head + 1'b1;
  wire	     tx_buf_ready = (tx_head != tx_tail_next);
  always @(posedge sys_clk or negedge RESET_n)
    if( ~RESET_n )
      {tx_head, tx_tail} = 0;
    else if(posedge_tx_buf_write) begin
       tx_buf[tx_tail] <= tx_buf_data;
       tx_tail <= tx_tail_next;
    end
    else if( ~tx_ready )
      tx_send <= 0;
    else if( (tx_head != tx_tail) & ~tx_send) begin
       tx_data <= tx_buf[tx_head];
       tx_send <= 1'b1;
       tx_head <= tx_head_next;
    end
  
//---------------------------------------------------------------------------
//  Floppy and Hard Disks
//---------------------------------------------------------------------------
//  block(128byte) address = disk * 2048 + track * 26 + sector -1
// a, b, c, d: 256KB floppy (2002 (7d2h) block x 128byte)
// i, j: 4MB harddisk (8000h block x 128byte )
// p:  512MB harddisk (400000h block x 128 byte) not supported
  wire [4:0] drive_num = REG_FDCD[4:0];
  wire [23:0] disk_top_block = 
       (drive_num == 5'd0)  ? 24'h000000 :  // drive a (   0)
       (drive_num == 5'd1)  ? 24'h000800 :  // drive b (2048)
       (drive_num == 5'd2)  ? 24'h001000 :  // drive c (4096)
       (drive_num == 5'd3)  ? 24'h001800 :  // drive d (6144)
       (drive_num == 5'd8)  ? 24'h002000 :  // drive i (8192)
       (drive_num == 5'd9)  ? 24'h00a000 :  // drive j (40960)
//       (drive_num == 5'd15)  ? 24'h012000 :  // drive p (73728)
       24'h412000;
  wire [31:0] local_lba = 
	      ((drive_num == 5'd0) |
	       (drive_num == 5'd1) |
	       (drive_num == 5'd2) |
	       (drive_num == 5'd3)) ?
	      ((REG_FDCT[6:0] * 5'd26) + REG_FDCS[4:0] - 1'd1) :
	      ((drive_num == 5'd8) |
	       (drive_num == 5'd9)) ?
	      ((REG_FDCT[7:0] * 8'd128) + REG_FDCS[6:0] - 1'd1) :
//	      (drive_num == 5'd15) ?
//	      ((REG_FDCT[7:0] * 16384) + (REG_FDCS[13:0] - 14'd1)) :
	      0;
  
  assign disk_block_address[23:0] = disk_top_block + local_lba[23:0];
  assign dma_start_address[15:0]  = {REG_DMAH[7:0], REG_DMAL[7:0]};
  
  assign BUSREQ_n = disk_ready;
  always @(posedge CLK)
    if( disk_busy ) begin
       disk_read  <= 0;
       disk_write <= 0;
    end
    else if( cpu_write_io )
      case (io_addr)
	IOADDR_FDCOP:
	  if(D == FDCOP_READ)
	    disk_read <= 1'b1;
	  else if(D == FDCOP_WRITE)
	    disk_write <= 1'b1;
	//
	IOADDR_FDCD: REG_FDCD <= D;
	IOADDR_FDCT: REG_FDCT <= D;
	IOADDR_FDCS: REG_FDCS <= D;
	IOADDR_DMAL: REG_DMAL <= D;
	IOADDR_DMAH: REG_DMAH <= D;
      endcase

//---------------------------------------------------------------------------
// Interrupt
//---------------------------------------------------------------------------
// Int Vector for UART receive (hard coding)
  parameter	 IVECTOR_UART_RECV = 8'h6C; // SBC Z80 Grant BASIC
  assign int_vector = IVECTOR_UART_RECV;
//  assign INT_n      = ~rx_data_ready;
  assign INT_n = 1'b1;

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
// SD memory Hard disk emulator
//---------------------------------------------------------------------------
  wire	      disk_ready;
  wire	      disk_busy = ~disk_ready;	      
  reg	      disk_read;
  reg	      disk_write;
  wire [23:0] disk_block_address;
  wire [15:0] dma_address;
  wire [15:0] dma_start_address;
//  wire [16:0] dma_bytecount = 17'h1fe00; // 2's complement of 512
  wire [5:0]  sd_state;
  wire [3:0]  sd_error;
  wire	      dma_write;	      
  wire	      dma_busreq;	      
  
  sdhd_cpm #(
	      .SYS_FRQ(27_000_000),
	      .MEM_FRQ(400_000)
    ) sdhd_cpm_inst
  (
   .i_clk                (sys_clk),
   .i_reset_n            (RESET_SD_n),
   .i_sd_miso            (sd_miso),
   .o_sd_mosi            (sd_mosi),
   .o_sd_cs_n            (sd_cs_n),
   .o_sd_clk             (sd_clk),
   .o_disk_ready         (disk_ready),
   .i_disk_read          (disk_read),
   .i_disk_write         (disk_write),
   .i_disk_block_address ({2'b0, disk_block_address[23:2]}),
   .i_disk_block_sub_address (disk_block_address[1:0]),
   .o_dma_address        (dma_address),
   .i_dma_start_address  (dma_start_address),
//   .i_dma_bytecount      (dma_bytecount),
   .i_dma_data           (d_ram_to_dma),
   .o_dma_data           (d_dma_to_ram),
   .o_dma_write          (dma_write),
   .o_dma_busreq         (dma_busreq),
   .o_sd_state           (sd_state),
   .o_sd_error           (sd_error)
   );

//---------------------------------------------------------------------------
// for debug
//---------------------------------------------------------------------------
//`define USE_RGBLED_FOR_DEBUG
`ifdef  USE_RGBLED_FOR_DEBUG
  // output debug signal to RGB_LED pin
//  assign LED_RGB = dma_address[0];
  assign LED_RGB = dma_write;
`else
  // indicate state of UART and heartbeat on RGB LED
  reg [7:0] LED_R;
  reg [7:0] LED_G;
  reg [7:0] LED_B;
  ws2812 onboard_rgb_led(.clk(sys_clk), .we(1'b1), .sout(LED_RGB),
			 .r(LED_R), .g(LED_G), .b(LED_B));

  reg [25:0] cnt_500ms;
  reg	     clk_1Hz;
  always @(posedge sys_clk)
    if(cnt_500ms == (SYSCLK_FRQ/2)-1) begin
       cnt_500ms <= 0;
       clk_1Hz = ~clk_1Hz;
    end else 
      cnt_500ms <= cnt_500ms + 1'b1;
  
  reg [25:0] cnt_250ms;
  reg	     clk_2Hz;
  always @(posedge sys_clk)
    if(cnt_250ms == (SYSCLK_FRQ/4)-1) begin
       cnt_250ms <= 0;
       clk_2Hz = ~clk_2Hz;
    end else 
      cnt_250ms <= cnt_250ms + 1'b1;

  always @(posedge CLK)
    if(~RESET_n)
      {LED_R, LED_G, LED_B} <= 24'h00_00_00;
    else begin
       LED_R <= rx_data_ready ? 8'h10:
		~sd_mosi ? 8'h20:
		8'h00;
       LED_G <=  ~tx_ready ? 8'h10:
		 ~sd_miso ? 8'h20:
		 8'h00;
       LED_B <= clk_1Hz ? 8'h10: 8'h00;
    end
`endif

endmodule
