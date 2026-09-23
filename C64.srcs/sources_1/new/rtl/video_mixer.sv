//
//
// Copyright (c) 2017,2021 Alexey Melnikov
//
// This program is GPL Licensed. See COPYING for the full license.
//
//
////////////////////////////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

//
// LINE_LENGTH: Length of display line in pixels when HBlank = 0;
// HALF_DEPTH:  If =1 then color dept is 4 bits per component
//
// altera message_off 10720 
// altera message_off 12161

module video_mixer
#(
	/*parameter LINE_LENGTH  = 768,
	parameter HALF_DEPTH   = 0,
	parameter GAMMA        = 0*/
)
(
	input            CLK_VIDEO, // should be multiple by (ce_pix*4)
	output reg       CE_PIXEL,  // output pixel clock enable

	input            ce_pix,    // input pixel clock or clock_enable

	input            scandoubler,
	input [1:0]      scanlines,
	
	// color
	input [2:0] R,
	input [2:0] G,
	input [2:0] B,

	// Positive pulses.
	input            HSync,
	input            VSync,
	input            HBlank,
	input            VBlank,

	// Freeze engine
	// HDMI: displays last frame 
	// VGA:  black screen with HSync and VSync
	/*input            HDMI_FREEZE,
	output           freeze_sync,*/

	// video output signals
	output reg [2:0] VGA_R,
	output reg [2:0] VGA_G,
	output reg [2:0] VGA_B,
	output reg       VGA_VS,
	output reg       VGA_HS,
	output reg       VGA_DE
);

wire hs_g, vs_g;
wire hb_g, vb_g;

wire [2:0] R_sd;
wire [2:0] G_sd;
wire [2:0] B_sd;
wire hs_sd, vs_sd, hb_sd, vb_sd, ce_pix_sd;

reg clk2x;
reg clkpix;
reg [2:0] div=0;
always @(posedge CLK_VIDEO) begin :clk_div
    //reg [1:0] div;
    div<=div+1;    
    clk2x<=~&div[1:0];
    clkpix<=~&div;
end 

//scandoubler #(.LENGTH(LINE_LENGTH), .HALF_DEPTH(HALF_DEPTH_SD)) sd
scandoubler  sd
(
	.clk_x2(clk2x),
	.clk_pix(clkpix),
	
	.scanlines(scanlines),
	
	.hs_in(HSync),
	.vs_in(VSync),
	.hb_in(HBlank),
	.vb_in(VBlank),
	.r_in(R),
	.g_in(G),
	.b_in(B),

	.hs_out(hs_sd),
	.vs_out(vs_sd),
	.hb_out(hb_sd),
	.vb_out(vb_sd),
	.r_out(R_sd),
	.g_out(G_sd),
	.b_out(B_sd)
);

wire [2:0] rt = (scandoubler ? R_sd : R);
wire [2:0] gt = (scandoubler ? G_sd : G);
wire [2:0] bt = (scandoubler ? B_sd : B);

always @(posedge CLK_VIDEO) begin
	reg [3:0] r,g,b;
	reg hde,vde,hs,vs, old_vs;
	reg old_hde;
	reg old_ce;
	reg ce_osc, fs_osc;
	
	old_ce <= ce_pix;
	ce_osc <= ce_osc | (old_ce ^ ce_pix);

	old_vs <= vs;
	if(~old_vs & vs) begin
		fs_osc <= ce_osc;
		ce_osc <= 0;
	end

	CE_PIXEL <= scandoubler ? clk2x : fs_osc ? (~old_ce & ce_pix) : ce_pix;

/*	if(!GAMMA && HALF_DEPTH) begin
		r <= {rt,rt};
		g <= {gt,gt};
		b <= {bt,bt};
	end
	else begin*/
		r <= rt;
		g <= gt;
		b <= bt;
	//end

	hde <= scandoubler ? ~hb_sd : ~HBlank;
	vde <= scandoubler ? ~vb_sd : ~VBlank;
	vs  <= scandoubler ?  vs_sd :  VSync;
	hs  <= scandoubler ?  hs_sd :  HSync;


	if(CE_PIXEL) begin	   
       VGA_R <= r;
       VGA_G <= g;
       VGA_B <= b;

		VGA_VS <= vs;
		VGA_HS <= hs;

		old_hde <= hde;
		if(old_hde ^ hde) VGA_DE <= vde & hde;
	end
end

endmodule
