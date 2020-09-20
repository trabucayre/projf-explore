// (C)2019 Gwenhael Goavec-Merou, open source hardware released under the MIT License

module dvi (
	input        clk_pix,
	input        clk_dvi,
	input        rst,
	input        de,
	input        hsync,
	input        vsync,
	input  [7:0] pix_r,
	input  [7:0] pix_g,
	input  [7:0] pix_b,
	output       TMDS_0_clk_p,
	output       TMDS_0_clk_n,
	output [2:0] TMDS_0_data_p,
	output [2:0] TMDS_0_data_n
);
	wire [9:0] red2_s, green2_s, blue2_s;

	TMDS_encoder encod_red (
		.clk_i(clk_pix), .de(de),
		.data_i(pix_r), .c0_i(1'b0), .c1_i(1'b0), .data_o(red2_s));
	TMDS_encoder encod_green (
		.clk_i(clk_pix), .de(de),
		.data_i(pix_g), .c0_i(1'b0), .c1_i(1'b0), .data_o(green2_s));
	TMDS_encoder encod_blue (
		.clk_i(clk_pix), .de(de),
		.data_i(pix_b), .c0_i(hsync), .c1_i(vsync), .data_o(blue2_s));
	
	wire [2:0] TMDS_0_data;
	wire       TMDS_clk_s;
	
	serializer serClk(.sl_clk_i(clk_pix), .fast_clk_i(clk_dvi), .rst(rst),
		.dat_i(10'b0000011111), .dat_o(TMDS_clk_s));
	OBUFDS #(.IOSTANDARD("TMDS_33"))
		clkdiff_inst (.O(TMDS_0_clk_p), .OB(TMDS_0_clk_n), .I(TMDS_clk_s));
	serializer serBlue(.sl_clk_i(clk_pix), .fast_clk_i(clk_dvi), .rst(rst),
		.dat_i(blue2_s), .dat_o(TMDS_0_data[0]));
	OBUFDS #(.IOSTANDARD("TMDS_33"))
		bdiff_inst (.O(TMDS_0_data_p[0]), .OB(TMDS_0_data_n[0]), .I(TMDS_0_data[0]));
	serializer serGreen(.sl_clk_i(clk_pix), .fast_clk_i(clk_dvi), .rst(rst),
		.dat_i(green2_s), .dat_o(TMDS_0_data[1]));
	OBUFDS #(.IOSTANDARD("TMDS_33"))
		gdiff_inst (.O(TMDS_0_data_p[1]), .OB(TMDS_0_data_n[1]), .I(TMDS_0_data[1]));
	serializer serRed(.sl_clk_i(clk_pix), .fast_clk_i(clk_dvi), .rst(rst),
		.dat_i(red2_s), .dat_o(TMDS_0_data[2]));
	OBUFDS #(.IOSTANDARD("TMDS_33"))
		rdiff_inst (.O(TMDS_0_data_p[2]), .OB(TMDS_0_data_n[2]), .I(TMDS_0_data[2]));
endmodule
