//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output [11:0] VIDEO_ARX,
	output [11:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler

`ifdef USE_FB
	// Use framebuffer in DDRAM (USE_FB=1 in qsf)
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

`ifdef USE_DDRAM
	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,
`endif

`ifdef USE_SDRAM
	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,
`endif

`ifdef DUAL_SDRAM
	//Secondary SDRAM
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;

assign VGA_SL = 0;
assign VGA_F1 = 0;
assign VGA_SCALER = 0;

assign AUDIO_S = 0;
assign AUDIO_L = 0;
assign AUDIO_R = 0;
assign AUDIO_MIX = 0;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

wire [1:0] ar = status[9:8];

assign VIDEO_ARX = (!ar) ? 12'd4 : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? 12'd3 : 12'd0;

`include "build_id.v" 
localparam CONF_STR = {
	"DDR3Burst;;",
	"-;",
	"O89,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"-;",
	"O35,Wait cnt,0,2,4,8,16,32,64,128;",
	"O6,Burst constant,initial,throughout;",
	"O7,Unsafe stop /w WE=1,no,yes;",
	"-;",
	"R1,Safe Stop;",
	"R2,Unsafe Stop;",
	"-;",
	"R0,Reset;",
	"V,v",`BUILD_DATE 
};

wire forced_scandoubler;
wire  [1:0] buttons;
wire [31:0] status;
wire [10:0] ps2_key;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),
	.gamma_bus(),

	.conf_str(CONF_STR),
	.forced_scandoubler(forced_scandoubler),

	.buttons(buttons),
	.status(status),
	.status_menumask(),
	
	.ps2_key(ps2_key)
);


///////////////////////   CLOCKS   ///////////////////////////////

wire clk_sys, clk_ddr3;
pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),
	.outclk_1(clk_ddr3)
);

wire reset = RESET | status[0] | buttons[1];

//////////////////////////////////////////////////////////////////

assign DDRAM_CLK = clk_ddr3;
assign DDRAM_BURSTCNT = burst_cnt;
assign DDRAM_ADDR = address;
assign DDRAM_RD = 1'b0;
assign DDRAM_BE = 8'h0F;
assign DDRAM_DIN = {56'b0, data_cnt};
assign DDRAM_WE = write_state == 2'd1 || unsafe_stop_with_we;

reg [1:0] write_state; //0: wait, 1: write, 2: stop
reg [7:0] data_cnt;
reg [7:0] burst_cnt;
reg [27:0] address;
reg [9:0] wait_cnt;


wire [9:0] wait_cnt_max;
always_comb begin
	case (status[5:3])
		3'd0 : wait_cnt_max = 10'd0;
		3'd1 : wait_cnt_max = 10'd2;
		3'd2 : wait_cnt_max = 10'd4;
		3'd3 : wait_cnt_max = 10'd8;
		3'd4 : wait_cnt_max = 10'd16;
		3'd5 : wait_cnt_max = 10'd32;
		3'd6 : wait_cnt_max = 10'd64;
		3'd7 : wait_cnt_max = 10'd128;
		default :  wait_cnt_max = 10'd128;
	endcase
end

localparam BURSTCNT = 8'h80;
localparam ADDRESS = 28'h2400000;
wire throughout_burst_constant = status[6];
wire unsafe_stop_with_we = status[7] & unsafe_stop;

always @(posedge clk_ddr3, posedge reset) begin
	if (reset) begin
		write_state <= 2'd0;
		data_cnt <= 8'd0;
		burst_cnt <= 8'd0;
		address <= 28'd0;
		wait_cnt <= 10'd0;
	end else if (write_state == 2'd0) begin
		if (wait_cnt == wait_cnt_max) begin
			write_state <= 2'd1;
			burst_cnt <= BURSTCNT;
			address <= ADDRESS;
			wait_cnt <= 10'd0;
		end else begin
			wait_cnt <= wait_cnt + 10'd1;
		end
	end else if (!DDRAM_BUSY && write_state == 2'd1) begin
		if (data_cnt == BURSTCNT - 8'd1) begin
			if (safe_stop) begin
				write_state <= 2'd2;
			end else begin
				data_cnt <= 8'd0;
				write_state <= 2'd0;
			end
		end else begin
			data_cnt <= data_cnt + 8'd1;
		end
		if (unsafe_stop) begin
			write_state <= 2'd2;
		end
		burst_cnt <= throughout_burst_constant ? BURSTCNT : 8'd1;
		address <= throughout_burst_constant ? ADDRESS : 8'd0;
	end else if (unsafe_stop) begin
		write_state <= 2'd2;
	end
end

reg ss1, ss2, ss3;
always @(posedge clk_ddr3) begin
	ss1 <= status[1]; // Safe Stop
	ss2 <= ss1;
	ss3 <= ss2;
end

reg safe_stop;
always @(posedge clk_ddr3, posedge reset) begin
	if (reset) begin
		safe_stop <= 1'b0;
	end else begin
		if (~ss2 & ss3) begin
			safe_stop <= 1'b1;
		end
	end
end

reg us1, us2, us3;
always @(posedge clk_ddr3) begin
	us1 <= status[2]; // Unsafe Stop
	us2 <= us1;
	us3 <= us2;
end

reg unsafe_stop;
always @(posedge clk_ddr3, posedge reset) begin
	if (reset) begin
		unsafe_stop <= 1'b0;
	end else begin
		if (~us2 & us3) begin
			unsafe_stop <= 1'b1;
		end
	end
end

wire enable_video = ~(safe_stop | unsafe_stop | DDRAM_BUSY);

//////////////////////////////////////////////////////////////////
wire HBlank;
wire HSync;
wire VBlank;
wire VSync;
wire ce_pix;
wire [7:0] video;

mycore mycore
(
	.clk(clk_sys),
	.reset(reset),
	
	.pal(1'b0),
	.scandouble(forced_scandoubler),

	.ce_pix(ce_pix),

	.HBlank(HBlank),
	.HSync(HSync),
	.VBlank(VBlank),
	.VSync(VSync),

	.video(video)
);

assign CLK_VIDEO = clk_sys;
assign CE_PIXEL = ce_pix;

assign VGA_DE = ~(HBlank | VBlank);
assign VGA_HS = HSync;
assign VGA_VS = VSync;
assign VGA_G  = e2 ? video : 8'h00;
assign VGA_R  = e2 ? video : 8'h00;
assign VGA_B  = e2 ? video : 8'hFF;

reg e1, e2;
always @(posedge clk_sys) begin
	e1 <= enable_video;
	e2 <= e1;
end


reg  [26:0] act_cnt;
always @(posedge clk_sys) act_cnt <= act_cnt + 1'd1; 
assign LED_USER    = DDRAM_BUSY;

endmodule
