## Project F: FPGA Ad Astra - Spartan Edge Accelerator Makefile
## (C)2020 Will Green, open source hardware released under the MIT License
## Learn more at https://projectf.io

VIVADO = vivado -nolog -nojournal -mode batch

CABLE := digilent_hs2

XDC = sea.xdc
ADD_SRC += bram.sv clock_gen.sv
ADD_SRC += ../display_timings.sv ../lfsr.sv ../sprite.sv ../starfield.sv
ADD_SRC += dvi.v serializer.v tmds_encoder.v

all: top_lfsr.bit top_starfields.bit top_hello_en.bit top_hello_jp.bit top_greet.bit

%.ys: %.sv
	echo "read_verilog -sv $^ $(ADD_SRC)" > $@
	echo "synth_xilinx -edif $*.edif -top $*" >> $@

%.edif: %.ys
	yosys $*.ys

%.bit: %.edif
	$(VIVADO) -source run_vivado.tcl -tclargs $* $(XDC)

%_flash: %.bit
	openFPGALoader -c $(CABLE) $*.bit

clean:
	-rm *.bit *.log *.edif *.ys

.PHONY: all clean
