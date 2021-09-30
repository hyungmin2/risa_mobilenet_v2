TOP_MODULE=risa_top

VERILATOR_FLAGS =
VERILATOR_FLAGS += -cc --exe
VERILATOR_FLAGS += -O2 -x-assign 0
VERILATOR_FLAGS += --trace --trace-structs
VERILATOR_FLAGS += -Wno-CMPCONST
VERILATOR_FLAGS += -Wno-WIDTH
VERILATOR_FLAGS += --threads 8
VERILATOR_FLAGS += --top-module $(TOP_MODULE)

output=obj_dir/V$(TOP_MODULE)

default: $(output)

SOURCE_FILES = \
	intf.sv \
	buffer_ramt_rsize.sv \
	buffer_ramt_qsize.sv \
	buffer_row.sv \
	buffer_column.sv \
	pe.sv \
	requant.sv \
	pe_array.sv \
	risa_top.sv \
	testbench.cc \
	risa_testbench.cc \
	risa_testbench_host.cc 

$(output):
	verilator $(VERILATOR_FLAGS) -f input.vc $(SOURCE_FILES)
	$(MAKE) -j -C obj_dir -f V$(TOP_MODULE).mk

run:
	@mkdir -p logs
	$(output)
	diff output.dat ref_output.dat


clean:
	-rm -rf obj_dir logs *.log *.dmp *.vpd core output.dat
