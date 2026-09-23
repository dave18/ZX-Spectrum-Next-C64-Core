`timescale 1ns/1ps
// ============================================================================
// C1530 Datassette - Tape Counter with on-screen overlay
//
// Improved version of the mechanical tape counter.
//
// Key fixes/changes vs. the original:
//  - FIXED: rewind digit decrement (the original accidentally incremented d_tens
//     when rolling under 0, breaking the counter during REW).
//  - Replaced the huge nested digit case with a compact FONT ROM array.
//  - Encapsulated BCD increment/decrement in helper functions.
//  - Derived clock-divider values from parameters instead of hard-coded literals.
//  - Used always_ff / always_comb consistently and cleaned up magic numbers.
//  - Made overlay position configurable via parameters.
//  - FIX: Widened tick_div / wind_div to prevent counter freeze on clocks >= 65MHz.
//  - FIX: Uncoupled vblank coordinate resets from ce to guarantee clean sweeps.
// ============================================================================

module tape_counter #(
	parameter int CLK_HZ       = 32_000_000,
	parameter int TICK_HZ      = 1000,        // 1 kHz -> 1 tick = 1 ms of tape
	parameter int THRESH_BASE  = 2693,        // ms/rotation at tape start
	parameter int THRESH_INC   = 6,           // ms/rotation added per rotation
	parameter int ABS_MAX      = 8191,        // absolute rotation saturation / 13-bit time-map limit
	parameter int WIND_MS      = 476,         // ms per counter click during FF/REW
	parameter int POS_X_PAL    = 316,         // align with drive overlay X origin (PAL)
	parameter int POS_X_NTSC   = 323,         // align with drive overlay X origin (NTSC)
	parameter int POS_Y_PAL    = 249,         // third drive-overlay row (PAL: 237 + 12)
	parameter int POS_Y_NTSC   = 241          // third drive-overlay row (NTSC: 229 + 12)
) (
	input        clk,         // clk_sys (~32 MHz)
	input        ce,          // ~8 MHz pixel clock-enable

	input        hblank,
	input        vblank,
	input        ntsc,

	// Control
	input        enable,        // 1 = overlay visible
	input        tape_loaded,   // 1 = a tape is loaded
	input        new_tape,      // pulse/level: reset counter & position
	input        counter_reset, // OSD "Tape Counter Reset" pulse
	input [24:0] tap_play_addr, // current TAP file position
	input [24:0] tap_last_addr, // total TAP file size

	// Transport state from c1530 (active low)
	input        cass_run,      // 0 = motor rotating
	input        cass_sense,    // 0 = PLAY pressed

	// Winding (top-level guarantees mutual exclusion)
	input        ff,            // 1 = fast-forward active
	input        rew,           // 1 = rewind active

	// Synchronization back to the top-level tape position
	output reg        wind_step,
	output reg [12:0] abs_count,       // absolute counter value (index into time_map)

	output reg  [2:0] pixel_color
);

// ---------------------------------------------------------------------------
// Local constants
// ---------------------------------------------------------------------------
localparam TICK_DIV   = CLK_HZ / TICK_HZ;   // 32000 at 32 MHz / 1 kHz
localparam WIND_TICKS = (WIND_MS < 1) ? 1 : WIND_MS;

localparam [2:0] C_TRANSPARENT = 3'd0;
localparam [2:0] C_GREEN       = 3'd2;
localparam [2:0] C_YELLOW      = 3'd6;
localparam [2:0] C_RED         = 3'd4;
localparam [2:0] C_BLUE        = 3'd1;

// ---------------------------------------------------------------------------
// BCD helpers
// ---------------------------------------------------------------------------
function automatic [11:0] bcd_inc(input [11:0] bcd);
	reg [3:0] h, t, o;
	begin
		h = bcd[11:8]; t = bcd[7:4]; o = bcd[3:0];
		if (o == 4'd9) begin
			o = 4'd0;
			if (t == 4'd9) begin
				t = 4'd0;
				if (h == 4'd9) h = 4'd0;
				else           h = h + 4'd1;
			end else begin
				t = t + 4'd1;
			end
		end else begin
			o = o + 4'd1;
		end
		bcd_inc = {h, t, o};
	end
endfunction

function automatic [11:0] bcd_dec(input [11:0] bcd);
	reg [3:0] h, t, o;
	begin
		h = bcd[11:8]; t = bcd[7:4]; o = bcd[3:0];
		if (o == 4'd0) begin
			o = 4'd9;
			if (t == 4'd0) begin
				t = 4'd9;
				if (h == 4'd0) h = 4'd9;
				else           h = h - 4'd1;
			end else begin
				t = t - 4'd1;   // FIX: original had +1 here, causing REW to go wrong
			end
		end else begin
			o = o - 4'd1;
		end
		bcd_dec = {h, t, o};
	end
endfunction

// ---------------------------------------------------------------------------
// Tick generators
// ---------------------------------------------------------------------------
// FIX: Widened tick_div dynamically to prevent wrap-around bugs at high frequencies
reg [$clog2(TICK_DIV):0] tick_div = 0;
reg                      tick_1k  = 0;
always @(posedge clk) begin
	tick_1k <= 0;
	if (tick_div >= TICK_DIV[$clog2(TICK_DIV):0] - 1'd1) begin
		tick_div <= 0;
		tick_1k  <= 1;
	end else begin
		tick_div <= tick_div + 1'd1;
	end
end

// FIX: Widened wind_div to dynamically fit WIND_TICKS values
reg [$clog2(WIND_TICKS):0] wind_div  = 0;

always @(posedge clk) begin
	wind_step <= 0;
	if (!winding) begin
		wind_div <= 0;
	end else if (tick_1k) begin
		if (wind_div >= WIND_TICKS[$clog2(WIND_TICKS):0] - 1'd1) begin
			wind_div  <= 0;
			wind_step <= 1;
		end else begin
			wind_div <= wind_div + 1'd1;
		end
	end
end

// ---------------------------------------------------------------------------
// Transport state (combinational)
// ---------------------------------------------------------------------------
wire at_end  = tape_loaded & (tap_play_addr >= tap_last_addr);
wire winding = tape_loaded & (ff | rew); // allow REW even after end-of-tape
wire playing = tape_loaded & ~at_end & ~cass_run & ~cass_sense & ~winding;
wire paused  = tape_loaded & ~at_end & cass_run & ~cass_sense & ~winding;
// ---------------------------------------------------------------------------
// Physical counter model: accumulating time vs. growing reel radius
// ---------------------------------------------------------------------------
reg [15:0] pos_acc   = 0;
reg [15:0] threshold = THRESH_BASE[15:0];
reg [3:0]  d_ones    = 0;
reg [3:0]  d_tens    = 0;
reg [3:0]  d_huns    = 0;

reg counter_reset_d = 0;
wire counter_reset_edge = counter_reset & ~counter_reset_d;

always @(posedge clk) begin
	counter_reset_d <= counter_reset;

	if (new_tape || !tape_loaded) begin
		pos_acc     <= 0;
		abs_count   <= 0;
		threshold   <= THRESH_BASE[15:0];
		d_ones      <= 0;
		d_tens      <= 0;
		d_huns      <= 0;
	end else begin
		if (counter_reset_edge) begin
			// Mechanical reset only clears the digits; absolute position is kept.
			d_ones <= 0;
			d_tens <= 0;
			d_huns <= 0;
		end

		if (tick_1k && playing && !winding) begin
			if (pos_acc + 1'd1 >= threshold) begin
				pos_acc <= (pos_acc + 1'd1) - threshold;
				if (abs_count < ABS_MAX[12:0]) begin
					abs_count <= abs_count + 1'd1;
					threshold <= threshold + THRESH_INC[15:0];
				end
				if (!counter_reset_edge) begin
					{d_huns, d_tens, d_ones} <= bcd_inc({d_huns, d_tens, d_ones});
				end
			end else begin
				pos_acc <= pos_acc + 1'd1;
			end
		end

		if (wind_step && !counter_reset_edge) begin
			pos_acc <= 0;
			if (ff && abs_count < ABS_MAX[12:0]) begin
				abs_count <= abs_count + 1'd1;
				threshold <= threshold + THRESH_INC[15:0];
				{d_huns, d_tens, d_ones} <= bcd_inc({d_huns, d_tens, d_ones});
			end else if (rew && abs_count != 0) begin
				abs_count <= abs_count - 1'd1;
				threshold <= (threshold >= THRESH_BASE[15:0] + THRESH_INC[15:0])
								 ? threshold - THRESH_INC[15:0]
								 : THRESH_BASE[15:0];
				{d_huns, d_tens, d_ones} <= bcd_dec({d_huns, d_tens, d_ones});
			end
		end
	end
end

// ===========================================================================
// Rendering overlay
// ===========================================================================
localparam bit [9:0] TC_W = 10'd30; // 5 cells * 6 px
localparam bit [9:0] TC_H = 10'd5;  // 5 lines of char

wire [9:0] base_x = ntsc ? POS_X_NTSC[9:0] : POS_X_PAL[9:0];
wire [9:0] base_y = ntsc ? POS_Y_NTSC[9:0] : POS_Y_PAL[9:0];

reg [9:0] x_pos = 0;
reg [9:0] y_pos = 0;
reg       old_hblank = 0;

always @(posedge clk) begin
	if (hblank) x_pos <= 0;
	else if (ce) x_pos <= x_pos + 1'd1;

	if (ce) old_hblank <= hblank;

	if (vblank) y_pos <= 0;
	else if (ce) begin
		if (old_hblank && !hblank) y_pos <= y_pos + 1'd1;
	end
end

wire tc_visible = enable && tape_loaded;
wire tc_area = tc_visible &&
               (x_pos >= base_x) && (x_pos < base_x + TC_W) &&
               (y_pos >= base_y) && (y_pos < base_y + TC_H);

reg [2:0] tc_col_r = 0;
reg [2:0] tc_px_r  = 0;
reg [2:0] tc_py_r  = 0;

always @(posedge clk) if (ce) begin
	// tc_col_r / tc_px_r: aggiornati ogni pixel nella zona overlay
	if (hblank) begin
		tc_col_r <= 0;
		tc_px_r  <= 0;
	end else if (x_pos == base_x - 10'd1) begin
		tc_col_r <= 0;
		tc_px_r  <= 0;
	end else if (tc_area) begin
		if (tc_px_r == 3'd5) begin
			tc_px_r  <= 0;
			tc_col_r <= tc_col_r + 1'd1;
		end else begin
			tc_px_r  <= tc_px_r + 1'd1;
		end
	end
end

// FIX: Uncouple vblank coordinate resets from ce to guarantee clean sweeps under all conditions
always @(posedge clk) begin
	if (vblank) begin
		tc_py_r <= 0;
	end else if (ce) begin
		if (old_hblank && !hblank) begin
			if (y_pos == base_y - 10'd1) begin
				tc_py_r <= 0;
			end else if (y_pos >= base_y && y_pos < base_y + TC_H) begin
				if (tc_py_r == 3'd5) tc_py_r <= 0;
				else                 tc_py_r <= tc_py_r + 1'd1;
			end else begin
				tc_py_r <= 0;
			end
		end
	end
end

// Character selection: transport-state glyph in col 0, then hundreds/tens/ones.
reg [4:0] tc_state_char;
always @(*) begin
	if (ff)             tc_state_char = 15; // FFWD
	else if (rew)       tc_state_char = 14; // REW
	else if (playing)   tc_state_char = 13; // PLAY
	else if (paused)    tc_state_char = 12; // PAUSE
	else                tc_state_char = 11; // STOP
end

reg [6:0] tc_char;
always @(*) begin
	case (tc_col_r)
		3'd0: tc_char = tc_state_char;
		3'd1: tc_char = 10;         // blank space
		3'd2: tc_char = d_huns;     // hundreds
		3'd3: tc_char = d_tens;     // tens
		3'd4: tc_char = d_ones;     // ones
		default: tc_char = 10;      // blank
	endcase
end

wire valid_tc_pixel = tc_area && (tc_px_r < 5) && (tc_py_r < 5);

// ---------------------------------------------------------------------------
// Font ROM
// ---------------------------------------------------------------------------

wire [4:0] font[16*5] = '{
	5'b01110, 5'b10001, 5'b10001, 5'b10001, 5'b01110,
	5'b00100, 5'b01100, 5'b00100, 5'b00100, 5'b01110,
	5'b01110, 5'b10001, 5'b00110, 5'b01000, 5'b11111,
	5'b11110, 5'b00001, 5'b01110, 5'b00001, 5'b11110,
	5'b10001, 5'b10001, 5'b11111, 5'b00001, 5'b00001,
	5'b11111, 5'b10000, 5'b11110, 5'b00001, 5'b11110,
	5'b01110, 5'b10000, 5'b11110, 5'b10001, 5'b01110,
	5'b11111, 5'b00001, 5'b00010, 5'b00100, 5'b00100,
	5'b01110, 5'b10001, 5'b01110, 5'b10001, 5'b01110,
	5'b01110, 5'b10001, 5'b01111, 5'b00001, 5'b01110,

	5'b00000, 5'b00000, 5'b00000, 5'b00000, 5'b00000,

	5'b11111, 5'b11111, 5'b11111, 5'b11111, 5'b11111, // STOP
	5'b11011, 5'b11011, 5'b11011, 5'b11011, 5'b11011, // PAUSE
	5'b10000, 5'b11000, 5'b11100, 5'b11000, 5'b10000, // PLAY
	5'b00101, 5'b01101, 5'b11111, 5'b01101, 5'b00101, // REW
	5'b10100, 5'b10110, 5'b11111, 5'b10110, 5'b10100  // FF
};

reg [6:0] font_addr;

// ---------------------------------------------------------------------------
// Pipeline stage 1: latch cell coordinates and state
// ---------------------------------------------------------------------------
reg [2:0] px_s1, py_s1;
reg       valid_s1;
reg [2:0] color_s1;

always @(posedge clk) if (ce) begin
	font_addr  <= (tc_char<<2) + tc_char + py_s1;
	px_s1      <= tc_px_r;
	py_s1      <= tc_py_r;
	valid_s1   <= valid_tc_pixel;
	color_s1   <= (ff || rew) ? C_BLUE   :
					  playing     ? C_GREEN  :
					  paused      ? C_YELLOW : C_RED;
end

// ---------------------------------------------------------------------------
// Pipeline stage 2: font lookup
// ---------------------------------------------------------------------------
reg [4:0] font_row_s2;
reg [2:0] px_s2;
reg       valid_s2;
reg [2:0] color_s2;

always @(posedge clk) if (ce) font_row_s2 <= font[font_addr];

always @(posedge clk) if (ce) begin
	px_s2       <= px_s1;
	valid_s2    <= valid_s1;
	color_s2    <= color_s1;
end

// ---------------------------------------------------------------------------
// Pipeline stage 3: pixel shift and color
// ---------------------------------------------------------------------------
wire [2:0] px_rev   = (px_s2 < 5) ? 3'd4 - px_s2 : 3'd0;
wire       pixel_on = (px_s2 < 5) && font_row_s2[px_rev];

always @(posedge clk) if (ce) pixel_color <= (valid_s2 && pixel_on) ? color_s2 : C_TRANSPARENT;

endmodule
