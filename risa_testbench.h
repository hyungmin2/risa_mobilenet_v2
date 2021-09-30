#ifndef __RISA_TESTBENCH_H__
#define __RISA_TESTBENCH_H__

#include <verilated.h>
#include "Vrisa_top.h"


#include <queue>
#include <map>
#include <vector>
#include <thread>
#include <mutex>


#include "defines.h"


struct CommandDataPort {
  uint8_t valid;
  uint8_t command;
  uint32_t command_data0;
  uint32_t command_data1;

  static struct CommandDataPort ConvertFromPort(const WData* p_packed_val) {
  struct CommandDataPort val;
    val.command_data1 = p_packed_val[0];
    val.command_data0 = p_packed_val[1];
    val.command = p_packed_val[2] & 0xFF;
    val.valid = (p_packed_val[2] >> 8) & 0x1;
    return val;
  }

  void ConvertToPort(WData* p_packed_val) {
    p_packed_val[0] = command_data1;
    p_packed_val[1] = command_data0;
    p_packed_val[2] = command | (valid<<8);
  }
} ;


struct BufferColumnState {
  uint16_t pein;
  uint16_t peout;
  uint8_t al_in;
  struct BufferColumnState ConvertFromPort(const QData  p_packed_val) {
    al_in = (p_packed_val >> 0) & 0xF;
    peout = (p_packed_val >> 4) & 0xFFFF;
    pein = (p_packed_val >> 20) & 0xFFFF;
  }

  QData  ConvertToPort() {
    QData  p_packed_val = al_in | (peout<<4) | (pein<<20);
    return p_packed_val;
  }
} ;



struct BufferRowState {
  uint8_t fin;
  uint8_t fout;
  uint8_t pein;
  uint8_t peout;
  uint8_t aw_out;
  struct BufferRowState ConvertFromPort(const IData  p_packed_val) {
    aw_out = (p_packed_val >> 0) & 0xF;
    peout = (p_packed_val >> 4) & 0xF;
    pein = (p_packed_val >> 8) & 0xF;
    fout = (p_packed_val >> 12) & 0xF;
    fin = (p_packed_val >> 16) & 0xF;
  }

  IData  ConvertToPort() {
    IData  p_packed_val = aw_out | (peout<<4) | (pein<<8) | (fout<<12) | (fin<<16);
    return p_packed_val;
  }
} ;


struct RequantState {
  uint8_t al_in;
  struct RequantState ConvertFromPort(const CData   p_packed_val) {
    al_in = (p_packed_val >> 0) & 0xF;
  }

  CData  ConvertToPort() {
    CData  p_packed_val = al_in;
    return p_packed_val;
  }
} ;


#define COMMAND_CB 0
#define COMMAND_RQ 1
#define COMMAND_RB 2
#define COMMAND_AL 3
#define COMMAND_STOP 4

#define STATE_CB 0
#define STATE_RQ 1
#define STATE_RB 2
#define STATE_AL 3

#define WAIT_STATE_CB_AL 0
#define WAIT_STATE_CB_PEIN 1
#define WAIT_STATE_CB_PEOUT 2
#define WAIT_STATE_RQ_AL 3

class RisaTestBench {
  private:
    Vrisa_top* top;

    std::queue<uint8_t> al_data_in[ARRAY_WIDTH];
    std::queue<uint8_t> al_data_out[ARRAY_WIDTH];
    std::map<uint32_t, std::vector<uint8_t>> dram_contents;
    int al_start_relay[ARRAY_WIDTH+1];
    CommandDataPort cdp_zero;
    
    int64_t stop_cycle;
    
    void dump_cb_w(const char* fn);
    void dump_cb_b(const char* fn);
    void load_cb(uint32_t addr,uint32_t size);
    void load_ext_data(uint32_t addr, const char* fn);    
    void prepare_ext_data();

    
    //fake host program
    std::thread host_thread;
    std::mutex mtx;

    std::queue<CommandDataPort> command_queue;
    std::queue<int>             command_id_queue;
    int                         state_id_req;
    int                         state_ready;


