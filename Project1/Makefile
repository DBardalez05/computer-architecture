# Run from Project1/.
#   make test    run all four testbenches with iverilog
#   make tb_led  run just one testbench
#   make build   synthesize the CPU + LED program into build/top.bin
#   make prog    load build/top.bin onto the board (SRAM)

# OSS CAD suite tools (change this if yours is somewhere else)
CAD = $(HOME)/oss-cad-suite/bin

TESTS = tb_first proj1_tb tb_extra tb_led
pcf_file = constraints/iceBlinkPico.pcf

.PHONY: test $(TESTS) build prog clean

test: $(TESTS)

$(TESTS):
	mkdir -p build results/logs results/waveforms
	$(CAD)/iverilog -g2012 -I rtl -o build/$@.vvp tb/$@.sv
	$(CAD)/vvp build/$@.vvp | tee results/logs/$@.log

build:
	mkdir -p build results/logs
	$(CAD)/yosys -q -l results/logs/synthesis.log -p "read_verilog -sv -I rtl rtl/top.sv; synth_ice40 -top top -json build/top.json"
	$(CAD)/nextpnr-ice40 --up5k --package sg48 --freq 12 --json build/top.json --pcf $(pcf_file) --log results/logs/place_route.log --asc build/top.asc
	$(CAD)/icepack build/top.asc build/top.bin

prog: #for sram
	$(CAD)/dfu-util --device 1d50:6146 --alt 0 -D build/top.bin -R

clean:
	rm -rf build
