// Project F: FPGA Ad Astra - Top Starfields (spartanEdgeAccelerator with HDMI)
// (C)2020 Will Green, open source hardware released under the MIT License
// Learn more at https://projectf.io

`default_nettype none
`timescale 1ns / 1ps

module top_starfields (
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

    // LCD output
	logic [7:0] lcd_r, lcd_g, lcd_b;
    // colour channels
    logic [3:0] red, green, blue;
    always_comb begin
        red   = (sf1_on) ? sf1_star[7:4] : (sf2_on) ?
                sf2_star[7:4] : (sf3_on) ? sf3_star[7:4] : 4'h0;
        green = (sf1_on) ? sf1_star[7:4] : (sf2_on) ?
                sf2_star[7:4] : (sf3_on) ? sf3_star[7:4] : 4'h0;
        blue  = (sf1_on) ? sf1_star[7:4] : (sf2_on) ?
                sf2_star[7:4] : (sf3_on) ? sf3_star[7:4] : 4'h0;
    end

    // LCD output
    logic [7:0] lcd_r, lcd_g, lcd_b;

    always_comb begin
        lcd_r = (lcd_den) ? {red, 4'hf}   : 8'h0;
        lcd_g = (lcd_den) ? {green, 4'hf} : 8'h0;
        lcd_b = (lcd_den) ? {blue, 4'hf}  : 8'h0;
    end

	dvi dvi_inst (.clk_pix, .clk_dvi, .rst(!clk_locked),
		.de(lcd_den), .hsync(lcd_hsync), .vsync(lcd_vsync),
		.pix_r(lcd_r), .pix_g(lcd_g), .pix_b(lcd_b),
		.TMDS_0_clk_p, .TMDS_0_clk_n, .TMDS_0_data_p, .TMDS_0_data_n
	);

endmodule
