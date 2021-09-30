
#include "risa_testbench.h"
#include <iostream>


void RisaTestBench::host_getstates(int type) {
  mtx.lock();
  mtx.unlock();
  state_ready = false;
  state_id_req = type;
  std::this_thread::yield();

  while(1) {
    mtx.lock();
    if(state_ready) {
      mtx.unlock();
      return;
    }

    mtx.unlock();
    std::this_thread::yield();
  }
}

void RisaTestBench::host_setcommand(int type, CommandDataPort command)  {
  usleep(100+rand()%100);
  mtx.lock();
  command_queue.push(command);
  command_id_queue.push(type);
  mtx.unlock();
}


RisaTestBench::RisaTestBench(Vrisa_top* _top) 
  : top(_top)
  {
  
  cdp_zero.valid = 0;
  cdp_zero.command = 0;
  cdp_zero.command_data0 = 0;
  cdp_zero.command_data1 = 0;

  stop_cycle = -1;
}


void RisaTestBench::initialize() {
  prepare_ext_data();

  // Initial input values
  top->clk = 0;
  top->rstn = 1;
  top->stateport_al = 0;

  cdp_zero.ConvertToPort(top->i_commanddataport_h_cb);
  cdp_zero.ConvertToPort(top->i_commanddataport_h_rq);
  cdp_zero.ConvertToPort(top->i_commanddataport_h_rb);
  cdp_zero.ConvertToPort(top->i_commanddataport_al);

  for(int i = 0; i < ARRAY_WIDTH; i ++) {
    top->al_bw_data[i] = 0;
    top->al_bw_valid[i] = 0;
  }

  host_thread = std::thread(&RisaTestBench::host_function, this);
}

bool RisaTestBench::step_cycle(vluint64_t cycle) {
  //reset
  top->rstn = 1;
  if(cycle < 20)  top->rstn = 0;

  //feed ext data
  for(int i =ARRAY_WIDTH-1; i >=0; i--) {
    top->al_bw_data[i] = 0;
    top->al_bw_valid[i] = 0;

    if((top->al_bw_ready0[i] || top->al_bw_ready1[i]) && !al_data_in[i].empty() && al_start_relay[i]){
      top->al_bw_valid[i] = 1;
      top->al_bw_data[i] = al_data_in[i].front();

      al_data_in[i].pop();          
      al_start_relay[i+1] = 1;
    }
  }
    
  auto commanddataport_al = CommandDataPort::ConvertFromPort(top->commanddataport_al);
  if(commanddataport_al.valid) {
    load_cb(commanddataport_al.command_data0,commanddataport_al.command_data1);
  }

  for(int i = 0; i < ARRAY_WIDTH; i ++) {
    if(top->aw_bw_valid[i]) {
      al_data_out[i].push(top->aw_bw_data[i]);
    }
  }

  // get state 
  {
    mtx.lock();
    if(state_id_req == STATE_CB) {
      host_stateport_h_cb.ConvertFromPort(top->o_stateport_h_cb);
    }
    else if(state_id_req == STATE_RQ) {
      host_stateport_h_rq.ConvertFromPort(top->o_stateport_h_rq);
    }
    else if(state_id_req == STATE_RB) {
      host_stateport_h_rb.ConvertFromPort(top->o_stateport_h_rb);
    }
    else if(state_id_req == STATE_AL) {
      host_stateport_al = top->o_stateport_al;    
    }
    state_ready = true;
    mtx.unlock();
  }

  //set command
  {
    cdp_zero.ConvertToPort(top->i_commanddataport_h_cb);
    cdp_zero.ConvertToPort(top->i_commanddataport_h_rq);
    cdp_zero.ConvertToPort(top->i_commanddataport_h_rb);
    cdp_zero.ConvertToPort(top->i_commanddataport_al);

    mtx.lock();
    if(!command_id_queue.empty()) {
      int command_id = command_id_queue.front();
      CommandDataPort command = command_queue.front();
      command_id_queue.pop();
      command_queue.pop();

      if(command_id == COMMAND_CB) {
        command.ConvertToPort(top->i_commanddataport_h_cb);
      }
      else if(command_id == COMMAND_RQ) {
        command.ConvertToPort(top->i_commanddataport_h_rq);
      }
      else if(command_id == COMMAND_RB) {
        command.ConvertToPort(top->i_commanddataport_h_rb);
      }
      else if(command_id == COMMAND_AL) {
        command.ConvertToPort(top->i_commanddataport_al);
      }
      else if(command_id == COMMAND_STOP) {
        stop_cycle = cycle + 100; //set stop cycle
      }
    }
    mtx.unlock();    
  }

  if(stop_cycle == cycle)  return false; //stop

  return true;
}

