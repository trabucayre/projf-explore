// Project F: FPGA Ad Astra - Top LFSR (spartanEdgeAccelerator with HDMI)
// (C)2020 Will Green, open source hardware released under the MIT License
// Learn more at https://projectf.io

`default_nettype none
`timescale 1ns / 1ps

module top_lfsr (
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

    logic sf_area;
    always_comb sf_area = (sx < 512 && sy < 256);

    // 17-bit LFSR
    logic [16:0] sf_reg;
    lfsr #(
        .LEN(17),
        .TAPS(17'b10010000000000000)
    ) lsfr_sf (
        .clk(clk_pix),
        .rst(!clk_locked),
        .en(sf_area && lcd_den),
        .sreg(sf_reg)
    );

    // VGA output
    logic star;
    // LCD output
    logic [7:0] lcd_r, lcd_g, lcd_b;

    always_comb begin
        star = &{sf_reg[16:9]};  // (~512 stars for 8 bits with 512x256)
        lcd_r = (lcd_den && sf_area && star) ? {sf_reg[3:0], 4'hf} : 8'h0;
        lcd_g = (lcd_den && sf_area && star) ? {sf_reg[3:0], 4'hf} : 8'h0;
        lcd_b = (lcd_den && sf_area && star) ? {sf_reg[3:0], 4'hf} : 8'h0;
    end

	dvi dvi_inst (.clk_pix, .clk_dvi, .rst(!clk_locked),
		.de(lcd_den), .hsync(lcd_hsync), .vsync(lcd_vsync),
		.pix_r(lcd_r), .pix_g(lcd_g), .pix_b(lcd_b),
		.TMDS_0_clk_p, .TMDS_0_clk_n, .TMDS_0_data_p, .TMDS_0_data_n
	);

endmodule
