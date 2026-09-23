`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 19.08.2026 10:25:05
// Design Name: 
// Module Name: c64
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps
`default_nettype wire 

module c64(

//Master input clock
input         CLK_50M,

//BUTTONS
input BT_RST,
input BT_DRV,
input BT_NMI,

//Video
output  [2:0] VGA_R,
output  [2:0] VGA_G,
output  [2:0] VGA_B,
output        VGA_HS,
output        VGA_VS,

//PS2 Keyboard
//input ps2_clk_io,
//input ps2_data_io,

//Matrix Keyboard
input [6:0] keyb_col_i,
output[7:0] keyb_row_o,

//Joysticks
input joyp1_i,
input joyp2_i,
input joyp3_i,
input joyp4_i,
input joyp6_i,
output joyp7_o,
input joyp9_i,
output reg joysel_o,

//iec (next expansion bus d0 to d2)
output iec_atn_o,
inout iec_clk_io,
inout iec_data_io,
output bus_y_o,
output bus_busack_n_o,
//output bus_halt_n_o,

// MicroSD
input SD_MISO,
output SD_MOSI,   
output SD_CS,
output SD_CS1,
output SD_CLK,

output reg audioext_l_o,
output reg audioext_r_o,

//MEMORY
output [19:0] RAM_A,
inout [15:0] RAM_D,
output RAM_UB,
output RAM_LB,
output RAM_CS,
output RAM_OE,
output RAM_WE

    );

wire [95:0] status;
wire pll_locked;
wire clk_sys;
wire clk64;
wire clk48;
wire clk_ctrl;

wire [63:0] reconfig_to_pll;
wire [63:0] reconfig_from_pll;
wire        cfg_waitrequest;
reg         cfg_write;
reg         cfg_den;
reg   [6:0] cfg_address;
wire  [15:0] cfg_dout;
reg  [15:0] cfg_din;
reg         cfg_reset=0;
wire        cfg_drdy;

clk_wiz_0 pll
   (
    // Clock out ports
    .clk_out1(clk48),     // output clk_out1
    .clk_out2(clk64),     // output clk_out2
    .clk_out3(clk_sys),     // output clk_out3
    // Dynamic reconfiguration ports
    .daddr(cfg_address), // input [6:0] daddr
    .dclk(CLK_50M), // input dclk
    .den(cfg_den), // input den
    .din(cfg_din), // input [15:0] din
    .dout(cfg_dout), // output [15:0] dout
    .drdy(cfg_drdy), // output drdy
    .dwe(cfg_write), // output dwe    
    // Status and control signals
    .reset(cfg_reset), // input reset
    .locked(pll_locked),       // output locked
   // Clock in ports
    .clk_in1(CLK_50M)      // input clk_in1
);



/*myBUFG clk_ctrl_buf (
   .O(clk_ctrl), // 1-bit output: Buffer
   .I(clk_sys)  // 1-bit input: Buffer
);*/
assign clk_ctrl=clk_sys;
//reg [31:0] cfg_debug;
reg close_osd=0;
reg ntsc_r = 0;
always @(posedge CLK_50M) begin
	reg ntscd = 0, ntscd2 = 0;
	reg [3:0] state = 0;
	reg [23:0] delay = 0;
	reg osd_s1 = 0, osd_s2 = 0;

	osd_s1 <= osd;
	osd_s2 <= osd_s1;

	// bringing ntsc_req into the CLK_50M domain
	ntscd  <= ntsc_req;
	ntscd2 <= ntscd;

	cfg_write <= 0;
	close_osd <= 0;
	cfg_den <= 0;
	
	

	if(ntscd2 != ntsc_r) begin
	if(osd_s2 && delay < 24'd2500000) begin // 50ms pulse to close OSD
	// Close OSD so that PAL/NTSC switch induced reset does not
	// blank screen, if PAUSE when in OSD is enabled
			close_osd <= 1;
			delay <= delay + 1'd1;
			end else if (delay < 24'd7500000) begin // 150ms total delay
			delay <= delay + 1'd1;
			end else begin
			state <= 1;
			ntsc_r <= ntscd2;
			delay <= 0;
			end
	end else begin
	delay <= 0;
	end

	if(!cfg_waitrequest) begin
		//if(state) state<=state+1'd1;
		case(state)
			1: begin
					cfg_reset <= 1;
                    state<=2;					
				end
			2: begin
					cfg_address <= 7'h14;
			        cfg_den<=1;
			        state<=3;		
				end				
			3: begin
					if (cfg_drdy) begin
					   state<=4;
					   cfg_din<=cfg_dout;
					 //  cfg_debug[15:0]<=cfg_dout;
					end
				end				
			4: begin					
					cfg_din <= ntsc_r ? 16'h171c : 16'h16db;
					cfg_write <= 1;
					cfg_den <= 1;
					state<=5;
				end
			5: begin
					if (cfg_drdy) begin
					   state<=6;					   
					end
			end
			6: begin
					cfg_address <= 7'h15;
			        cfg_den<=1;
			        state<=7;		
				end				
			7: begin
					if (cfg_drdy) begin
					   state<=8;
					   cfg_din<=cfg_dout;
					 //  cfg_debug[31:16]<=cfg_dout;
					end
				end				
			8: begin					
					cfg_din <= ntsc_r ? 16'h7c00 : 16'h6c00;
					cfg_write <= 1;
					cfg_den <= 1;
					state<=9;
				end
			9: begin
					if (cfg_drdy) begin
					   state<=10;				
					end
				end
			10: begin
					cfg_reset<=0;
					state<=0;
				end
		endcase
	end
end

reg ntsc_sys1 = 0, ntsc = 0;
reg reset_n;
reg reset_wait = 0;
reg ntsc_prev = 0;


///////////////////// Buttons /////////////////////////
wire bt_drv_db;
wire bt_rst_db;
wire bt_nmi_db;
debouncer #(.CLK_FREQ(32000000),.DEBOUNCE_TIME_MS(20)) db_drv (
    .clk(clk_sys),
    .rst_n(reset_n),
    .button_in(BT_DRV), 
    .button_out(bt_drv_db)
);
debouncer #(.CLK_FREQ(32000000),.DEBOUNCE_TIME_MS(20)) db_nmi (
    .clk(clk_sys),
    .rst_n(reset_n),
    .button_in(BT_NMI), 
    .button_out(bt_nmi_db)
);
debouncer #(.CLK_FREQ(32000000),.DEBOUNCE_TIME_MS(20)) db_rst (
    .clk(clk_sys),
    .rst_n(reset_n),
    .button_in(BT_RST), 
    .button_out(bt_rst_db)
);


//wire reset_n=pll_locked;
//reg ntsc_sys1 = 0, ntsc = 0;

//reg ntsc_prev = 0;
wire        ioctl_download;
reg old_download;
reg do_erase = 1;

wire  [7:0] ioctl_index;
wire load_prg   = ioctl_index == 'h01;
wire load_crt   = ioctl_index == 'h41 || ioctl_index == 5;
wire load_reu   = ioctl_index == 'h81;
wire load_tap   = ioctl_index == 'hC1;
wire load_flt   = ioctl_index == 7;
wire load_rom   = ioctl_index == 8;
wire load_c1581 = ioctl_index == 9;

