// Project F: FPGA Ad Astra - Top Greetings (spartanEdgeAccelerator with HDMI)
// (C)2020 Will Green, open source hardware released under the MIT License
// Learn more at https://projectf.io

`default_nettype none
`timescale 1ns / 1ps

module top_greet (
    input  wire logic clk100MHZ,   // 100 MHz clock
    input  wire logic rstn_i,      // reset button (active low)
    output      logic [2:0] TMDS_0_data_p,
    output      logic [2:0] TMDS_0_data_n,
    output      logic TMDS_0_clk_p,
    output      logic TMDS_0_clk_n
    );

    logic lcd_den;
    logic lcd_hsync;    // horizontal sync
    logic lcd_vsync;    // vertical sync

    // generate pixel clock
    logic clk_pix;
    logic clk_dvi;
    logic clk_locked;
    clock_gen clock_1280x720 (
       .clk(clk100MHZ),
       .rst(!rstn_i),  // reset button is active low
       .clk_pix,
       .clk_dvi,
       .clk_locked
    );

    // display timings
    localparam CORDW = 12;  // screen coordinate width in bits
    logic [CORDW-1:0] sx, sy;
    display_timings #(.CORDW(CORDW),
        .HACTIVE(1280), .HFP(72), .HSYNC(80), .HBP(216),
        .VACTIVE(720), .VFP(3), .VSYNC(5), .VBP(22)
    ) timings_1280x720 (
        .clk_pix,
        .rst(!clk_locked),  // wait for clock lock
        .sx,
        .sy,
        .hsync(lcd_hsync),
        .vsync(lcd_vsync),
        .de(lcd_den)
    );

    // greeting selector
    localparam MSG_CHG = 80; // change message every N frames
    logic [7:0] cnt_frm;     // 7-bit frame counter
    logic [4:0] greet_line;  // 32 greeting line pairs
    always_ff @(posedge clk_pix) begin
        if (sy == 720 && sx == 1280) begin  // start of blanking
            cnt_frm <= cnt_frm + 1;
            if (cnt_frm == MSG_CHG) begin
                greet_line <= greet_line + 1;
                cnt_frm <= 0;
            end
        end
    end

    // greetings
    localparam GREET_WIDTH = 6;  // 6-bit code points (U+0020 - U+005F)
    localparam GREET_DEPTH = 32 * 16;  // 32 messages of 16 chars each
    localparam GREET_ADDRW = $clog2(GREET_DEPTH);
    localparam GREET_INIT_F = "../greets.mem";

    logic [GREET_ADDRW-1:0] greet_addr;
    logic [GREET_WIDTH-1:0] greet_cp;  // char code point

    bram #(  // greetings ROM
        .INIT_F(GREET_INIT_F),
        .WIDTH(GREET_WIDTH),
        .DEPTH(GREET_DEPTH)
    ) greet_rom (
        .clk(clk_pix),
        .addr(greet_addr),
        .we(1'b0),
        .data_in(),
        .data(greet_cp)
    );

    // font ROM
    localparam FONT_WIDTH  = 8;  // width in pixels
    localparam FONT_HEIGHT = 8;  // number of lines
    localparam FONT_DEPTH  = 64 * FONT_HEIGHT;    // 64 chars
    localparam FONT_ADDRW  = $clog2(FONT_DEPTH);  // font ROM address width
    localparam FONT_INIT_F = "../font_unscii_8x8_latin_uc.mem";

    logic [FONT_ADDRW-1:0] font_addr;
    logic [FONT_WIDTH-1:0] font_data;

    bram #(
        .INIT_F(FONT_INIT_F),
        .WIDTH(FONT_WIDTH),
        .DEPTH(FONT_DEPTH)
    ) font_rom (
        .clk(clk_pix),
        .addr(font_addr),
        .we(1'b0),
        .data_in(),
        .data(font_data)
    );

    // sprites - drawn position is one pixel left and down from sprite coordinate
    localparam LINE2 = 240;      // where to start second line of sprites
    localparam SPR_SCALE_X = 8;  // enlarge sprite width by this factor
    localparam SPR_SCALE_Y = 8;  // enlarge sprite height by this factor

    logic [FONT_ADDRW-1:0] spr0_gfx_addr, spr1_gfx_addr, spr2_gfx_addr,
        spr3_gfx_addr, spr4_gfx_addr, spr5_gfx_addr, spr6_gfx_addr, spr7_gfx_addr;
    logic [FONT_ADDRW-1:0] spr0_gfx_line_addr, spr1_gfx_line_addr, spr2_gfx_line_addr,
        spr3_gfx_line_addr, spr4_gfx_line_addr, spr5_gfx_line_addr, spr6_gfx_line_addr, spr7_gfx_line_addr;
    logic [GREET_ADDRW-1:0] spr0_cp_addr, spr1_cp_addr, spr2_cp_addr,
        spr3_cp_addr, spr4_cp_addr, spr5_cp_addr, spr6_cp_addr, spr7_cp_addr;
    logic [GREET_WIDTH-1:0] spr0_cp, spr1_cp, spr2_cp, spr3_cp,
                            spr4_cp, spr5_cp, spr6_cp, spr7_cp;

    logic spr0_gdma, spr0_cp_ready, spr0_fdma, spr0_pix, spr0_done;
    logic spr1_gdma, spr1_cp_ready, spr1_fdma, spr1_pix, spr1_done;
    logic spr2_gdma, spr2_cp_ready, spr2_fdma, spr2_pix, spr2_done;
    logic spr3_gdma, spr3_cp_ready, spr3_fdma, spr3_pix, spr3_done;
    logic spr4_gdma, spr4_cp_ready, spr4_fdma, spr4_pix, spr4_done;
    logic spr5_gdma, spr5_cp_ready, spr5_fdma, spr5_pix, spr5_done;
    logic spr6_gdma, spr6_cp_ready, spr6_fdma, spr6_pix, spr6_done;
    logic spr7_gdma, spr7_cp_ready, spr7_fdma, spr7_pix, spr7_done;

    // choose characters to display
    logic [GREET_ADDRW-1:0] msg_start;
    always_comb begin
        // subtract 0x20 from code points as font starts at U+0020
        spr0_gfx_addr = (spr0_cp - 'h20) * FONT_HEIGHT;
        spr1_gfx_addr = (spr1_cp - 'h20) * FONT_HEIGHT;
        spr2_gfx_addr = (spr2_cp - 'h20) * FONT_HEIGHT;
        spr3_gfx_addr = (spr3_cp - 'h20) * FONT_HEIGHT;
        spr4_gfx_addr = (spr4_cp - 'h20) * FONT_HEIGHT;
        spr5_gfx_addr = (spr5_cp - 'h20) * FONT_HEIGHT;
        spr6_gfx_addr = (spr6_cp - 'h20) * FONT_HEIGHT;
        spr7_gfx_addr = (spr7_cp - 'h20) * FONT_HEIGHT;

        msg_start = 'h10 * greet_line;    // 16 chars per greeting
        spr0_cp_addr = (sy < LINE2) ? (msg_start+'h0) : (msg_start+'h8);
        spr1_cp_addr = (sy < LINE2) ? (msg_start+'h1) : (msg_start+'h9);
        spr2_cp_addr = (sy < LINE2) ? (msg_start+'h2) : (msg_start+'hA);
        spr3_cp_addr = (sy < LINE2) ? (msg_start+'h3) : (msg_start+'hB);
        spr4_cp_addr = (sy < LINE2) ? (msg_start+'h4) : (msg_start+'hC);
        spr5_cp_addr = (sy < LINE2) ? (msg_start+'h5) : (msg_start+'hD);
        spr6_cp_addr = (sy < LINE2) ? (msg_start+'h6) : (msg_start+'hE);
        spr7_cp_addr = (sy < LINE2) ? (msg_start+'h7) : (msg_start+'hF);
    end

    always_ff @(posedge clk_pix) begin
        if (spr0_cp_ready) spr0_cp <= greet_cp;
        if (spr1_cp_ready) spr1_cp <= greet_cp;
        if (spr2_cp_ready) spr2_cp <= greet_cp;
        if (spr3_cp_ready) spr3_cp <= greet_cp;
        if (spr4_cp_ready) spr4_cp <= greet_cp;
        if (spr5_cp_ready) spr5_cp <= greet_cp;
        if (spr6_cp_ready) spr6_cp <= greet_cp;
        if (spr7_cp_ready) spr7_cp <= greet_cp;
    end

    logic spr_start;
    localparam SCREEN_ACTIVE = 1280;
    always_comb begin
        spr_start = (sy < LINE2) ? (sy == 150 && sx == 0) : (sy == 250 && sx == 0);

        // greetings char DMA slots
        spr0_gdma = (sx >= SCREEN_ACTIVE +  0 && sx < SCREEN_ACTIVE +  2);  // 2 clock cycles
        spr1_gdma = (sx >= SCREEN_ACTIVE +  2 && sx < SCREEN_ACTIVE +  4);
        spr2_gdma = (sx >= SCREEN_ACTIVE +  4 && sx < SCREEN_ACTIVE +  6);
        spr3_gdma = (sx >= SCREEN_ACTIVE +  6 && sx < SCREEN_ACTIVE +  8);
        spr4_gdma = (sx >= SCREEN_ACTIVE +  8 && sx < SCREEN_ACTIVE + 10);
        spr5_gdma = (sx >= SCREEN_ACTIVE + 10 && sx < SCREEN_ACTIVE + 12);
        spr6_gdma = (sx >= SCREEN_ACTIVE + 12 && sx < SCREEN_ACTIVE + 14);
        spr7_gdma = (sx >= SCREEN_ACTIVE + 14 && sx < SCREEN_ACTIVE + 16);

        // allow one cycle for code point to be ready
        spr0_cp_ready = (sx == SCREEN_ACTIVE +  1);
        spr1_cp_ready = (sx == SCREEN_ACTIVE +  3);
        spr2_cp_ready = (sx == SCREEN_ACTIVE +  5);
        spr3_cp_ready = (sx == SCREEN_ACTIVE +  7);
        spr4_cp_ready = (sx == SCREEN_ACTIVE +  9);
        spr5_cp_ready = (sx == SCREEN_ACTIVE + 11);
        spr6_cp_ready = (sx == SCREEN_ACTIVE + 13);
        spr7_cp_ready = (sx == SCREEN_ACTIVE + 15);

        // font glyph DMA slots after code point stored
        spr0_fdma = (sx >= SCREEN_ACTIVE +  2 && sx < SCREEN_ACTIVE +  4);  // 2 clock cycles
        spr1_fdma = (sx >= SCREEN_ACTIVE +  4 && sx < SCREEN_ACTIVE +  6);
        spr2_fdma = (sx >= SCREEN_ACTIVE +  6 && sx < SCREEN_ACTIVE +  8);
        spr3_fdma = (sx >= SCREEN_ACTIVE +  8 && sx < SCREEN_ACTIVE + 10);
        spr4_fdma = (sx >= SCREEN_ACTIVE + 10 && sx < SCREEN_ACTIVE + 12);
        spr5_fdma = (sx >= SCREEN_ACTIVE + 12 && sx < SCREEN_ACTIVE + 14);
        spr6_fdma = (sx >= SCREEN_ACTIVE + 14 && sx < SCREEN_ACTIVE + 16);
        spr7_fdma = (sx >= SCREEN_ACTIVE + 16 && sx < SCREEN_ACTIVE + 18);

        greet_addr = 0;
        if (spr0_gdma) greet_addr = spr0_cp_addr;
        if (spr1_gdma) greet_addr = spr1_cp_addr;
        if (spr2_gdma) greet_addr = spr2_cp_addr;
        if (spr3_gdma) greet_addr = spr3_cp_addr;
        if (spr4_gdma) greet_addr = spr4_cp_addr;
        if (spr5_gdma) greet_addr = spr5_cp_addr;
        if (spr6_gdma) greet_addr = spr6_cp_addr;
        if (spr7_gdma) greet_addr = spr7_cp_addr;

        font_addr = 0;
        if (spr0_fdma) font_addr = spr0_gfx_line_addr;
        if (spr1_fdma) font_addr = spr1_gfx_line_addr;
        if (spr2_fdma) font_addr = spr2_gfx_line_addr;
        if (spr3_fdma) font_addr = spr3_gfx_line_addr;
        if (spr4_fdma) font_addr = spr4_gfx_line_addr;
        if (spr5_fdma) font_addr = spr5_gfx_line_addr;
        if (spr6_fdma) font_addr = spr6_gfx_line_addr;
        if (spr7_fdma) font_addr = spr7_gfx_line_addr;
    end

    localparam START_SPRITE_X = 416;
    sprite #(
        .LSB(0),
        .WIDTH(FONT_WIDTH),
        .HEIGHT(FONT_HEIGHT),
        .SCALE_X(SPR_SCALE_X),
        .SCALE_Y(SPR_SCALE_Y),
        .ADDRW(FONT_ADDRW),
        .CORDW(CORDW)
        ) spr0 (
        .clk(clk_pix),
        .rst(!clk_locked),
        .start(spr_start),
        .dma_avail(spr0_fdma),
        .sx,
        .sprx(START_SPRITE_X),
        .gfx_data(font_data),
        .gfx_addr_base(spr0_gfx_addr),
        .gfx_addr(spr0_gfx_line_addr),
        .pix(spr0_pix),
        .done(spr0_done)
    );

    sprite #(
        .LSB(0),
        .WIDTH(FONT_WIDTH),
        .HEIGHT(FONT_HEIGHT),
        .SCALE_X(SPR_SCALE_X),
        .SCALE_Y(SPR_SCALE_Y),
        .ADDRW(FONT_ADDRW),
        .CORDW(CORDW)
        ) spr1 (
        .clk(clk_pix),
        .rst(!clk_locked),
        .start(spr_start),
        .dma_avail(spr1_fdma),
        .sx,
        .sprx(START_SPRITE_X + 64),
        .gfx_data(font_data),
        .gfx_addr_base(spr1_gfx_addr),
        .gfx_addr(spr1_gfx_line_addr),
        .pix(spr1_pix),
        .done(spr1_done)
    );

    sprite #(
        .LSB(0),
        .WIDTH(FONT_WIDTH),
        .HEIGHT(FONT_HEIGHT),
        .SCALE_X(SPR_SCALE_X),
        .SCALE_Y(SPR_SCALE_Y),
        .ADDRW(FONT_ADDRW),
        .CORDW(CORDW)
        ) spr2 (
        .clk(clk_pix),
        .rst(!clk_locked),
        .start(spr_start),
        .dma_avail(spr2_fdma),
        .sx,
        .sprx(START_SPRITE_X + (2 * 64)),
        .gfx_data(font_data),
        .gfx_addr_base(spr2_gfx_addr),
        .gfx_addr(spr2_gfx_line_addr),
        .pix(spr2_pix),
        .done(spr2_done)
    );

    sprite #(
        .LSB(0),
        .WIDTH(FONT_WIDTH),
        .HEIGHT(FONT_HEIGHT),
        .SCALE_X(SPR_SCALE_X),
        .SCALE_Y(SPR_SCALE_Y),
        .ADDRW(FONT_ADDRW),
        .CORDW(CORDW)
        ) spr3 (
        .clk(clk_pix),
        .rst(!clk_locked),
        .start(spr_start),
        .dma_avail(spr3_fdma),
        .sx,
        .sprx(START_SPRITE_X + (3 * 64)),
        .gfx_data(font_data),
        .gfx_addr_base(spr3_gfx_addr),
        .gfx_addr(spr3_gfx_line_addr),
        .pix(spr3_pix),
        .done(spr3_done)
    );

    sprite #(
        .LSB(0),
        .WIDTH(FONT_WIDTH),
        .HEIGHT(FONT_HEIGHT),
        .SCALE_X(SPR_SCALE_X),
        .SCALE_Y(SPR_SCALE_Y),
        .ADDRW(FONT_ADDRW),
        .CORDW(CORDW)
        ) spr4 (
        .clk(clk_pix),
        .rst(!clk_locked),
        .start(spr_start),
        .dma_avail(spr4_fdma),
        .sx,
        .sprx(START_SPRITE_X + (4 * 64)),
        .gfx_data(font_data),
        .gfx_addr_base(spr4_gfx_addr),
        .gfx_addr(spr4_gfx_line_addr),
        .pix(spr4_pix),
        .done(spr4_done)
    );

    sprite #(
        .LSB(0),
        .WIDTH(FONT_WIDTH),
        .HEIGHT(FONT_HEIGHT),
        .SCALE_X(SPR_SCALE_X),
        .SCALE_Y(SPR_SCALE_Y),
        .ADDRW(FONT_ADDRW),
        .CORDW(CORDW)
        ) spr5 (
        .clk(clk_pix),
        .rst(!clk_locked),
        .start(spr_start),
        .dma_avail(spr5_fdma),
        .sx,
        .sprx(START_SPRITE_X + (5 * 64)),
        .gfx_data(font_data),
        .gfx_addr_base(spr5_gfx_addr),
        .gfx_addr(spr5_gfx_line_addr),
        .pix(spr5_pix),
        .done(spr5_done)
    );

    sprite #(
        .LSB(0),
        .WIDTH(FONT_WIDTH),
        .HEIGHT(FONT_HEIGHT),
        .SCALE_X(SPR_SCALE_X),
        .SCALE_Y(SPR_SCALE_Y),
        .ADDRW(FONT_ADDRW),
        .CORDW(CORDW)
        ) spr6 (
        .clk(clk_pix),
        .rst(!clk_locked),
        .start(spr_start),
        .dma_avail(spr6_fdma),
        .sx,
        .sprx(START_SPRITE_X + (6 * 64)),
        .gfx_data(font_data),
        .gfx_addr_base(spr6_gfx_addr),
        .gfx_addr(spr6_gfx_line_addr),
        .pix(spr6_pix),
        .done(spr6_done)
    );

    sprite #(
        .LSB(0),
        .WIDTH(FONT_WIDTH),
        .HEIGHT(FONT_HEIGHT),
        .SCALE_X(SPR_SCALE_X),
        .SCALE_Y(SPR_SCALE_Y),
        .ADDRW(FONT_ADDRW),
        .CORDW(CORDW)
        ) spr7 (
        .clk(clk_pix),
        .rst(!clk_locked),
        .start(spr_start),
        .dma_avail(spr7_fdma),
        .sx,
        .sprx(START_SPRITE_X + (7 * 64)),
        .gfx_data(font_data),
        .gfx_addr_base(spr7_gfx_addr),
        .gfx_addr(spr7_gfx_line_addr),
        .pix(spr7_pix),
        .done(spr7_done)
    );

    // font colours
    localparam COLR_A   = 12'h125; // initial colour A
    localparam COLR_B   = 12'h421; // initial colour B
    localparam SLIN_1A  = 12'd151; // 1st line of colour A
    localparam SLIN_1B  = 12'd179; // 1st line of colour B
    localparam SLIN_2A  = 12'd251; // 2nd line of colour A
    localparam SLIN_2B  = 12'd279; // 2nd line of colour B
    localparam LINE_INC = 3;       // lines of each colour

    logic [11:0] font_colr;  // 12 bit colour (4-bit per channel)
    logic [$clog2(LINE_INC)-1:0] cnt_line;
    always_ff @(posedge clk_pix) begin
        if ((sy == SLIN_1A || sy == SLIN_2A) && sx == 0) begin
            cnt_line <= 0;
            font_colr <= COLR_A;
        end else if ((sy == SLIN_1B || sy == SLIN_2B) && sx == 0) begin
            cnt_line <= 0;
            font_colr <= COLR_B;
        end else if (sx == 0) begin
            cnt_line <= cnt_line + 1;
            if (cnt_line == LINE_INC-1) begin
                cnt_line <= 0;
                font_colr <= font_colr + 12'h111;
            end
        end
    end

    localparam VSIZE = 750;
    localparam HSIZE = 1648;

    // starfields
    logic sf1_on, sf2_on, sf3_on;
    logic [7:0] sf1_star, sf2_star, sf3_star;

    starfield #(.H(HSIZE), .V(VSIZE), .INC(-1), .SEED(21'h9A9A9)) sf1 (
        .clk(clk_pix),
        .en(1'b1),
        .rst(!clk_locked),
        .sf_on(sf1_on),
        .sf_star(sf1_star)
    );

    starfield #(.H(HSIZE), .V(VSIZE), .INC(-2), .SEED(21'hA9A9A)) sf2 (
        .clk(clk_pix),
        .en(1'b1),
        .rst(!clk_locked),
        .sf_on(sf2_on),
        .sf_star(sf2_star)
    );

    starfield #(.H(HSIZE), .V(VSIZE), .INC(-4), .MASK(21'h7FF)) sf3 (
        .clk(clk_pix),
        .en(1'b1),
        .rst(!clk_locked),
        .sf_on(sf3_on),
        .sf_star(sf3_star)
    );

    logic spr_on;
    logic [7:0] red_spr, green_spr, blue_spr;
    logic [3:0] red_star, green_star, blue_star;
    always_comb begin
        spr_on = spr0_pix | spr1_pix | spr2_pix | spr3_pix |
                 spr4_pix | spr5_pix | spr6_pix | spr7_pix;
        red_spr    = (spr_on) ? {font_colr[11:8], 4'hf} : 8'h0;
        green_spr  = (spr_on) ? {font_colr[7:4], 4'hf} : 8'h0;
        blue_spr   = (spr_on) ? {font_colr[3:0], 4'hf} : 8'h0;
        red_star   = (sf1_on) ? sf1_star[7:4] : (sf2_on) ?
                      sf2_star[7:4] : (sf3_on) ? sf3_star[7:4] : 4'h0;
        green_star = (sf1_on) ? sf1_star[7:4] : (sf2_on) ?
                      sf2_star[7:4] : (sf3_on) ? sf3_star[7:4] : 4'h0;
        blue_star  = (sf1_on) ? sf1_star[7:4] : (sf2_on) ?
                      sf2_star[7:4] : (sf3_on) ? sf3_star[7:4] : 4'h0;
    end

    // LCD output
    logic [7:0] lcd_r, lcd_g, lcd_b;

    always_comb begin
        lcd_r = (lcd_den) ? (spr_on) ? red_spr   : {red_star, 4'hf}   : 8'h0;
        lcd_g = (lcd_den) ? (spr_on) ? green_spr : {green_star, 4'hf} : 8'h0;
        lcd_b = (lcd_den) ? (spr_on) ? blue_spr  : {blue_star, 4'hf}  : 8'h0;
    end

	dvi dvi_inst (.clk_pix, .clk_dvi, .rst(!clk_locked),
		.de(lcd_den), .hsync(lcd_hsync), .vsync(lcd_vsync),
		.pix_r(lcd_r), .pix_g(lcd_g), .pix_b(lcd_b),
		.TMDS_0_clk_p, .TMDS_0_clk_n, .TMDS_0_data_p, .TMDS_0_data_n
	);

endmodule
