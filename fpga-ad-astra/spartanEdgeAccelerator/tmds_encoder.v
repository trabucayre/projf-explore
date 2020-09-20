// (C)2019 Gwenhael Goavec-Merou, open source hardware released under the MIT License

module TMDS_encoder (
	input            clk_i,
	input      [7:0] data_i,
	input            c0_i,
	input            c1_i,
	input            de,
	output reg [9:0] data_o
);

	/* generate xor and xnor representation */
	wire [8:0] dat_xor_s, dat_xnor_s;
	assign dat_xor_s[0] = data_i[0];
	assign dat_xnor_s[0] = data_i[0];
	genvar l_inst;
	generate
	for (l_inst = 1; l_inst < 8; l_inst = l_inst + 1) begin
		assign dat_xor_s[l_inst]  = data_i[l_inst] ^ dat_xor_s[l_inst-1];
		assign dat_xnor_s[l_inst] = ~(data_i[l_inst] ^ dat_xnor_s[l_inst-1]);
	end
	endgenerate
	assign dat_xor_s[8] = 1'b1;
	assign dat_xnor_s[8] = 1'b0;

	/* determine bit high count */
	wire [3:0] N1_in = data_i[0] + data_i[1] + data_i[2] + data_i[3] +
					data_i[4] + data_i[5] + data_i[6] + data_i[7];

	wire [8:0] q_m = (N1_in > 4 || (N1_in == 4 && data_i[0] == 0))?dat_xnor_s : dat_xor_s;
	wire [8:0] q_m_n = ~q_m;

	wire signed [4:0] N1 = {4'b0,q_m[0]} + {4'b0,q_m[1]}
			+ {4'b0,q_m[2]} + {4'b0,q_m[3]} + {4'b0,q_m[4]}
			+ {4'b0,q_m[5]} + {4'b0,q_m[6]} + {4'b0,q_m[7]};

	wire signed [4:0] N0 = 5'b01000 - N1;
	wire signed [4:0] disparity = N1 - N0;

	reg signed [4:0] cntTm;
	always @(posedge clk_i) begin
		if (!de) begin
			case ({c1_i,c0_i})
			2'b00:
				data_o <= 10'b1101010100; // 0x354
			2'b01:
				data_o <= 10'b0010101011; // 0x0AB
			2'b10:
				data_o <= 10'b0101010100; // 0x154
			2'b11:
				data_o <= 10'b1010101011; // 0x2AB
			endcase
			cntTm <= 5'b0;
		end else begin
			if (cntTm == 5'b0 || disparity == 5'b0) begin
				if (q_m[8] == 1'b1) begin
					data_o <= {2'b01, q_m[7:0]};
					cntTm <= cntTm + disparity;
				end else begin
					data_o <= {2'b10, q_m_n[7:0]};
					cntTm <= cntTm - disparity;
				end
			end else if ((cntTm > 0 && disparity > 0) ||
						(cntTm < 0 && disparity < 0)) begin
				data_o <= {1'b1, q_m[8], q_m_n[7:0]};
				cntTm <= cntTm + {3'b0, q_m[8], 1'b0}
						- disparity;
			end else begin
				data_o <= {1'b0, q_m};
				cntTm <= cntTm - $signed({3'b0, q_m_n[8], 1'b0})
						+ disparity;
			end
		end
	end
endmodule