always @(posedge clk_sys) begin
	integer reset_counter;
	// Bringing ntsc_r back into clk_sys domain
	ntsc_sys1 <= ntsc_r;
	ntsc <= ntsc_sys1;
	// Detect pal/ntsc switch
	ntsc_prev <= ntsc;

	reset_n <= !reset_counter;
	old_download <= ioctl_download;

	//if (RESET | !pll_locked | (ntsc_prev != ntsc)) begin
	if (!bt_rst_db | status[0] | status[17] | !pll_locked | (ntsc_prev != ntsc)) begin
		if(!bt_rst_db) do_erase <= 1;
		reset_counter <= 100000;
	end
	else if(~old_download & ioctl_download & load_prg & ~status[50]) begin
		do_erase <= 1;
		reset_wait <= 1;
		reset_counter <= 255;
	end
	else if (ioctl_download & (load_crt | load_rom)) begin
		do_erase <= 1;
		reset_counter <= 255;
	end
	else if ((ioctl_download || inj_meminit) & ~reset_wait);
	else if (erasing) force_erase <= 0;
	else if (!reset_counter) begin
		do_erase <= 0;
		if(reset_wait && c64_addr == 'hFFCF) reset_wait <= 0;
	end
	else begin
		reset_counter <= reset_counter - 1;
		if (reset_counter == 100 && (~status[24] | do_erase)) force_erase <= 1;
	end
end



reg [7:0] spec_row;
reg [7:0] spec_row_latch;
reg [6:0] spec_col;
assign keyb_row_o=spec_row_latch;

//assign keyb_row_o=spec_row_addr;
/*myBUFG mb (
    .I(fart),
    .O(keyb_row_o)
);*/

reg [5:0] key_joy;
always @ (posedge clk_sys) begin : rowsel
    reg [2:0] div;
    reg [7:0] spec_row_addr;    
    if (!reset_n) begin
        spec_row_addr<=8'b11111110;
        div<=0;
    end
    else begin
        div<=div+1;
        if (div==0) spec_row_addr<={spec_row_addr[6:0],spec_row_addr[7]};    //rotate keyboard rows
        if (div==1) spec_row_latch<=spec_row_addr;
        if (div==7) begin
            spec_row<=spec_row_latch;
            spec_col<=keyb_col_i;
        end
        if (spec_row==8'hfe) begin
            key_joy[0]<=~spec_col[6];   //up                    
        end
        if (spec_row==8'hf7) begin
            key_joy[5]<=~spec_col[5];   //back                    
        end
        if (spec_row==8'hbf) begin
            key_joy[4]<=~spec_col[0];   //enter                    
            key_joy[3]<=~spec_col[6];   //right
        end
        if (spec_row==8'h7f) begin
            key_joy[2]<=~spec_col[5];   //left                    
            key_joy[1]<=~spec_col[6];   //down
        end
    end 
end
 



/*wire [7:0] ps2_code;
wire ps2_net;
reg [10:0] ps2_key;
reg ps2_ext;
reg ps2_break;

ps2_keyboard #(
    .clk_freq(32000000),
    .debounce_counter_size(8)
  ) ps2_keyboard_to_ascii_0(
    .clk(clk_sys),
    .ps2_clk(ps2_clk_io),
    .ps2_data(ps2_data_io),
    .ps2_code(ps2_code),
    .ps2_new(ps2_new)          
);




reg old_ps2_state;
always @(posedge clk_sys) begin
    old_ps2_state<=ps2_new;
    if (!reset_n)
    begin
        ps2_key<=0;
        ps2_ext<=0;
        ps2_break<=0;    
    end
    else
    begin               
        if ((ps2_new)  && (!old_ps2_state)) begin      //new code recieved
            case (ps2_code)
                8'he0:  ps2_ext<=1;
                8'hf0:  ps2_break<=1;
                default: begin
                    ps2_key[10]<=~ps2_key[10];
                    ps2_key[9]<=~ps2_break;
                    ps2_key[8]<=ps2_ext;
                    ps2_key[7:0]<=ps2_code;
                    ps2_ext<=0;
                    ps2_break<=0;
                end  
            endcase
        end
    end
end
*/
//------------- USER PORT -----------------

wire [7:0] pb_o;
reg [7:0] pb_i;
reg       pa2_i;
wire     pa2_o;
wire       pc2_n_o;
reg       flag2_n_i;
reg       sp2_i;
wire    sp2_o, sp1_o;
reg     sp1_i;
reg       cnt2_i, cnt1_i;
wire      cnt2_o, cnt1_o;

always_comb begin
	pa2_i       = 1;
	flag2_n_i   = 1;
	sp1_i       = 1;
	sp2_i       = 1;
	cnt1_i      = 1;
	cnt2_i      = 1;
	pb_i        = 8'hFF;
	//UART_TXD    = 1;
	//UART_RTS    = 0;
	//UART_DTR    = 0;
	//drive_par_i = 8'hFF;
	//drive_stb_i = 1;
	//USER_OUT[0] = 1;
	//USER_OUT[1] = 1;

/*	if(disk_parport & disk_access) begin
		drive_par_i = pb_o;
		drive_stb_i = pc2_n_o;
		pb_i        = drive_par_o;
		flag2_n_i   = drive_stb_o;
	end
	else if(status[43]) begin
		UART_TXD  = pa2_o & uart_int;
		flag2_n_i = uart_rxd;
		sp2_i     = uart_rxd;
		pb_i[0]   = uart_rxd;
		UART_RTS  = ~pb_o[1] & uart_int;
		UART_DTR  = ~pb_o[2] & uart_int;
		pb_i[4]   = ~uart_dsr;
		pb_i[6]   = ~uart_cts;
		pb_i[7]   = ~uart_dsr;

		USER_OUT[1] = pa2_o | uart_int;

		if(~status[51]) begin
			UART_TXD = pa2_o & sp1_o & uart_int;
			pb_i[7]  = cnt2_o;
			cnt2_i   = pb_o[7];

			USER_OUT[1] = (pa2_o & sp1_o) | uart_int;
		end
	end
	else begin
		pb_i[5:0] = {!joyD_c64[6:4], !joyC_c64[6:4], pb_o[7] ? ~joyC_c64[3:0] : ~joyD_c64[3:0]};
	end*/
end

wire hsync;
wire vsync;
wire hblank;
wire vblank;
wire hsync_out;
wire vsync_out;
wire c64_pause;

video_sync sync
(
	.clk32(clk_sys),
	.pause(c64_pause),
	.hsync(hsync),
	.vsync(vsync),
	.ntsc(ntsc),
	.wide(1'b0),//(wide),
	.hsync_out(hsync_out),
	.vsync_out(vsync_out),
	.hblank(hblank),
	.vblank(vblank),
	.csync(csync),
	.tv_disp(tv_disp)
);

/*reg hq2x160;
always @(posedge clk_sys) begin
	reg old_vsync;

	old_vsync <= vsync_out;
	if (!old_vsync && vsync_out) begin
		hq2x160 <= (status[10:8] == 2);
	end
end
*/
reg ce_pix;
always @(posedge CLK_VIDEO) begin
	reg [1:0] div;
	reg       lores;

	div <= div + 1'b1;
	if(&div) lores <= ~lores;
	ce_pix <= ~lores  && !div;
end

//wire forced_scandoubler=1'b0;
wire CLK_VIDEO=clk64;
wire scandoubler = status[10:8]>0;// || forced_scandoubler;
wire vm_hs,vm_vs;
wire [2:0] vm_r,vm_g,vm_b;



video_mixer video_mixer
(
	.CLK_VIDEO(CLK_VIDEO),

	//.hq2x(~status[10] & (status[9] ^ status[8])),
	.scandoubler(scandoubler),
	.scanlines(status[9:8]),
	//.gamma_bus(22'd0),//(gamma_bus),

	.ce_pix(ce_pix),
	.R(o_r[2:0]),//vgar),
	.G(o_g[2:0]),//vgag),
	.B(o_b[2:0]),//vgab),
	.HSync(hsync_out),
	.VSync(vsync_out),
	.HBlank(hblank),
	.VBlank(vblank),

	//.HDMI_FREEZE(HDMI_FREEZE),
//	.freeze_sync(freeze_sync),

	//.CE_PIXEL(CE_PIXEL),
	.VGA_R(vm_r),
	.VGA_G(vm_g),
	.VGA_B(vm_b),
	.VGA_VS(vm_vs),
	.VGA_HS(vm_hs),
	.VGA_DE(vga_de)
);


/*assign VGA_R=tvr;
assign VGA_G=tvg;
assign VGA_B=tvb;
assign VGA_HS=~csync;
assign VGA_VS=1'b1;*/
/*assign VGA_R=status[89]?tvr:vgar;
assign VGA_G=status[89]?tvg:vgag;
assign VGA_B=status[89]?tvb:vgab;
assign VGA_HS=status[89]?~csync:~hsync_out;
assign VGA_VS=status[89]?1'b1:~vsync_out;*/
assign VGA_R=status[89]?tvr:vga_de?vm_r:3'b000;
assign VGA_G=status[89]?tvg:vga_de?vm_g:3'b000;
assign VGA_B=status[89]?tvb:vga_de?vm_b:3'b000;
assign VGA_HS=status[89]?~csync:~vm_hs;
assign VGA_VS=status[89]?1'b1:~vm_vs;

wire        dma_req;
wire        dma_cycle;
wire [15:0] dma_addr;
wire  [7:0] dma_dout;
wire  [7:0] dma_din;
wire        dma_we;
wire        ext_cycle;

wire [24:0] reu_ram_addr;
wire  [7:0] reu_ram_dout;
wire        reu_ram_we;

wire  [7:0] reu_dout;
wire        reu_irq;

wire        ram_ce;
wire        ram_we;
wire        IOE;
wire        IOF;


wire  [1:0] reu_cfg = 2'b00;//status[54:53];
wire        reu_wrap = 1'b0;//~status[63] & status[54];
wire        reu_oe  = IOF && reu_cfg;

wire  [7:0] c64_data_out;
wire  [7:0] c64_data_in;
wire [15:0] c64_addr;

//wire [7:0] sdram_data;
wire [7:0] ram_din=ram_addr[0]?RAM_D[15:8]:RAM_D[7:0];

reg  [7:0] cart_id;
reg        cart_bank_hi;
reg        cart_bank_16k;
reg  [7:0] cart_bank_num;
reg        cart_exrom;
reg        cart_game;
reg        cart_attached = 0;
reg        cart_hdr_wr;

reg        force_erase;
reg        erasing;

reg        inj_meminit = 0;




wire game;
wire exrom;
wire io_rom;
wire cart_ce;
wire cart_we;
wire nmi;
wire cart_oe;
wire IOF_rd;
wire  [7:0] cart_data;
wire  [7:0] cart_wrdata;
wire [24:0] cart_addr;
wire cart_mem_req;

wire        ioctl_wr;
wire        ioctl_rd;
wire [20:0] ioctl_addr;
wire  [7:0] ioctl_data;
reg  [7:0] ioctl_din;


wire        ioctl_upload;
wire        tape_ioctl_wait;
wire [31:0] ioctl_file_ext;




wire        nmi_ack;
//wire        freeze_key;
wire        mod_key;


wire        romL;
wire        romH;
wire        UMAXromH;

wire       io_cycle;
reg        io_cycle_ce;
reg        io_cycle_we;
reg [21:0] io_cycle_addr;
reg  [7:0] io_cycle_data;


reg [20:0] ioctl_load_addr;
reg        ioctl_req_wr;
reg        ioctl_req_rd;

//NEXT maxes out at 200000 (2mb)
localparam TAP_ADDR = 21'h100000;   //1mb tap size
localparam REU_ADDR = 21'h100000;   //no real space
localparam CRT_ADDR = 21'h100000;   //1mb cart size


wire cart_ezfl = cart_attached && (cart_id == 32 || cart_id ==33);
reg ext_crt = 0;

cartridge cartridge
(
	.clk32(clk_sys),
	.reset_n(reset_n),

	.cart_loading(ioctl_download && load_crt),
	.cart_id(cart_attached ? cart_id : status[52] ? 8'd99 : 8'd255),
	.cart_exrom(cart_exrom),
	.cart_game(cart_game),
	.cart_bank_hi(cart_bank_hi),
	.cart_bank_16k(cart_bank_16k),
	.cart_bank_num(cart_bank_num),
	.cart_bank_addr(ioctl_load_addr[20:13]),
	.cart_bank_wr(cart_hdr_wr),
	.cart_boot(~status[38]),

	.exrom(exrom),
	.game(game),

	.romL(romL),
	.romH(romH),
	.UMAXromH(UMAXromH),
	.IOE(IOE),
	.IOF(IOF),
	.mem_write(ram_we),
	.mem_ce(ram_ce),
	.mem_ce_out(cart_ce),
	.mem_write_out(cart_we),
	.mem_in(ram_din),
	.mem_out(cart_wrdata),
	.mem_addr(cart_addr),
	.mem_req(cart_mem_req),
	.mem_cycle(io_cycle),
	.IO_rom(io_rom),
	.IO_rd(cart_oe),
	.IO_data(cart_data),
	.addr_in(c64_addr),
	.data_in(c64_data_out),
	.data_out(c64_data_in),

	.freeze_key(~bt_nmi_db),
	.mod_key(mod_key),
	.nmi(nmi),
	.nmi_ack(nmi_ack)
);



reg  [4:0] erase_to;

reg        erase_cram;
reg        io_cycleD;
reg        old_st0 = 0;
reg        old_meminit;
reg [15:0] inj_end;
reg  [7:0] inj_meminit_data;
reg  [2:0] rd_cyc;
reg        ioctl_rd_en;
reg [15:0] cart_blk_len;
reg  [3:0] cart_hdr_cnt;
reg  [7:0] cart_id_hi;

reg        start_strk = 0;
//reg [10:0] key = 0;
reg        reset_keys = 0;

always @(posedge clk_sys) begin
	old_download <= ioctl_download;
	io_cycleD <= io_cycle;
	cart_hdr_wr <= 0;
	
	if (~io_cycle & io_cycleD) begin
		io_cycle_ce <= 1;
		io_cycle_we <= 0;
		io_cycle_addr <= tap_play_addr + TAP_ADDR;
		if (ioctl_req_wr) begin
			ioctl_req_wr <= 0;
			io_cycle_we <= 1;
			io_cycle_addr <= ioctl_load_addr;
			ioctl_load_addr <= ioctl_load_addr + 1'b1;
			if (erasing) io_cycle_data <= {8{ioctl_load_addr[6]}};
			else if (inj_meminit) io_cycle_data <= inj_meminit_data;
			else io_cycle_data <= ioctl_data;
		end

		if(ioctl_req_rd) begin
			io_cycle_addr <= ioctl_load_addr;
			ioctl_rd_en <= 1;
		end
	end
	
	if (io_cycle) {io_cycle_ce, io_cycle_we, ioctl_rd_en} <= 0;

	if (ioctl_rd) begin
		if(ioctl_addr == 0) ioctl_load_addr <= CRT_ADDR;
		ioctl_req_rd <= 1;
	end

	rd_cyc <= {rd_cyc[1:0], io_cycle & io_cycle_ce & ioctl_rd_en};
	if(rd_cyc[2]) begin
		ioctl_din <= ram_din;
		ioctl_req_rd <= 0;
		ioctl_load_addr <= ioctl_load_addr + 1'b1;
	end


	if (ioctl_wr) begin
		if (load_prg) begin
			// PRG header
			// Load address low-byte
			if      (ioctl_addr == 0) begin ioctl_load_addr[7:0]  <= ioctl_data; inj_end[7:0]  <= ioctl_data; end
			// Load address high-byte
			else if (ioctl_addr == 1) begin ioctl_load_addr[15:8] <= ioctl_data; inj_end[15:8] <= ioctl_data; end
			else begin ioctl_req_wr <= 1; inj_end <= inj_end + 1'b1; end
		end

		if (load_crt) begin
			if (ioctl_addr == 0) begin
				ioctl_load_addr <= CRT_ADDR;
				cart_blk_len <= 0;
				cart_hdr_cnt <= 0;
			end

			if (ioctl_addr == 8'h16) cart_id_hi <= ioctl_data;
			if (ioctl_addr == 8'h17) cart_id    <= cart_id_hi ? 8'd255 : ioctl_data;
			if (ioctl_addr == 8'h18) cart_exrom <= ioctl_data[0];
			if (ioctl_addr == 8'h19) cart_game  <= ioctl_data[0];

			if (ioctl_addr >= 8'h40) begin
				if (!cart_blk_len || cart_hdr_cnt) begin
					cart_hdr_cnt <= cart_hdr_cnt + 1'b1;
					if (cart_hdr_cnt == 6)  cart_blk_len  <= {ioctl_data, 8'h00};
					if (cart_hdr_cnt == 11) cart_bank_num <= ioctl_data;
					if (cart_hdr_cnt == 12) cart_bank_hi  <= ioctl_data > 8'h80;
					if (cart_hdr_cnt == 14) cart_bank_16k <= ioctl_data > 8'h20;
					if (cart_hdr_cnt == 15) cart_hdr_wr   <= 1;
				end
				else begin
					cart_blk_len <= cart_blk_len - 1'b1;
					ioctl_req_wr <= 1;
				end
			end
		end
		
		if (load_tap) begin
			if (ioctl_addr == 0)  ioctl_load_addr <= TAP_ADDR;
			ioctl_req_wr <= 1;
		end

		if (load_reu) begin
			if (ioctl_addr == 0) ioctl_load_addr <= REU_ADDR;
			ioctl_req_wr <= 1;
		end
	end
	
	if (old_download != ioctl_download && load_crt) begin
		cart_attached <= old_download;
		erase_cram <= 1;
		ext_crt <= ioctl_download;// && (ioctl_file_ext == ".CRT");
	end 

	// meminit for RAM injection
	if (old_download != ioctl_download && load_prg && !inj_meminit) begin
		inj_meminit <= 1;
		ioctl_load_addr <= 0;
	end

	if (inj_meminit) begin
		if (!ioctl_req_wr) begin
			// check if done
			if (ioctl_load_addr == 'h100) begin
				inj_meminit <= 0;
			end
			else begin
				ioctl_req_wr <= 1;
				
				// Initialize BASIC pointers to simulate the BASIC LOAD command
				case(ioctl_load_addr)
					// TXT (2B-2C)
					// Set these two bytes to $01, $08 just as they would be on reset (the BASIC LOAD command does not alter these)
					'h2B: inj_meminit_data <= 'h01;
					'h2C: inj_meminit_data <= 'h08;

					// SAVE_START (AC-AD)
					// Set these two bytes to zero just as they would be on reset (the BASIC LOAD command does not alter these)
					'hAC, 'hAD: inj_meminit_data <= 'h00;
					
					// VAR (2D-2E), ARY (2F-30), STR (31-32), LOAD_END (AE-AF)
					// Set these just as they would be with the BASIC LOAD command (essentially they are all set to the load end address)
					'h2D, 'h2F, 'h31, 'hAE: inj_meminit_data <= inj_end[7:0];
					'h2E, 'h30, 'h32, 'hAF: inj_meminit_data <= inj_end[15:8];
					
					default: begin
						ioctl_req_wr <= 0;
						
						// advance the address
						ioctl_load_addr <= ioctl_load_addr + 1'b1;
					end
				endcase
			end
		end
	end

	old_meminit <= inj_meminit;
	start_strk  <= old_meminit & ~inj_meminit;
	
	old_st0 <= status[17];
	if (~old_st0 & status[17]) cart_attached <= 0;
	
	if (!erasing && force_erase) begin
		erasing <= 1;
		ioctl_load_addr <= 0;
	end

	if (erasing && !ioctl_req_wr) begin
		erase_to <= erase_to + 1'b1;
		if (&erase_to) begin
			if (ioctl_load_addr < ({erase_cram, 16'hFFFF}))
				ioctl_req_wr <= 1;
			else begin
				erasing <= 0;
				erase_cram <= 0;
			end
		end
	end
end

reg  [3:0] act = 0;
reg [7:0] row_overide;
reg [6:0] col_overide;
always @(posedge clk_sys) begin
 	
	//reg        joy_finish = 0;
	//reg [17:0] joy_last = 0;
	//reg [17:0] joy_key;
	int        to;

	reset_keys <= 0;

/*	joy_key =(joy[9:8] == 3) ?
				(joy[0] ? 18'h005 : joy[1] ? 18'h006 : joy[2] ? 18'h004 : joy[3] ? 18'h00C  :
				 joy[4] ? 18'h003 : joy[5] ? 18'h00B : joy[6] ? 18'h083 : joy[7] ? 18'h00A  : 18'h0):
				(joy[9]) ?
				(joy[0] ? 18'h016 : joy[1] ? 18'h01E : joy[2] ? 18'h026 : joy[3] ? 18'h025  :
			    joy[4] ? 18'h02E : joy[5] ? 18'h045 : joy[6] ? 18'h035 : joy[7] ? 18'h031  : 18'h0):
				(joy[0] ? 18'h174 : joy[1] ? 18'h16B : joy[2] ? 18'h172 : joy[3] ? 18'h175  : 
				 joy[4] ? 18'h05A : joy[5] ? 18'h029 : joy[6] ? 18'h076 : joy[7] ? 18'h2276 : 18'h0);
	
	if(~reset_n) {joy_finish, act} <= 0;

	if(joy[9:8]) begin
		joy_finish <= 1;
		if(!joy[7:0] && joy_last) begin
			joy_last <= 0;
			reset_keys <= 1;
		end
		else if(!joy_last[8:0] && joy_key) begin
			to <= to + 1'd1;
			if(joy_last[17:9] != joy_key[17:9]) begin
				joy_last[17:9] <= joy_key[17:9];
				key <= joy_key[17:9];
				key[9] <= 1;
				key[10] <= ~key[10];
			end
			else if(to > 640000 && joy_last[8:0] != joy_key[8:0]) begin
				joy_last[8:0] <= joy_key[8:0];
				key <= joy_key[8:0];
				key[9] <= 1;
				key[10] <= ~key[10];
			end
		end
		else begin
			to <= 0;
		end
	end
	else if(joy_finish) begin
		joy_last   <= 0;
		key        <= 0;
		key[10]    <= ps2_key[10];
		joy_finish <= 0;
		reset_keys <= 1;
	end
	else*/ 
	if(act) begin            //Need to replace with matrix version
		to <= to + 1;
		if(to > 1280000) begin
		//if(to > 2666666) begin
			to <= 0;
			act <= act + 1'd1;
			case(act)
				// keyboard overrides
				 1: begin				 
				    row_overide<=8'hfb;    //R
				    col_overide<=7'b1110111;
				 end
				 2: col_overide<=7'b1111111;
				 3: begin				 
				    row_overide<=8'hdf;    //U
				    col_overide<=7'b1110111;
				 end
				 4: col_overide<=7'b1111111;
				 5: begin				 
				    row_overide<=8'h7f;    //N
				    col_overide<=7'b1110111;
				 end				 
				 6: col_overide<=7'b1111111;
				 7: begin				 
				    row_overide<=8'hbf;    //Enter
				    col_overide<=7'b1111110;				 
				 end
				 9: begin				 
				    row_overide<=8'hff;    //done!
				    col_overide<=7'b1111111;
				 end
				 10: act <= 0;
			endcase
			//key[9]  <= act[0];
			//key[10] <= (act >= 9) ? ps2_key[10] : ~key[10];
		end
	end
	else begin
		to <= 0;
		//key <= {ps2_key[10], ps2_key[9] & disk_ready, ps2_key[8:0]};
		//key <= {ps2_key[10], ps2_key[9] , ps2_key[8:0]};
	end
	if(start_strk & ~status[50]) begin
		act <= 1;
	//	key <= 0;
	end
end


/*wire ezfl_save = 1'b0;//status[61] | (status[62] & OSD_STATUS & ezfl_mod);
reg  ezfl_mod = 0;
reg  ezfl_idx = 0;
reg  ezfl_save_en = 0;
reg save_old = 0;
reg ext_old = 0;
always @(posedge clk_sys) begin
	

	if(cart_mem_req) ezfl_mod <= 1;
	if(ioctl_download && load_crt) ezfl_mod <= 0;
	if(ioctl_upload) {ezfl_mod, ezfl_save_en} <= 0;
	
	save_old <= ezfl_save;
	if(~save_old & ezfl_save) ezfl_idx <= ~status[61];
	
	ext_old <= ext_crt;
	if(~ext_old & ext_crt) ezfl_save_en <= 1;
end
*/

/*
reu reu
(
	.clk(clk_sys),
	.reset(~reset_n),
	.cfg(reu_cfg),
	.wrap(reu_wrap),

	.dma_req(dma_req),

	.dma_cycle(dma_cycle),
	.dma_addr(dma_addr),
	.dma_dout(dma_dout),
	.dma_din(dma_din),
	.dma_we(dma_we),

	.ram_cycle(ext_cycle),
	.ram_addr(reu_ram_addr),
	.ram_dout(reu_ram_dout),
	.ram_din(sdram_data),
	.ram_we(reu_ram_we),
	
	.cpu_addr(c64_addr),
	.cpu_dout(c64_data_out),
	.cpu_din(reu_dout),
	.cpu_we(ram_we),
	.cpu_cs(IOF),
	
	.irq(reu_irq)
);
*/
reg ext_cycle_d;
always @(posedge clk_sys) ext_cycle_d <= ext_cycle;
//wire reu_ram_ce = ~ext_cycle_d & ext_cycle & dma_req;



wire        refresh;

reg [1:0] ce_sys_div = 0;
wire ce_sys = (ce_sys_div == 0);
always @(posedge clk_sys) ce_sys_div <= ce_sys_div + 1'd1;

//------------- TAP / C1530 Datassette -------------------


wire       cass_write;
wire       cass_motor;
wire       cass_sense;
wire       cass_read;
wire       cass_run;
wire       cass_finish;
wire       cass_snd = cass_read & status[11] & ~cass_finish;

wire       tap_loaded;
wire [24:0] tap_play_addr;
wire [24:0] tap_last_addr;

wire [2:0] tape_ovl_color;



tape_subsystem tape
(
	.clk(clk_sys),
	.ce(ce_sys),
	.reset_n(reset_n),
	.hblank(hblank),
	.vblank(vblank),
	.ntsc(ntsc),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_data(ioctl_data),
	.load_tap(load_tap),
	.ioctl_wait(tape_ioctl_wait),

	.io_cycle(io_cycle),
	.sdram_data(ram_din),

	.cmd_play(status[7] | tape_play),
	.cmd_stop(status[95] | tape_key_stop),
	.cmd_rew(status[93] | tape_key_rew),
	.cmd_ff(status[94] | tape_key_ff),
	.cmd_unload(status[23]),
	.cmd_counter_reset(status[91] | tape_key_counter_reset),
	.counter_enable(status[92]),
	.tape_autoplay_off(status[39]),
	.tape_autounload_off(status[90]),

	.cass_write(cass_write),
	.cass_motor(cass_motor),
	.cass_sense(cass_sense),
	.cass_read(cass_read),
	.cass_run(cass_run),
	.cass_finish(cass_finish),

	.tap_loaded(tap_loaded),
	.tap_play_addr(tap_play_addr),
	.tap_last_addr(tap_last_addr),

	.pixel_color(tape_ovl_color)
);


reg use_tape;
always @(posedge clk_sys) begin
	integer to = 0;

	if(to) to <= to - 1;
	else use_tape <= status[36];

	if(tap_loaded | ~cass_sense) begin
		use_tape <= 1;
		to <= 128000000; //4s
	end
end

reg [26:0] act_cnt;
always @(posedge clk_sys) act_cnt <= act_cnt + (cass_sense ? 4'd1 : 4'd8);
wire tape_led = tap_loaded && (act_cnt[26] ? (~(~cass_sense & cass_motor) && act_cnt[25:18] > act_cnt[7:0]) : act_cnt[25:18] <= act_cnt[7:0]);




wire [17:0] audio_l,audio_r;

wire audioext_l;
wire audioext_r;

// audio jack

wire [15:0] opl_out=0;
wire  [7:0] opl_dout=0;

reg [11:0] sid_ld_addr = 0;
reg [15:0] sid_ld_data = 0;
reg        sid_ld_wr   = 0;
always @(posedge clk_sys) begin
	sid_ld_wr <= 0;
	if(ioctl_wr && load_flt && ioctl_addr < 6144) begin
		if(ioctl_addr[0]) begin
			sid_ld_data[15:8] <= ioctl_data;
			sid_ld_addr <= ioctl_addr[12:1];
			sid_ld_wr <= 1;
		end
		else begin
			sid_ld_data[7:0] <= ioctl_data;
		end
	end
end

//DigiMax
reg [8:0] dac_l, dac_r;
always @(posedge clk_sys) begin
/*	reg [8:0] dac[4];
	reg [3:0] act;

	if(!status[41:40] || ~reset_n) begin
		dac <= '{0,0,0,0};
		act <= 0;
	end
	else if((status[41] ? iof_we : ioe_we) && ~c64_addr[2]) begin
		dac[c64_addr[1:0]] <= c64_data_out;
		if(c64_data_out) act[c64_addr[1:0]] <= 1;
	end

	// guess mono/stereo/4-chan modes
	if(act<2) begin
		dac_l <= dac[0] + dac[0];
		dac_r <= dac[0] + dac[0];
	end
	else if(act<3) begin
		dac_l <= dac[1] + dac[1];
		dac_r <= dac[0] + dac[0];
	end
	else begin
		dac_l <= dac[1] + dac[2];
		dac_r <= dac[0] + dac[3];
	end*/
	dac_l<=8'd0;
	dac_r<=8'd0;
end

localparam [3:0] comp_f1 = 4;
localparam [3:0] comp_a1 = 2;
localparam       comp_x1 = ((32767 * (comp_f1 - 1)) / ((comp_f1 * comp_a1) - 1)) + 1; // +1 to make sure it won't overflow
localparam       comp_b1 = comp_x1 * comp_a1;

function [15:0] compr; input [15:0] inp;
	reg [15:0] v, v1;
	begin
		v  = inp[15] ? (~inp) + 1'd1 : inp;
		v1 = (v < comp_x1[15:0]) ? (v * comp_a1) : (((v - comp_x1[15:0])/comp_f1) + comp_b1[15:0]);
		v  = v1;
		compr = inp[15] ? ~(v-1'd1) : v;
	end
endfunction

reg [15:0] alo,aro;
reg [15:0] alo_u,aro_u;
always @(posedge clk_sys) begin
	reg [16:0] alm,arm;
	reg [15:0] cout;
	reg [15:0] cin;
	
	cin  <= opl_out - {{3{opl_out[15]}},opl_out[15:3]};
	cout <= compr(cin);

	alm <= {cout[15],cout} + {audio_l[17],audio_l[17:2]} + {2'b0,dac_l,6'd0} + {cass_snd, 9'd0};
	arm <= {cout[15],cout} + {audio_r[17],audio_r[17:2]} + {2'b0,dac_r,6'd0} + {cass_snd, 9'd0};
	alo <= ^alm[16:15] ? {alm[16], {15{alm[15]}}} : alm[15:0];
	aro <= ^arm[16:15] ? {arm[16], {15{arm[15]}}} : arm[15:0];
end

 
sigma_delta_dac #(15) sd_l
(
	.CLK(clk_sys),
	.RESET(~reset_n),
	.DACin({~alo[15], alo[14:0]}),
	.DACout(audioext_l)
);

sigma_delta_dac #(15) sd_2
(
	.CLK(clk_sys),
	.RESET(~reset_n),
	.DACin({~aro[15], aro[14:0]}),
	.DACout(audioext_r)
);    
     
  
/*dac #(.MSBI_G(15)) dac_audio_L (   
      .clk_i(clk_sys),
      .res_i(~reset_n),
      //.dac_i(audio_l[16:0]),
      .dac_i({~alo[15], alo[14:0]}),
      .dac_o(audioext_l)
   );*/
   
always @(posedge clk_sys)
         audioext_l_o <= audioext_l;
         
always @(posedge clk_sys)
         audioext_r_o <= audioext_r;
/*         
         
dac #(.MSBI_G(17)) dac_audio_R (   
      .clk_i(clk_sys),
      .res_i(~reset_n),
      .dac_i(audio_r[16:0]),
      .dac_o(audioext_r)
   );
   
always @(posedge clk_sys)
         audioext_r_o <= audioext_r;

 */



 /*
   
 always @(posedge clk_sys)
    audio_m <= ({1'b0,audio_l[16:0]}) + ({1'b0,audio_r[16:0]});


dac #(.MSBI_G(17)) dac_audio_M (   
      .clk_i(clk_sys),
      .res_i(~reset_n),
      .dac_i(audio_m),
      .dac_o(audioext_m)
   );
   
always @(posedge clk_sys)
         audioext_m_o <= audioext_m;
   */      

// ***** VIDEO ***********

wire  [7:0] r,g,b;
wire [2:0] osd_r,osd_g,osd_b;
wire csync,tv_disp;

wire  [2:0] o_r,o_g,o_b;
assign o_r=osd?osd_r:r[2:0];
assign o_g=osd?osd_g:g[2:0];
assign o_b=osd?osd_b:b[2:0];

//wire [3:0] vgar=(hblank | vblank)?4'b0000:o_r[7:4];
//wire [3:0] vgag=(hblank | vblank)?4'b0000:o_g[7:4];
//wire [3:0] vgab=(hblank | vblank)?4'b0000:o_b[7:4];
wire [2:0] tvr=~tv_disp?3'b000:o_r;
wire [2:0] tvg=~tv_disp?3'b000:o_g;
wire [2:0] tvb=~tv_disp?3'b000:o_b;


//cart_addr also is the c64 cpu address
//wire [15:0] ram_addr=( io_cycle ? (cart_mem_req ? cart_addr[15:0]   : io_cycle_addr[15:0] ) : ext_cycle ? c64_addr[15:0] : cart_addr[15:0]   );
//wire [21:0] ram_addr=( io_cycle ? (cart_mem_req ? cart_addr : io_cycle_addr ) : ext_cycle ? reu_ram_addr : cart_addr  );
//REU removed
wire [21:0] ram_addr=( io_cycle ? (cart_mem_req ? cart_addr[21:0] : io_cycle_addr ) : cart_addr[21:0]  );

assign RAM_A=ram_addr[20:1];//{5'b00000,c64_addr[15:1]};
assign RAM_UB=~ram_addr[0];
assign RAM_LB=ram_addr[0];

//wire [7:0] ram_dout=( io_cycle ? (cart_mem_req ? cart_wrdata : io_cycle_data ) : ext_cycle ? reu_ram_out : cart_wrdata );
wire [7:0] ram_dout=( io_cycle ? (cart_mem_req ? cart_wrdata : io_cycle_data ) : cart_wrdata );




assign RAM_CS=~comb_ce;
assign RAM_OE=1'b0;//ram_we;
//wire comb_we=( io_cycle ? (cart_mem_req ? cart_we     : io_cycle_we   ) : ext_cycle ? reu_ram_we   : cart_we     );//ram_we;
wire comb_we=( io_cycle ? (cart_mem_req ? cart_we     : io_cycle_we   ) : cart_we     );//ram_we;
wire comb_ce=( io_cycle ? (cart_mem_req ? cart_ce     : io_cycle_ce   ) : cart_ce     );//ram_we;
assign RAM_D=comb_we?{ram_dout,ram_dout}:16'hz;
assign RAM_WE=~comb_we;




/*blk_mem_gen_0 fake_ram (
  .clka(clk_sys),    // input wire clka
  .ena  (1'b1),
  .wea(ram_we),      // input wire [0 : 0] wea
  .addra(c64_addr),  // input wire [15 : 0] addra
  .dina(c64_data_out),    // input wire [7 : 0] dina
  .douta(c64_data_in)  // output wire [7 : 0] douta
  //.addra( io_cycle ? (cart_mem_req ? cart_addr[15:0]   : io_cycle_addr[15:0] ) : ext_cycle ? reu_ram_addr[15:0] : cart_addr[15:0]   ),
  //.ena  ( io_cycle ? (cart_mem_req ? cart_ce     : io_cycle_ce   ) : ext_cycle ? reu_ram_ce   : cart_ce     ),
  //.wea  ( io_cycle ? (cart_mem_req ? cart_we     : io_cycle_we   ) : ext_cycle ? reu_ram_we   : cart_we     ),
  //.dina ( io_cycle ? (cart_mem_req ? cart_wrdata : io_cycle_data ) : ext_cycle ? reu_ram_dout : cart_wrdata )
  //.douta(sdram_data)  // output wire [7 : 0] douta
  
);
*/

wire [31:0] osd_ctrl_out;
reg osd;
reg old_bt_drv;
reg old_osd_ctrl;
always @(posedge clk_sys)
begin
    if (!reset_n)
    begin
        osd<=0;
        old_bt_drv<=1;
        old_osd_ctrl<=0;
    end
    else
    begin
        old_bt_drv<=bt_drv_db;
        old_osd_ctrl<=osd_ctrl_out[0];
        if ((!bt_drv_db) && (old_bt_drv)) osd<=~osd;
        else if (old_osd_ctrl!=osd_ctrl_out[0]) osd<=osd_ctrl_out[0];
    //   if (cart_attached) osd<=0;
        if (close_osd) osd<=0;    
        if (inj_meminit) osd<=0;
    end  
end


wire [15:0] osd_dout; 

wire [15:0] osd_din;
wire [9:0] osd_addr;
wire [15:0] osd_ctrl_dout;
wire osd_we;

wire [7:0] osd_char;
reg [15:0] osd_addr_latch;
reg [7:0] osd_byte_latch;

reg [2:0] osd_r_f,osd_g_f,osd_b_f;
reg [2:0] osd_r_b,osd_g_b,osd_b_b;
reg [2:0] osd_r_fl,osd_g_fl,osd_b_fl;
reg [2:0] osd_r_bl,osd_g_bl,osd_b_bl;
assign osd_r=osd_char_bit?osd_r_fl:osd_r_bl;
assign osd_g=osd_char_bit?osd_g_fl:osd_g_bl;
assign osd_b=osd_char_bit?osd_b_fl:osd_b_bl;

wire osd_char_bit=osd_byte_latch[7];

always_comb begin			
			//case (osd_dout[15:12])
			case (osd_addr_latch[11:8])
			'h0: begin
			     osd_r_f=3'h0;
			     osd_g_f=3'h0;
			     osd_b_f=3'h0;
			end
			'h1: begin
			     osd_r_f=3'h7;
			     osd_g_f=3'h7;
			     osd_b_f=3'h7;
			end
			'h2: begin
			     osd_r_f=3'h4;
			     osd_g_f=3'h1;
			     osd_b_f=3'h1;
			end
			'h3: begin
			     osd_r_f=3'h3;
			     osd_g_f=3'h6;
			     osd_b_f=3'h6;
			end
			'h4: begin
			     osd_r_f=3'h4;
			     osd_g_f=3'h1;
			     osd_b_f=3'h5;
			end
			'h5: begin
			     osd_r_f=3'h2;
			     osd_g_f=3'h5;
			     osd_b_f=3'h2;
			end
			'h6: begin
			     osd_r_f=3'h1;
			     osd_g_f=3'h1;
			     osd_b_f=3'h5;
			end
			'h7: begin
			     osd_r_f=3'h7;
			     osd_g_f=3'h7;
			     osd_b_f=3'h3;
			end
			'h8: begin
			     osd_r_f=3'h4;
			     osd_g_f=3'h2;
			     osd_b_f=3'h1;
			end
			'h9: begin
			     osd_r_f=3'h2;
			     osd_g_f=3'h2;
			     osd_b_f=3'h0;
			end
			'ha: begin
			     osd_r_f=3'h6;
			     osd_g_f=3'h3;
			     osd_b_f=3'h3;
			end
			'hb: begin
			     osd_r_f=3'h2;
			     osd_g_f=3'h2;
			     osd_b_f=3'h2;
			end
			'hc: begin
			     osd_r_f=3'h3;
			     osd_g_f=3'h3;
			     osd_b_f=3'h3;
			end
			'hd: begin
			     osd_r_f=3'h4;
			     osd_g_f=3'h7;
			     osd_b_f=3'h4;
			end
			'he: begin
			     osd_r_f=3'h3;
			     osd_g_f=3'h3;
			     osd_b_f=3'h7;
			end
			'hf: begin
			     osd_r_f=3'h5;
			     osd_g_f=3'h5;
			     osd_b_f=3'h5;
			end
			endcase
			
			//case (osd_dout[19:16])
			case (osd_addr_latch[15:12])
			'h0: begin
			     osd_r_b=3'h0;
			     osd_g_b=3'h0;
			     osd_b_b=3'h0;
			end
			'h1: begin
			     osd_r_b=3'h7;
			     osd_g_b=3'h7;
			     osd_b_b=3'h7;
			end
			'h2: begin
			     osd_r_b=3'h4;
			     osd_g_b=3'h1;
			     osd_b_b=3'h1;
			end
			'h3: begin
			     osd_r_b=3'h3;
			     osd_g_b=3'h6;
			     osd_b_b=3'h6;
			end
			'h4: begin
			     osd_r_b=3'h4;
			     osd_g_b=3'h1;
			     osd_b_b=3'h5;
			end
			'h5: begin
			     osd_r_b=3'h2;
			     osd_g_b=3'h5;
			     osd_b_b=3'h2;
			end
			'h6: begin
			     osd_r_b=3'h1;
			     osd_g_b=3'h1;
			     osd_b_b=3'h5;
			end
			'h7: begin
			     osd_r_b=3'h7;
			     osd_g_b=3'h7;
			     osd_b_b=3'h3;
			end
			'h8: begin
			     osd_r_b=3'h4;
			     osd_g_b=3'h2;
			     osd_b_b=3'h1;
			end
			'h9: begin
			     osd_r_b=3'h2;
			     osd_g_b=3'h2;
			     osd_b_b=3'h0;
			end
			'ha: begin
			     osd_r_b=3'h6;
			     osd_g_b=3'h3;
			     osd_b_b=3'h3;
			end
			'hb: begin
			     osd_r_b=3'h2;
			     osd_g_b=3'h2;
			     osd_b_b=3'h2;
			end
			'hc: begin
			     osd_r_b=3'h3;
			     osd_g_b=3'h3;
			     osd_b_b=3'h3;
			end
			'hd: begin
			     osd_r_b=3'h4;
			     osd_g_b=3'h7;
			     osd_b_b=3'h4;
			end
			'he: begin
			     osd_r_b=3'h3;
			     osd_g_b=3'h3;
			     osd_b_b=3'h7;
			end
			'hf: begin
			     osd_r_b=3'h5;
			     osd_g_b=3'h5;
			     osd_b_b=3'h5;
			end			
			endcase

end



chargen_wrapper chargen_wrapper
(
		
	.clk(clk_sys),
	.address({osd_addr_latch[7],1'b0,osd_addr_latch[6:0],osd_ycount[2:0]}),
	//.address({9'd1,osd_ycount[2:0]}),
	.dout(osd_char)
);

osd_mem osd_mem (
  .clka(clk_ctrl),    // input wire clka
  .wea(osd_we),      // input wire [0 : 0] wea
  .addra(osd_addr),  // input wire [9 : 0] addra
  .dina(osd_din),    // input wire [15 : 0] dina
  .douta(osd_ctrl_dout),  // output wire [15 : 0] douta
  .clkb(clk_sys),    // input wire clkb
  .web(1'b0),      // input wire [0 : 0] web
  .addrb(osd_screenAddr[9:0]),  // input wire [9 : 0] addrb
  .dinb(16'd0),    // input wire [15 : 0] dinb
  .doutb(osd_dout)  // output wire [15 : 0] doutb
);

reg [8:0] osd_xcount;
reg [8:0] osd_ycount;
reg old_hblank;
reg old_vblank;
reg [1:0] pix_div;
reg osd_drawh;
reg osd_drawv;
wire osd_drawArea=osd_drawh & osd_drawv;

always @(posedge clk_sys)
begin
    old_hblank<=hblank;
    old_vblank<=vblank;
    if ((!vblank) && (old_vblank))
    begin
        osd_ycount<=0;
    end        
    else
    begin
        if ((!hblank) && (old_hblank))
        begin
            osd_xcount<=0;
            osd_ycount<=osd_ycount+1;
            if (osd_ycount==39) osd_drawv<=1;
            if (osd_ycount==239) osd_drawv<=0;
            pix_div=2'b11;
        end
        else
        begin
            pix_div<= pix_div+1;
            if (pix_div==2'b00)
            begin
                //if ({osd_xcount[8:3],osd_xcount[0]}==6) osd_drawh<=1;
                //if ({osd_xcount[8:3],osd_xcount[0]}==6+80) osd_drawh<=0;
                if (osd_xcount[8:3]==3) osd_drawh<=1;
                if (osd_xcount[8:3]==3+40) osd_drawh<=0;
                
                osd_xcount<=osd_xcount+1;
                if (osd_xcount[2:0]==3'b110) osd_addr_latch<=osd_dout;
               /* if (osd_xcount[2:0]==3'b111)
                begin
                    if (osd_drawArea)
                    begin
                        osd_byte_latch<=osd_char;                                                
                    end
                    else
                    begin
                        osd_byte_latch<=8'h0;                       
                    end                    
                end    
                else osd_byte_latch<={osd_byte_latch[6:0],1'b0};*/
                
                if (osd_xcount[2:0]==3'b111)
                begin
                    //osd_addr_latch<=osd_dout;
                    if (osd_drawArea)
                    begin                        
                        osd_byte_latch<=osd_char;
                        osd_r_fl<=osd_r_f;
                        osd_g_fl<=osd_g_f;
                        osd_b_fl<=osd_b_f;
                        osd_r_bl<=osd_r_b;
                        osd_g_bl<=osd_g_b;
                        osd_b_bl<=osd_b_b;                        
                    end
                    else
                    begin                    
                        osd_byte_latch<=8'h0;   
                        osd_r_fl<=3'h7;
                        osd_g_fl<=3'h7;
                        osd_b_fl<=3'h7;
                        osd_r_bl<=3'h1;
                        osd_g_bl<=3'h1;
                        osd_b_bl<=3'h5;                        
                    end                    
                end
                else osd_byte_latch<={osd_byte_latch[6:0],1'b0};                   
            end
        end
    end 
    
    //if ((osd_ycount[2:0]==0) && (osd_xcount[2:0]==0)) osd_addr_latch<=osd_dout[11:0];
     
    
end

wire [11:0] osd_screenAddr=(osd_ycount[8:3]-5)*40+(osd_xcount[8:3]-3);


//wire aec_out;
/*reg old_aec;
reg [15:0] osd_latched_dout;
always @(posedge clk_sys)
begin
    old_aec<=aec_out;
    if ((aec_out) && (!old_aec) && (c64_addr!='h3fff)) osd_latched_dout<=osd_dout;
end*/


//wire freeze_sync;
reg freeze;
reg old_sync;
always @(posedge clk_sys) begin	
	//old_sync <= freeze_sync;
	//if(old_sync ^ freeze_sync) freeze <= osd;
	freeze <= osd;
end

wire        ntsc_req = status[2];

assign SD_CS1=1'b1;

//NEXT Real Time Clock I2C address is  0x68
CtrlModule CtrlModule (
			.clk(clk_ctrl), 
			.reset_n(1'b1),        //this needs to stay running once system has booted
			.osd_addr(osd_addr),
			.osd_din(osd_din),
			.osd_we(osd_we),
			.osd_ctrl({31'h0,osd}),
			.osd_ctrl_out(osd_ctrl_out),
			.osd_dout(osd_ctrl_dout),
			.spi_miso(SD_MISO),
			.spi_mosi(SD_MOSI), 
			.spi_clk(SD_CLK), 
			.spi_cs(SD_CS),
			.ps2_key({joyb[4:0],joya[4:0],5'b00000,key_joy}),
			.status(status),
			
			//.cfg_debug(cfg_debug),
			
			.ioctl_download(ioctl_download),
			.ioctl_index(ioctl_index),
			.ioctl_addr(ioctl_addr),		
		    .ioctl_wr(ioctl_wr),
		    .ioctl_dout(ioctl_data),
		    .ioctl_wait(ioctl_req_wr | reset_wait)//|ioctl_req_rd|tape_ioctl_wait)
); 
 
 wire c64_iec_atn;
 wire c64_iec_data;
assign iec_clk_io=c64_iec_clk?1'bz:1'b0;
assign iec_data_io=c64_iec_data?1'bz:1'b0;
wire drive_iec_clk=iec_clk_io;
wire drive_iec_data=iec_data_io;
assign bus_y_o=c64_iec_clk?1'b0:1'b1;        //1=cpu transmit
assign iec_atn_o=c64_iec_atn;
assign bus_busack_n_o=c64_iec_data?1'b0:1'b1; 
//assign bus_halt_n_o=1'b1;
 
reg [6:0] joya;
reg [6:0] joyb;

always @(posedge clk_sys) begin
    joysel_o<=~joysel_o;
    if (joysel_o) joyb<={2'b00,~joyp6_i,~joyp4_i,~joyp3_i,~joyp2_i,~joyp1_i}; else joya<={2'b00,~joyp6_i,~joyp4_i,~joyp3_i,~joyp2_i,~joyp1_i}; 
end
 
fpga64_sid_iec fpga64
(
	.clk32(clk_sys),
	.reset_n(reset_n),
	.pause(1'b0),//(freeze),
	.pause_out(c64_pause),
	//.bios(status[15:14]),        //1=standard rom
	
	//.turbo_mode({status[47] & ~disk_access, status[46]}),
	.turbo_mode({status[47] , status[46]}),
	.turbo_speed(status[49:48]),

	//.ps2_key(osd?11'd0:key),
	//.kbd_reset((~reset_n) | reset_keys),//((~reset_n & ~status[1]) | reset_keys),
	//.shift_mod(2'b00),//(~status[60:59]),
	.spec_col(osd?7'b1111111:act?col_overide:spec_col),
    .spec_row(act?row_overide:spec_row),

	.ramAddr(c64_addr),
	.ramDout(c64_data_out),
	.ramDin(c64_data_in),
	.ramCE(ram_ce),
	.ramWE(ram_we),

	.vic_variant(status[35:34]),
	.ntscmode(ntsc),
	.hsync(hsync),
	.vsync(vsync),
	.palette(status[84:82]),
	.r(r),
	.g(g),
	.b(b),

	.game(game),
	.exrom(exrom),
	.UMAXromH(UMAXromH),
	.irq_n(1'b1),
	.nmi_n(~nmi),
	.nmi_ack(nmi_ack),
	//.freeze_key(freeze_key),
	.tape_play(tape_play),
	.tape_rew(tape_key_rew),
	.tape_stop(tape_key_stop),
	.tape_ff(tape_key_ff),
	.tape_reset_counter(tape_key_counter_reset),
	.mod_key(mod_key),
	.roml(romL),
	.romh(romH),
	.ioe(IOE),
	.iof(IOF),
	.io_rom(io_rom),
	//.io_ext(cart_oe | reu_oe | opl_en),
	.io_ext(cart_oe),
	//.io_data(cart_oe ? cart_data : reu_oe ? reu_dout : opl_dout),
	.io_data(cart_data),
	.dma_req(1'b0),//(dma_req),
	.dma_cycle(dma_cycle),
	.dma_addr(16'd0),//(dma_addr),
	.dma_dout(8'b00000000),//(dma_dout),
	.dma_din(dma_din),
	.dma_we(1'b0),//(dma_we),
	.irq_ext_n(1'b1),//(~reu_irq),

	.cia_mode(status[45]),

	.joya(status[3]?joyb:joya),//({(pd12_mode && !joy[9:8]) ? joyA_c64[6:5] : 2'b00, joyA_c64[4:0] | {1'b0, pd12_mode[1] & paddle_2_btn, pd12_mode[1] & paddle_1_btn, 2'b00} | {pd12_mode[0] & mouse_btn[0], 3'b000, pd12_mode[0] & mouse_btn[1]}}),
	.joyb(status[3]?joya:joyb),//({(pd34_mode && !joy[9:8]) ? joyB_c64[6:5] : 2'b00, joyB_c64[4:0] | {1'b0, pd34_mode[1] & paddle_4_btn, pd34_mode[1] & paddle_3_btn, 2'b00} | {pd34_mode[0] & mouse_btn[0], 3'b000, pd34_mode[0] & mouse_btn[1]}}),

	.pot1(8'd0),//(pd12_mode[1] ? paddle_1 : pd12_mode[0] ? mouse_x : {8{joyA_c64[5]}}),
	.pot2(8'd0),//(pd12_mode[1] ? paddle_2 : pd12_mode[0] ? mouse_y : {8{joyA_c64[6]}}),
	.pot3(8'd0),//(pd34_mode[1] ? paddle_3 : pd34_mode[0] ? mouse_x : {8{joyB_c64[5]}}),
	.pot4(8'd0),//(pd34_mode[1] ? paddle_4 : pd34_mode[0] ? mouse_y : {8{joyB_c64[6]}}),

	.io_cycle(io_cycle),
	.ext_cycle(ext_cycle),
	.refresh(refresh),

	.sid_ld_clk(clk_sys),
	.sid_ld_addr(sid_ld_addr),
	.sid_ld_data(sid_ld_data),
	.sid_ld_wr(sid_ld_wr),
	.sid_mode(status[22:20]),
	.sid_filter(2'b11),
	.sid_ver({status[16],status[13]}),
	.sid_cfg({status[68:67],status[65:64]}),
	.sid_fc_off_l(status[66] ? (13'h600 - {status[72:70],7'd0}) : 13'd0),
	.sid_fc_off_r(status[69] ? (13'h600 - {status[75:73],7'd0}) : 13'd0),
	.sid_digifix(~status[37]),
	.audio_l(audio_l),
	.audio_r(audio_r),
	//.audio_l_u(audio_l),
	//.audio_r_u(audio_r),


	.iec_data_o(c64_iec_data),
	.iec_atn_o(c64_iec_atn),
	.iec_clk_o(c64_iec_clk),
	.iec_data_i(drive_iec_data),
	.iec_clk_i(drive_iec_clk),
	
	.pb_i(pb_i),
	.pb_o(pb_o),
	.pa2_i(pa2_i),
	.pa2_o(pa2_o),
	.pc2_n_o(pc2_n_o),
	.flag2_n_i(flag2_n_i),
	.sp2_i(sp2_i),
	.sp2_o(sp2_o),
	.sp1_i(sp1_i),
	.sp1_o(sp1_o),
	.cnt2_i(cnt2_i),
	.cnt2_o(cnt2_o),
	.cnt1_i(cnt1_i),
	.cnt1_o(cnt1_o),
	

	.c64rom_addr(ioctl_addr[13:0]),
	.c64rom_data(ioctl_data),
	.c64rom_wr(load_rom && !ioctl_addr[16:14] && ioctl_download && ioctl_wr),

	.cass_write(cass_write),
	.cass_motor(cass_motor),
	.cass_sense(~tape_adc_act & (use_tape ? cass_sense : cass_rtc)),
	.cass_read(tape_adc_act ? ~tape_adc : cass_read)		
);


endmodule
/*
module myBUFG (O, I);

    parameter cds_action = "ignore";

    output  [7:0] O;

    input   [7:0] I;
    
       buf   BUFFER1  (O[0], I[0]);
       buf   BUFFER2  (O[1], I[1]);
       buf   BUFFER3  (O[2], I[2]);
       buf   BUFFER4  (O[3], I[3]);
       buf   BUFFER5  (O[4], I[4]);
       buf   BUFFER6  (O[5], I[5]);
       buf   BUFFER7  (O[6], I[6]);
       buf   BUFFER8  (O[7], I[7]);
       

    specify

     // Synthesis parameters
    
     // Specify path delays

           (I *> O) = (1, 1);

    endspecify

endmodule
*/

module debouncer #(
    parameter CLK_FREQ = 50_000_000,    // Clock frequency in Hz
    parameter DEBOUNCE_TIME_MS = 20     // Debounce time in milliseconds
)(
    input wire clk,           // System clock
    input wire rst_n,         // Active low reset
    input wire button_in,     // Raw button input (noisy)
    output reg button_out     // Debounced button output
);

    // Calculate counter value for debounce time
    localparam COUNTER_MAX = (CLK_FREQ / 1000) * DEBOUNCE_TIME_MS;
    localparam COUNTER_WIDTH = $clog2(COUNTER_MAX + 1);

    // Internal registers
    reg [COUNTER_WIDTH-1:0] counter;
    reg button_sync_0, button_sync_1;

    // Double-flop synchronizer to avoid metastability
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            button_sync_0 <= 1'b1;
            button_sync_1 <= 1'b1;
        end else begin
            button_sync_0 <= button_in;
            button_sync_1 <= button_sync_0;
        end
    end

    // Debounce logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 0;
            button_out <= 1'b1;
        end else begin
            if (button_sync_1 != button_out) begin
                // Input differs from output, start/continue counting
                counter <= counter + 1;
                if (counter >= COUNTER_MAX) begin
                    button_out <= button_sync_1;
                    counter <= 0;
                end
            end else begin
                // Input matches output, reset counter
                counter <= 0;
            end
        end
    end

endmodule