// (C)2019 Gwenhael Goavec-Merou, open source hardware released under the MIT License

module serializer (
	input wire sl_clk_i,
	input wire fast_clk_i,
	input wire rst,
	// data in
	input wire [9:0] dat_i,
	// data out
	output wire dat_o
);

wire casc1, casc2;

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("SDR"),
	.DATA_WIDTH(10),
	.INIT_OQ(1), .INIT_TQ(1),
	.SERDES_MODE("MASTER"),
	.SRVAL_OQ(0), .SRVAL_TQ(0),
	.TBYTE_CTL("FALSE"),
	.TBYTE_SRC("FALSE"),
	.TRISTATE_WIDTH(1)
) mserdes_inst (
	.OFB(),                // 1-bit output: Feedback path for data
	.OQ(dat_o),            // 1-bit output: Data path output
	// SHIFTOUT1 / SHIFTOUT2: 1-bit (each) output: Data output expansion (1-bit each)
	.SHIFTOUT1(), .SHIFTOUT2(),
	.TBYTEOUT(),           // 1-bit output: Byte group tristate
	.TFB(),                // 1-bit output: 3-state control
	.TQ(),                 // 1-bit output: 3-state control
	.CLK(fast_clk_i),     // 1-bit input: High speed clock
	.CLKDIV(sl_clk_i),     // 1-bit input: Divided clock
	// D1 - D8: 1-bit (each) input: Parallel data inputs (1-bit each)
	.D1(dat_i[0]),
	.D2(dat_i[1]),
	.D3(dat_i[2]),
	.D4(dat_i[3]),
	.D5(dat_i[4]),
	.D6(dat_i[5]),
	.D7(dat_i[6]),
	.D8(dat_i[7]),
	.OCE(1'b1),            // 1-bit input: Output data clock enable
	.RST(rst),             // 1-bit input: Reset
	// SHIFTIN1 / SHIFTIN2: 1-bit (each) input: Data input expansion (1-bit each)
	.SHIFTIN1(casc1), .SHIFTIN2(casc2),
	// T1 - T4: 1-bit (each) input: Parallel 3-state inputs
	.T1(1'b0), .T2(1'b0), .T3(1'b0), .T4(1'b0),
	.TBYTEIN(1'b0),        // 1-bit input: Byte group tristate
	.TCE(1'b0)             // 1-bit input: 3-state clock enable
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("SDR"),
	.DATA_WIDTH(10),
	.INIT_OQ(1), .INIT_TQ(1),
	.SERDES_MODE("SLAVE"),
	.SRVAL_OQ(0), .SRVAL_TQ(0),
	.TBYTE_CTL("FALSE"),
	.TBYTE_SRC("FALSE"),
	.TRISTATE_WIDTH(1)
) sserdes_inst (
	.OFB(),                // 1-bit output: Feedback path for data
	.OQ(),                 // 1-bit output: Data path output
	// SHIFTOUT1 / SHIFTOUT2: 1-bit (each) output: Data output expansion (1-bit each)
	.SHIFTOUT1(casc1), .SHIFTOUT2(casc2),
	.TBYTEOUT(),           // 1-bit output: Byte group tristate
	.TFB(),                // 1-bit output: 3-state control
	.TQ(),                 // 1-bit output: 3-state control
	.CLK(fast_clk_i),     // 1-bit input: High speed clock
	.CLKDIV(sl_clk_i),     // 1-bit input: Divided clock
	// D1 - D8: 1-bit (each) input: Parallel data inputs (1-bit each)
	.D1(    1'b0),
	.D2(    1'b0),
	.D3(dat_i[8]),
	.D4(dat_i[9]),
	.D5(    1'b0),
	.D6(    1'b0),
	.D7(    1'b0),
	.D8(    1'b0),
	.OCE(1'b1),            // 1-bit input: Output data clock enable
	.RST(rst),             // 1-bit input: Reset
	// SHIFTIN1 / SHIFTIN2: 1-bit (each) input: Data input expansion (1-bit each)
	.SHIFTIN1(1'b0), .SHIFTIN2(1'b0),
	// T1 - T4: 1-bit (each) input: Parallel 3-state inputs
	.T1(1'b0), .T2(1'b0), .T3(1'b0), .T4(1'b0),
	.TBYTEIN(1'b0),        // 1-bit input: Byte group tristate
	.TCE(1'b0)             // 1-bit input: 3-state clock enable
);

endmodule
