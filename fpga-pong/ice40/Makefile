## Project F: FPGA Pong - iCEBreaker Makefile
## (C)2020 Will Green, open source hardware released under the MIT License
## Learn more at https://projectf.io

# configuration
SHELL = /bin/sh
FPGA_PKG = sg48
PCF = icebreaker.pcf
ADD_SRC = clock_gen.sv ../debounce.sv ../display_timings.sv

top_pong_v1: top_pong_v1.rpt top_pong_v1.bin
top_pong_v2: top_pong_v2.rpt top_pong_v2.bin
top_pong_v3: top_pong_v3.rpt top_pong_v3.bin
top_pong_v4: top_pong_v4.rpt top_pong_v4.bin

%.json: %.sv
	yosys -ql $(subst .json,,$@)-yosys.log -p 'synth_ice40 -top $(subst .json,,$@) -json $@' $< $(ADD_SRC)

%.asc: %.json
	nextpnr-ice40 --up5k --package ${FPGA_PKG} --json $< --pcf ${PCF} --asc $@

%.rpt: %.asc
	icetime -d up5k -mtr $@ $<

%.bin: %.asc
	icepack $< $@

clean:
	rm -f top*.json top*.asc top*.rpt top*.bin top*yosys.log

all: top_pong_v1 top_pong_v2 top_pong_v3 top_pong_v4

.PHONY: all clean
