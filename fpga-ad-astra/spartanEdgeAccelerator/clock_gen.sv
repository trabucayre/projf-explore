`timescale 1 ns / 100 fs

module clock_gen(
	input  wire logic clk,
	input  wire logic rst,
	output      logic clk_locked,
	output      logic clk_pix,
	output      logic clk_dvi
	);

	logic clk_s;
	logic locked, locked_r;
	logic clkfb;
	logic clk_pix_unbuf, clk_dvi_unbuf;
	BUFG IBUF_inst (.I(clk), .O(clk_s));

	PLLE2_BASE #(
		.BANDWIDTH("OPTIMIZED"),
    	.CLKFBOUT_MULT(15),   // 1.5GHz
    	.CLKFBOUT_PHASE(0.0),
    	.CLKIN1_PERIOD(10.0), // 100MHz
    	.CLKOUT0_DIVIDE(20),  // 75MHz
    	.CLKOUT1_DIVIDE(4),   // 375MHz
    	.DIVCLK_DIVIDE(1),
    	.STARTUP_WAIT("FALSE")
	) PLLE2_BASE_inst (
		.CLKOUT0(clk_pix_unbuf),
		.CLKOUT1(clk_dvi_unbuf),
		.CLKOUT2(),
		.CLKOUT3(),
		.CLKOUT4(),
		.CLKOUT5(),
		.CLKFBOUT(clkfb),
		.LOCKED(locked),
		.CLKIN1(clk_s),
		.PWRDWN(1'b0),
		.RST(rst),
		.CLKFBIN(clkfb)
	);

	BUFG bufg_clk_pix(.I(clk_pix_unbuf), .O(clk_pix));
	BUFG bufg_clk_dvi(.I(clk_dvi_unbuf), .O(clk_dvi));

	always_ff @(posedge clk_pix) begin
		locked_r <= locked;
		clk_locked <= locked_r;
	end

endmodule