void RisaTestBench::finish() {
  std::cout << "finish"<< std::endl;
  
  host_thread.join();
  
  std::cout << "joined"<< std::endl;

  dump_cb_b("output.dat");
}

void RisaTestBench::dump_cb_w(const char* fn)  {
  size_t dump_size_per_cb = al_data_out[0].size();

  printf("dump_size_per_cb %ld\n",dump_size_per_cb);

  for(int i = 1 ; i < ARRAY_WIDTH; i ++) {
    if(dump_size_per_cb != al_data_out[i].size()){
      printf("dump size mismatch %ld - %ld at db %d\n",dump_size_per_cb,al_data_out[i].size(),i);
      return;
    }
  }
  
  FILE* outf = fopen(fn,"w"); //ascii!
  if(!outf) {
    printf("Dump file open error: %s\n",fn);
    return;  
  }

  for(int li = 0 ; li < dump_size_per_cb; li ++) {    
    for(int wi = 0 ; wi < ARRAY_WIDTH; wi ++) {
      fprintf(outf,"%d\n",(int8_t)al_data_out[wi].front());
      al_data_out[wi].pop();
    }
  }

  fclose(outf);
}

void RisaTestBench::dump_cb_b(const char* fn)  {
  size_t dump_size_per_cb = al_data_out[0].size();

  printf("dump_size_per_cb %ld\n",dump_size_per_cb);

  for(int i = 1 ; i < ARRAY_WIDTH; i ++) {
    if(dump_size_per_cb != al_data_out[i].size()){
      printf("dump size mismatch %ld - %ld at db %d\n",dump_size_per_cb,al_data_out[i].size(),i);
      return;
    }
  }
  
  FILE* outf = fopen(fn,"wb"); //ascii!
  if(!outf) {
    printf("Dump file open error: %s\n",fn);
    return;  
  }


  for(int li = 0 ; li < dump_size_per_cb; li ++) {    
    for(int wi = 0 ; wi < ARRAY_WIDTH; wi ++) {
      int8_t val = (int8_t)al_data_out[wi].front();
      fwrite(&val,1,1,outf);
      al_data_out[wi].pop();
    }
  }

  fclose(outf);
}


void RisaTestBench::load_cb(uint32_t addr,uint32_t size) {
  printf("load_cb addr %x size %x(%d)\n",addr,size,size);    

  if(dram_contents.find(addr) != dram_contents.end()){
    std::vector<uint8_t> rbuffer = dram_contents[addr];

    if(rbuffer.size() != size) {
      printf("load_cb size mismatch %ld-%d at %x\n",rbuffer.size(),size,addr);    
    }    
    else if (size % ARRAY_WIDTH != 0) {
      printf("load_cb size not aligned %d at %x\n",size,addr);    
    }
    else {
      for(int li = 0; li < (size/ARRAY_WIDTH) ; li ++) {
        for(int wi = 0; wi < ARRAY_WIDTH; wi ++) {
          al_data_in[wi].push( rbuffer[li*ARRAY_WIDTH+wi] );          
        }
      }

      for(int i = 0; i < ARRAY_WIDTH; i++ ){
        al_start_relay[i+1] = 0;
      }
      al_start_relay[0] = 1;
    }    
  }
  else {
    printf("reading from unloaded DDR address %x\n",addr);
  }
}

void RisaTestBench::load_ext_data(uint32_t addr, const char* fn) {
  FILE* inf = fopen(fn,"rb"); //binary!
  if(!inf) {
    printf("In file open error: %s\n",fn);
    return;  
  }

  size_t inf_size;
  fseek(inf,0,SEEK_END);
  inf_size = ftell(inf);
  fseek(inf,0,SEEK_SET);

  std::vector<uint8_t> rbuffer;
  rbuffer.resize(inf_size);
  fread(&rbuffer[0],1,inf_size,inf);
  fclose(inf);

  dram_contents[addr] = rbuffer;
}