    BufferRowState    host_stateport_h_rb;
    BufferColumnState host_stateport_h_cb;
    RequantState      host_stateport_h_rq;
    uint8_t           host_stateport_al;
    
    void host_function();
    void host_getstates(int type);
    void host_setcommand(int type, CommandDataPort command);
    void Control_Load(uint32_t axi_addr, uint32_t size, uint32_t addr_to);
    void Control_TrTransfer(uint32_t in_ch, uint32_t repeat_num, uint32_t fmap_h, uint32_t num_lines_per_ch, uint32_t last_line_width, uint32_t addr_from, uint32_t addr_to, uint32_t layer_id);
    void Control_LoadRQ(uint32_t axi_addr, uint32_t out_ch);
    void Control_IConv(
                                  uint32_t in_h,
                                  uint32_t in_w,
                                  uint32_t in_ch,
                                  uint32_t out_ch,
                                  uint32_t filter_k,
                                  uint32_t stride,
                                  uint32_t pad,
                                  uint32_t input_zp,
                                  uint32_t output_zp,
                                  uint32_t addr_to,
                                  uint32_t addr_filter,
                                  uint32_t layer_id,
                                  uint32_t relu
                                );
                                  
    void Control_Dconv(
                                  uint32_t  in_h,
                                  uint32_t  in_w,
                                  uint32_t  ch,
                                  uint32_t  filter_k,
                                  uint32_t  stride,
                                  uint32_t  pad,
                                  uint32_t  input_zp,
                                  uint32_t  output_zp,
                                  uint32_t  addr_from,
                                  uint32_t  addr_to,
                                  uint32_t  addr_filter,
                                  uint32_t  layer_id,
                                  uint32_t  relu
                                );
                                
    void Control_ConvInTransfer(
                                  uint32_t  in_h,
                                  uint32_t  in_w,
                                  uint32_t  in_ch,
                                  uint32_t  out_ch,
                                  uint32_t  filter_k,
                                  uint32_t  stride,
                                  uint32_t  pad,
                                  uint32_t  input_zp,
                                  uint32_t  output_zp,
                                  uint32_t  addr_from,
                                  uint32_t  addr_to,
                                  uint32_t  addr_filter,
                                  uint32_t  layer_id,
                                  uint32_t  relu
                                );

    void Control_Add(
                                  uint32_t  in_h,
                                  uint32_t  in_w,
                                  uint32_t  ch,
                                  uint32_t  input_zp0,
                                  uint32_t  input_zp1,
                                  uint32_t  rescale_int0,
                                  uint32_t  rescale_int1,
                                  uint32_t  output_zp,
                                  uint32_t  addr_from_new,
                                  uint32_t  addr_from_res,
                                  uint32_t  addr_to,
                                  uint32_t  layer_id,
                                  uint32_t  relu
                                );
      void Control_Avg(
                                  uint32_t  in_h,
                                  uint32_t  in_w,
                                  uint32_t  ch,
                                  uint32_t  input_zp,
                                  uint32_t  rescale_int,
                                  uint32_t  output_zp,
                                  uint32_t  addr_from,
                                  uint32_t  addr_to,
                                  uint32_t  layer_id
                                );
                                
      void Control_Dump(uint32_t addr_from, uint32_t axi_addr);
      void Control_WaitforIdle(uint32_t type);
      
      void Control_In_Transfer_Conv_Sequence(int lid, uint32_t in_buf_addr,  uint32_t out_buf_addr, uint32_t weight_addr);
      void Control_Dconv_Sequence(int lid, uint32_t in_buf_addr,  uint32_t out_buf_addr, uint32_t weight_addr);
      void Control_Add_Sequence(int lid, uint32_t in_buf0_addr,  uint32_t in_buf1_addr, uint32_t out_buf_addr);
      void Control_Avg_Sequence(int lid, uint32_t in_buf_addr,  uint32_t out_buf_addr);

  public:
    RisaTestBench(Vrisa_top* _top) ;
    void initialize();
    bool step_cycle(vluint64_t cycle) ; //return false when stop
    void finish() ;
};



#endif // __RISA_TESTBENCH_H__