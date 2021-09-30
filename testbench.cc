#include <verilated.h>
#include "Vrisa_top.h"

#include "risa_testbench.h"


#if VM_TRACE
# include <verilated_vcd_c.h>
#endif

vluint64_t main_time = 0;
vluint64_t main_cycle = 0;
double sc_time_stamp() {
    return main_time;  // Note does conversion to real, to match SystemC
}


int main(int argc, char** argv, char** env) {
  if (0 && argc && argv && env) {}
  

  Verilated::debug(0); //0: off, 9: highest
  Verilated::randReset(2);

  Verilated::commandArgs(argc, argv);

  Vrisa_top* top = new Vrisa_top;

#if VM_TRACE
  VerilatedVcdC* tfp = NULL;
  const char* flag = Verilated::commandArgsPlusMatch("trace");
  if (flag && strcmp(flag, "+trace") == 0) {
    Verilated::traceEverOn(true);
    tfp = new VerilatedVcdC;
    top->trace(tfp, 99);  // 99 hierarchy levels
    Verilated::mkdir("logs");
    tfp->open("logs/dump.vcd"); 
    VL_PRINTF("Dumping wave into logs/dump.vcd\n");
  }
#endif

  RisaTestBench risa_tb(top);
  risa_tb.initialize();

  while (!Verilated::gotFinish()) {
    main_time++; 
    top->clk = !top->clk;
              
    if(main_time % 2 == 0) {        
      main_cycle++;
    }       

    top->eval();

    if(main_time %2 == 1) {
      if( !risa_tb.step_cycle(main_cycle) ) break;
    }

#if VM_TRACE
    // Dump trace data for this cycle
    if (tfp) tfp->dump(main_time);
#endif
  }
  
  risa_tb.finish();

  top->final();


#if VM_TRACE
  if (tfp) { tfp->close(); tfp = NULL; }
#endif

  delete top; top = NULL;

  exit(0);
}

