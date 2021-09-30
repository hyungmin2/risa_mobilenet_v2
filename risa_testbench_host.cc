
#include "risa_testbench.h"
#include <iostream>

extern vluint64_t main_cycle;

void RisaTestBench::Control_WaitforIdle(uint32_t type)  {
  usleep(1000);

  while(true) {
    if(type == WAIT_STATE_CB_AL) {
      host_getstates(STATE_CB);
      if(host_stateport_h_cb.al_in == BUFFER_WEIGHT_IDLE)  break;
    }
    else if(type == WAIT_STATE_CB_PEIN) {
      host_getstates(STATE_CB);
      if(host_stateport_h_cb.pein == BUFFER_WEIGHT_IDLE)  break;
    }
    else if(type == WAIT_STATE_CB_PEOUT) {
      host_getstates(STATE_CB);
      if(host_stateport_h_cb.peout == BUFFER_WEIGHT_IDLE)  break;
    }
    else if(type == WAIT_STATE_RQ_AL) {
      host_getstates(STATE_RQ);
      if(host_stateport_h_rq.al_in == BUFFER_WEIGHT_IDLE)  break;
    }
  }
}

void RisaTestBench::Control_Load(uint32_t axi_addr, uint32_t size, uint32_t addr_to)  {
  CommandDataPort command;
  command.valid = 1;

  command.command = BUFFER_WEIGHT_MODESET_LOAD;
  command.command_data0 = addr_to;
  command.command_data1 = size / ARRAY_WIDTH;
  host_setcommand(COMMAND_CB,command);
  
  command.command = 1;
  command.command_data0 = axi_addr;
  command.command_data1 = size;
  host_setcommand(COMMAND_AL,command);
  
  usleep(10000);
  
  Control_WaitforIdle(WAIT_STATE_CB_AL);    
}

void RisaTestBench::Control_TrTransfer(uint32_t in_ch, uint32_t repeat_num, uint32_t fmap_h, uint32_t num_lines_per_ch, uint32_t last_line_width, uint32_t addr_from, uint32_t addr_to, uint32_t layer_id)  {
  CommandDataPort command;
  command.valid = 1;

  //set CB
  command.command = BUFFER_WEIGHT_MODESET_TRTRANSFER0;
  command.command_data0 = in_ch;
  command.command_data1 = repeat_num;
  host_setcommand(COMMAND_CB,command);
 

  command.command = BUFFER_WEIGHT_MODESET_TRTRANSFER1;
  command.command_data0 = num_lines_per_ch;
  command.command_data1 = last_line_width;
  host_setcommand(COMMAND_CB,command);

  command.command = BUFFER_WEIGHT_MODESET_TRTRANSFER2;
  command.command_data0 = addr_from;
  command.command_data1 = fmap_h;
  host_setcommand(COMMAND_CB,command);

  
  //set RB
  command.command = BUFFER_QUANT_MODESET_TRTRANSFER0;
  command.command_data0 = addr_to;
  if(last_line_width == 0)
    command.command_data1 = addr_to+(num_lines_per_ch * ARRAY_WIDTH )*fmap_h/2;
  else
    command.command_data1 = addr_to+((num_lines_per_ch-1) * ARRAY_WIDTH + last_line_width)*fmap_h/2;  
  host_setcommand(COMMAND_RB,command);
  
  command.command = BUFFER_QUANT_MODESET_TRTRANSFER1;
  if(last_line_width == 0)
    command.command_data0 = (num_lines_per_ch * ARRAY_WIDTH)*fmap_h/2;
  else
    command.command_data0 = ((num_lines_per_ch-1) * ARRAY_WIDTH + last_line_width)*fmap_h/2;
  command.command_data1 = layer_id;
  host_setcommand(COMMAND_RB,command);


  Control_WaitforIdle(WAIT_STATE_CB_PEOUT);
}


void RisaTestBench::Control_LoadRQ(uint32_t axi_addr, uint32_t out_ch)  {
  CommandDataPort command;
  command.valid = 1;

  command.command = REQUANT_MODESET_LOAD_RQ;
  command.command_data0 = CEILDIV(out_ch,ARRAY_WIDTH);
  host_setcommand(COMMAND_RQ,command);
  
  
  usleep(10000);
  command.command = 1;
  command.command_data0 = axi_addr;
  command.command_data1 = CEILDIV(out_ch,ARRAY_WIDTH)*ARRAY_WIDTH * 8;
  host_setcommand(COMMAND_AL,command);
  
  usleep(10000);

  Control_WaitforIdle(WAIT_STATE_RQ_AL);  
}


void RisaTestBench::Control_IConv(
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
                                  )  {
  CommandDataPort command;
  command.valid = 1;

  //set RQ
  command.command = REQUANT_MODESET_ACCUM_CONV0;
  command.command_data0 = in_h/stride;
  command.command_data1 = in_w/stride;
  host_setcommand(COMMAND_RQ,command); 
  
  command.command = REQUANT_MODESET_ACCUM_CONV1;
  command.command_data0 = CEILDIV(in_ch,ARRAY_HEIGHT);
  command.command_data1 = CEILDIV(out_ch,ARRAY_WIDTH);
  host_setcommand(COMMAND_RQ,command); 
  
  command.command = REQUANT_MODESET_ACCUM_CONV2;
  command.command_data0 = 1;
  command.command_data1 = stride;
  host_setcommand(COMMAND_RQ,command); 

  command.command = REQUANT_MODESET_ACCUM_CONV3;
  command.command_data0 = output_zp;
  host_setcommand(COMMAND_RQ,command); 
  
  command.command = REQUANT_MODESET_ACCUM_CONV5;
  command.command_data0 = in_ch;
  command.command_data1 = out_ch;
  host_setcommand(COMMAND_RQ,command); 
  
  command.command = REQUANT_MODESET_ACCUM_CONV_LAYERID;
  command.command_data0 = layer_id;
  command.command_data1 = relu;
  host_setcommand(COMMAND_RQ,command); 

  //set CB
  command.command = BUFFER_WEIGHT_MODESET_CONV0;
  command.command_data0 = in_h/stride;
  command.command_data1 = in_w/stride;
  host_setcommand(COMMAND_CB,command); 
  
  command.command = BUFFER_WEIGHT_MODESET_CONV1;
  command.command_data0 = CEILDIV(in_ch,ARRAY_HEIGHT);
  command.command_data1 = CEILDIV(out_ch,ARRAY_WIDTH);
  host_setcommand(COMMAND_CB,command); 
  
  command.command = BUFFER_WEIGHT_MODESET_CONV2;
  command.command_data0 = filter_k;
  command.command_data1 = stride;
  host_setcommand(COMMAND_CB,command); 

  command.command = BUFFER_WEIGHT_MODESET_CONV4;
  command.command_data0 = 0;//addr_from;
  command.command_data1 = addr_to;
  host_setcommand(COMMAND_CB,command); 
  
  command.command = BUFFER_WEIGHT_MODESET_CONV5;
  command.command_data0 = in_ch;
  command.command_data1 = out_ch;
  host_setcommand(COMMAND_CB,command); 
  
  command.command = BUFFER_WEIGHT_MODESET_CONV6;
  command.command_data0 = in_h;
  command.command_data1 = in_w;
  host_setcommand(COMMAND_CB,command); 
  
  command.command = BUFFER_WEIGHT_MODESET_CONV7;
  command.command_data0 = addr_filter;
  host_setcommand(COMMAND_CB,command); 
  
  command.command = BUFFER_WEIGHT_MODESET_ICONV_LAYERID;
  command.command_data0 = layer_id;
  host_setcommand(COMMAND_CB,command); 
  

  //set RB
  command.command = BUFFER_QUANT_MODESET_ICONV0;
  command.command_data0 = in_h;
  command.command_data1 = in_w;
  host_setcommand(COMMAND_RB,command); 
  
  command.command = BUFFER_QUANT_MODESET_ICONV1;
  command.command_data0 = CEILDIV(in_ch,ARRAY_HEIGHT);
  command.command_data1 = CEILDIV(out_ch,ARRAY_WIDTH);
  host_setcommand(COMMAND_RB,command); 
  
  command.command = BUFFER_QUANT_MODESET_ICONV2;
  command.command_data0 = filter_k;
  command.command_data1 = stride;
  host_setcommand(COMMAND_RB,command); 
  
  command.command = BUFFER_QUANT_MODESET_ICONV3;
  command.command_data0 = pad;
  command.command_data1 = input_zp;
  host_setcommand(COMMAND_RB,command); 
  
  command.command = BUFFER_QUANT_MODESET_ICONV4;
  command.command_data0 = 0;//addr_from;
  command.command_data1 = 0;//addr_to;
  host_setcommand(COMMAND_RB,command); 

  command.command = BUFFER_QUANT_MODESET_ICONV5;
  command.command_data0 = in_ch;
  command.command_data1 = out_ch;
  host_setcommand(COMMAND_RB,command); 
  
  command.command = BUFFER_QUANT_MODESET_ICONV6;
  command.command_data0 = filter_k*filter_k;
  command.command_data1 = in_ch;
  host_setcommand(COMMAND_RB,command);   

  command.command = BUFFER_QUANT_MODESET_ICONV_LAYERID;
  command.command_data0 = layer_id;
  host_setcommand(COMMAND_RB,command); 
  
  
  Control_WaitforIdle(WAIT_STATE_CB_PEIN);  
}


    
void RisaTestBench::Control_Dump(uint32_t addr_from, uint32_t len) {
  CommandDataPort command;
  command.valid = 1;

  command.command = BUFFER_WEIGHT_MODESET_DUMP;
  command.command_data0 = addr_from;
  command.command_data1 = len;
  host_setcommand(COMMAND_CB,command);
    
  Control_WaitforIdle(WAIT_STATE_CB_PEOUT);  
}

void RisaTestBench::Control_Dconv(
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
) {
  CommandDataPort command;
  command.valid = 1;

  //set RQ
  command.command = REQUANT_MODESET_ACCUM_CONV0;
  command.command_data0 = in_h/stride;
  command.command_data1 = in_w/stride;
  host_setcommand(COMMAND_RQ,command); 

  command.command = REQUANT_MODESET_ACCUM_CONV1;
  command.command_data0 = CEILDIV(ch,ARRAY_HEIGHT);
  command.command_data1 = CEILDIV(ch,ARRAY_HEIGHT); //width>?????
  host_setcommand(COMMAND_RQ,command); 
  
  command.command = REQUANT_MODESET_ACCUM_CONV2;
  command.command_data0 = filter_k;
  command.command_data1 = stride;
  host_setcommand(COMMAND_RQ,command); 
  
  command.command = REQUANT_MODESET_ACCUM_CONV3;
  command.command_data0 = output_zp;
  command.command_data1 = 1;
  host_setcommand(COMMAND_RQ,command); 
  
  command.command = REQUANT_MODESET_ACCUM_CONV5;
  command.command_data0 = ch;
  command.command_data1 = ch;
  host_setcommand(COMMAND_RQ,command); 
  
  command.command = REQUANT_MODESET_ACCUM_DCONV_LAYERID;
  command.command_data0 = layer_id;
  command.command_data1 = relu;
  host_setcommand(COMMAND_RQ,command); 


  //set CB
  command.command = BUFFER_WEIGHT_MODESET_CONV0;
  command.command_data0 = in_h/stride;
  command.command_data1 = in_w/stride;
  host_setcommand(COMMAND_CB,command); 
  
  command.command = BUFFER_WEIGHT_MODESET_CONV1;
  command.command_data0 = CEILDIV(ch,ARRAY_HEIGHT);
  command.command_data1 = CEILDIV(ch,ARRAY_HEIGHT); //width>?????
  host_setcommand(COMMAND_CB,command); 
  
  command.command = BUFFER_WEIGHT_MODESET_CONV2;
  command.command_data0 = filter_k;
  command.command_data1 = stride;
  host_setcommand(COMMAND_CB,command); 
  
  command.command = BUFFER_WEIGHT_MODESET_CONV3;
  command.command_data0 = pad;
  command.command_data1 = input_zp;
  host_setcommand(COMMAND_CB,command); 

  command.command = BUFFER_WEIGHT_MODESET_CONV4;
  command.command_data0 = addr_from;
  command.command_data1 = addr_to;
  host_setcommand(COMMAND_CB,command); 

  command.command = BUFFER_WEIGHT_MODESET_CONV5;
  command.command_data0 = ch;
  command.command_data1 = ch;
  host_setcommand(COMMAND_CB,command); 

  command.command = BUFFER_WEIGHT_MODESET_CONV6;
  command.command_data0 = in_h;
  command.command_data1 = in_w;
  host_setcommand(COMMAND_CB,command); 

  command.command = BUFFER_WEIGHT_MODESET_CONV7;
  command.command_data0 = addr_filter;
  command.command_data1 = 1;
  host_setcommand(COMMAND_CB,command); 

  command.command = BUFFER_WEIGHT_MODESET_DCONV_LAYERID;
  command.command_data0 = layer_id;
  command.command_data1 = ch;
  host_setcommand(COMMAND_CB,command); 

  Control_WaitforIdle(WAIT_STATE_CB_PEOUT);  
}



void RisaTestBench::Control_ConvInTransfer(
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
) {
  CommandDataPort command;
  command.valid = 1;

  //set RQ
  command.command = REQUANT_MODESET_ACCUM_CONV0;
  command.command_data0 = in_h/stride;
  command.command_data1 = in_w/stride;
  host_setcommand(COMMAND_RQ,command); 

  command.command = REQUANT_MODESET_ACCUM_CONV1;
  command.command_data0 = CEILDIV(in_ch,ARRAY_HEIGHT);
  command.command_data1 = CEILDIV(out_ch,ARRAY_WIDTH);
  host_setcommand(COMMAND_RQ,command); 

  command.command = REQUANT_MODESET_ACCUM_CONV2;
  command.command_data0 = filter_k;
  command.command_data1 = stride;
  host_setcommand(COMMAND_RQ,command); 
    
  command.command = REQUANT_MODESET_ACCUM_CONV3;
  command.command_data0 = output_zp;
  command.command_data1 = 0;
  host_setcommand(COMMAND_RQ,command); 
    
  command.command = REQUANT_MODESET_ACCUM_CONV5;
  command.command_data0 = in_ch;
  command.command_data1 = out_ch;
  host_setcommand(COMMAND_RQ,command); 

  command.command = REQUANT_MODESET_ACCUM_CONV_LAYERID;
  command.command_data0 = layer_id;
  command.command_data1 = relu;
  host_setcommand(COMMAND_RQ,command); 


  //set RB  
  command.command = BUFFER_QUANT_MODESET_CONV0;
  command.command_data0 = in_h;
  command.command_data1 = in_w;
  host_setcommand(COMMAND_RB,command); 

  command.command = BUFFER_QUANT_MODESET_CONV1;
  command.command_data0 = CEILDIV(in_ch,ARRAY_HEIGHT);
  command.command_data1 = CEILDIV(out_ch,ARRAY_WIDTH);
  host_setcommand(COMMAND_RB,command); 

  command.command = BUFFER_QUANT_MODESET_CONV2;
  command.command_data0 = filter_k;
  command.command_data1 = stride;
  host_setcommand(COMMAND_RB,command); 
    
  command.command = BUFFER_QUANT_MODESET_CONV3;
  command.command_data0 = pad;
  command.command_data1 = input_zp;
  host_setcommand(COMMAND_RB,command); 
    
  command.command = BUFFER_QUANT_MODESET_CONV4;
  command.command_data0 = 0;
  command.command_data1 = 0;
  host_setcommand(COMMAND_RB,command); 

  command.command = BUFFER_QUANT_MODESET_CONV5;
  command.command_data0 = in_ch;
  command.command_data1 = out_ch;
  host_setcommand(COMMAND_RB,command); 

  command.command = BUFFER_QUANT_MODESET_CONV6;
  command.command_data0 = addr_to;
  command.command_data1 = (in_h/stride) * (in_w/stride) * CEILDIV(out_ch,ARRAY_WIDTH);
  host_setcommand(COMMAND_RB,command); 
   
  command.command = BUFFER_QUANT_MODESET_CONV_IN_TRANSFER_LAYERID;
  command.command_data0 = layer_id;
  command.command_data1 = 1;
  host_setcommand(COMMAND_RB,command); 


  //set CB
  command.command = BUFFER_WEIGHT_MODESET_CONV0;
  command.command_data0 = in_h/stride;
  command.command_data1 = in_w/stride;
  host_setcommand(COMMAND_CB,command); 
    
  command.command = BUFFER_WEIGHT_MODESET_CONV1;
  command.command_data0 = CEILDIV(in_ch,ARRAY_HEIGHT);
  command.command_data1 = CEILDIV(out_ch,ARRAY_WIDTH);
  host_setcommand(COMMAND_CB,command); 
  
  command.command = BUFFER_WEIGHT_MODESET_CONV2;
  command.command_data0 = filter_k;
  command.command_data1 = stride;
  host_setcommand(COMMAND_CB,command); 
  
  command.command = BUFFER_WEIGHT_MODESET_CONV4;
  command.command_data0 = addr_from;
  command.command_data1 = addr_to;
  host_setcommand(COMMAND_CB,command); 
  
  command.command = BUFFER_WEIGHT_MODESET_CONV5;
  command.command_data0 = in_ch;
  command.command_data1 = out_ch;
  host_setcommand(COMMAND_CB,command); 
  
  command.command = BUFFER_WEIGHT_MODESET_CONV6;
  command.command_data0 = in_h;
  command.command_data1 = in_w;
  host_setcommand(COMMAND_CB,command); 
  
  command.command = BUFFER_WEIGHT_MODESET_CONV7;
  command.command_data0 = addr_filter;
  command.command_data1 = 0;
  host_setcommand(COMMAND_CB,command); 
    
  command.command = BUFFER_WEIGHT_MODESET_CONV_IN_TRANSFER_LAYERID;
  command.command_data0 = layer_id;
  command.command_data1 = 1;
  host_setcommand(COMMAND_CB,command); 

  // std::cout << "Ws cycle: " << main_cycle <<std::endl;
  Control_WaitforIdle(WAIT_STATE_CB_PEIN);  
  // std::cout << "We cycle: " << main_cycle <<std::endl;
}


void RisaTestBench::Control_Add(
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
) {
  CommandDataPort command;
  command.valid = 1;

  //set CB
  command.command = BUFFER_WEIGHT_MODESET_ADD0;
  command.command_data0 = in_h;
  command.command_data1 = in_w;
  host_setcommand(COMMAND_CB,command); 
    
  command.command = BUFFER_WEIGHT_MODESET_ADD1;
  command.command_data0 = ch;
  command.command_data1 = CEILDIV(ch,ARRAY_WIDTH);
  host_setcommand(COMMAND_CB,command); 
  
  command.command = BUFFER_WEIGHT_MODESET_ADD2;
  command.command_data0 = input_zp0;
  command.command_data1 = input_zp1;
  host_setcommand(COMMAND_CB,command); 
  
  command.command = BUFFER_WEIGHT_MODESET_ADD3;
  command.command_data0 = rescale_int0;
  command.command_data1 = rescale_int1;
  host_setcommand(COMMAND_CB,command); 
  
  command.command = BUFFER_WEIGHT_MODESET_ADD4;
  command.command_data0 = output_zp;
  command.command_data1 = 0;
  host_setcommand(COMMAND_CB,command); 
  
  command.command = BUFFER_WEIGHT_MODESET_ADD5;
  command.command_data0 = addr_from_new;
  command.command_data1 = addr_from_res;
  host_setcommand(COMMAND_CB,command); 
  
  command.command = BUFFER_WEIGHT_MODESET_ADD_LAYERID;
  command.command_data0 = layer_id;
  command.command_data1 = addr_to;
  host_setcommand(COMMAND_CB,command); 

  Control_WaitforIdle(WAIT_STATE_CB_PEIN);  
}

void RisaTestBench::Control_Avg(
  uint32_t  in_h,
  uint32_t  in_w,
  uint32_t  ch,
  uint32_t  input_zp,
  uint32_t  rescale_int,
  uint32_t  output_zp,
  uint32_t  addr_from,
  uint32_t  addr_to,
  uint32_t  layer_id
) {
  CommandDataPort command;
  command.valid = 1;

  //set CB
  command.command = BUFFER_WEIGHT_MODESET_AVG0;
  command.command_data0 = in_h;
  command.command_data1 = in_w;
  host_setcommand(COMMAND_CB,command); 
    
  command.command = BUFFER_WEIGHT_MODESET_AVG1;
  command.command_data0 = ch;
  command.command_data1 = CEILDIV(ch,ARRAY_WIDTH);
  host_setcommand(COMMAND_CB,command); 
  
  command.command = BUFFER_WEIGHT_MODESET_AVG2;
  command.command_data0 = input_zp;
  command.command_data1 = output_zp;
  host_setcommand(COMMAND_CB,command); 
  
  command.command = BUFFER_WEIGHT_MODESET_AVG3;
  command.command_data0 = rescale_int;
  command.command_data1 = 0;
  host_setcommand(COMMAND_CB,command); 
  
  command.command = BUFFER_WEIGHT_MODESET_AVG4;
  command.command_data0 = addr_from;
  command.command_data1 = addr_to;
  host_setcommand(COMMAND_CB,command); 
  
  command.command = BUFFER_WEIGHT_MODESET_AVG_LAYERID;
  command.command_data0 = layer_id;
  command.command_data1 = 0;
  host_setcommand(COMMAND_CB,command); 

  Control_WaitforIdle(WAIT_STATE_CB_PEIN);  
}


struct LAYER {
  uint32_t AXI_WEIGHT_LOAD_ADDR;
  uint32_t AXI_RQ_LOAD_ADDR;
  uint32_t L_FILTER_K;
  uint32_t L_IN_CH;
  uint32_t L_IN_H;
  uint32_t L_IN_W;
  uint32_t L_STRIDE;
  uint32_t L_PADDING;
  int INPUT_ZP0;
  int INPUT_ZP1;
  int OUTPUT_ZP;
  uint32_t ACT;
  uint32_t RESCALE0;
  uint32_t RESCALE1;
  uint32_t DUMMY;
};

LAYER MB[] = {
  (LAYER) {0,                       0,                    0,                  0,                0,              0,               0,                0,                  0,                 0,                  0,                   0,        0,               0,                0}, 
  (LAYER) {AXI_WEIGHT_1_LOAD_ADDR,  AXI_RQ_1_LOAD_ADDR,   L1_CONV_FILTER_K,   L1_CONV_IN_CH,    L1_CONV_IN_H,   L1_CONV_IN_W,    L1_CONV_STRIDE,   L1_CONV_PADDING,    INPUT_ZP_CONV_1,   0,                  OUTPUT_ZP_CONV_1,    ACT_RELU, 0,               0,                0},
  (LAYER) {AXI_WEIGHT_2_LOAD_ADDR,  AXI_RQ_2_LOAD_ADDR,   L2_DCONV_FILTER_K,  L2_DCONV_IN_CH,   L2_DCONV_IN_H,  L2_DCONV_IN_W,   L2_DCONV_STRIDE,  L2_DCONV_PADDING,   INPUT_ZP_DCONV_2,  0,                  OUTPUT_ZP_DCONV_2,   ACT_RELU, 0,               0,                0},
  (LAYER) {AXI_WEIGHT_3_LOAD_ADDR,  AXI_RQ_3_LOAD_ADDR,   L3_CONV_FILTER_K,   L3_CONV_IN_CH,    L3_CONV_IN_H,   L3_CONV_IN_W,    L3_CONV_STRIDE,   L3_CONV_PADDING,    INPUT_ZP_CONV_3,   0,                  OUTPUT_ZP_CONV_3,    ACT_NO,   0,               0,                0},
  (LAYER) {AXI_WEIGHT_4_LOAD_ADDR,  AXI_RQ_4_LOAD_ADDR,   L4_CONV_FILTER_K,   L4_CONV_IN_CH,    L4_CONV_IN_H,   L4_CONV_IN_W,    L4_CONV_STRIDE,   L4_CONV_PADDING,    INPUT_ZP_CONV_4,   0,                  OUTPUT_ZP_CONV_4,    ACT_RELU, 0,               0,                0},
  (LAYER) {AXI_WEIGHT_5_LOAD_ADDR,  AXI_RQ_5_LOAD_ADDR,   L5_DCONV_FILTER_K,  L5_DCONV_IN_CH,   L5_DCONV_IN_H,  L5_DCONV_IN_W,   L5_DCONV_STRIDE,  L5_DCONV_PADDING,   INPUT_ZP_DCONV_5,  0,                  OUTPUT_ZP_DCONV_5,   ACT_RELU, 0,               0,                0},
  (LAYER) {AXI_WEIGHT_6_LOAD_ADDR,  AXI_RQ_6_LOAD_ADDR,   L6_CONV_FILTER_K,   L6_CONV_IN_CH,    L6_CONV_IN_H,   L6_CONV_IN_W,    L6_CONV_STRIDE,   L6_CONV_PADDING,    INPUT_ZP_CONV_6,   0,                  OUTPUT_ZP_CONV_6,    ACT_NO,   0,               0,                0},
  (LAYER) {AXI_WEIGHT_7_LOAD_ADDR,  AXI_RQ_7_LOAD_ADDR,   L7_CONV_FILTER_K,   L7_CONV_IN_CH,    L7_CONV_IN_H,   L7_CONV_IN_W,    L7_CONV_STRIDE,   L7_CONV_PADDING,    INPUT_ZP_CONV_7,   0,                  OUTPUT_ZP_CONV_7,    ACT_RELU, 0,               0,                0},
  (LAYER) {AXI_WEIGHT_8_LOAD_ADDR,  AXI_RQ_8_LOAD_ADDR,   L8_DCONV_FILTER_K,  L8_DCONV_IN_CH,   L8_DCONV_IN_H,  L8_DCONV_IN_W,   L8_DCONV_STRIDE,  L8_DCONV_PADDING,   INPUT_ZP_DCONV_8,  0,                  OUTPUT_ZP_DCONV_8,   0,        0,               0,                0},
  (LAYER) {AXI_WEIGHT_9_LOAD_ADDR,  AXI_RQ_9_LOAD_ADDR,   L9_CONV_FILTER_K,   L9_CONV_IN_CH,    L9_CONV_IN_H,   L9_CONV_IN_W,    L9_CONV_STRIDE,   L9_CONV_PADDING,    INPUT_ZP_CONV_9,   0,                  OUTPUT_ZP_CONV_9,    ACT_NO,   0,               0,                0},
  (LAYER) {0 ,                      0,                    0,                  L10_ADD_IN_CH,    L10_ADD_IN_H,   L10_ADD_IN_W,    0,                0,                  INPUT0_ZP_ADD_10,  INPUT1_ZP_ADD_10,   OUTPUT_ZP_ADD_10,    0,        RESCALE0_ADD_10, RESCALE1_ADD_10,  0},
  (LAYER) {AXI_WEIGHT_11_LOAD_ADDR, AXI_RQ_11_LOAD_ADDR,  L11_CONV_FILTER_K,  L11_CONV_IN_CH,   L11_CONV_IN_H,  L11_CONV_IN_W,   L11_CONV_STRIDE,  L11_CONV_PADDING,   INPUT_ZP_CONV_11,  0,                  OUTPUT_ZP_CONV_11,   ACT_RELU, 0,               0,                0},
  (LAYER) {AXI_WEIGHT_12_LOAD_ADDR, AXI_RQ_12_LOAD_ADDR,  L12_DCONV_FILTER_K, L12_DCONV_IN_CH,  L12_DCONV_IN_H, L12_DCONV_IN_W,  L12_DCONV_STRIDE, L12_DCONV_PADDING,  INPUT_ZP_DCONV_12, 0,                  OUTPUT_ZP_DCONV_12,  ACT_RELU, 0,               0,                0},
  (LAYER) {AXI_WEIGHT_13_LOAD_ADDR, AXI_RQ_13_LOAD_ADDR,  L13_CONV_FILTER_K,  L13_CONV_IN_CH,   L13_CONV_IN_H,  L13_CONV_IN_W,   L13_CONV_STRIDE,  L13_CONV_PADDING,   INPUT_ZP_CONV_13,  0,                  OUTPUT_ZP_CONV_13,   ACT_NO,   0,               0,                0},
  (LAYER) {AXI_WEIGHT_14_LOAD_ADDR, AXI_RQ_14_LOAD_ADDR,  L14_CONV_FILTER_K,  L14_CONV_IN_CH,   L14_CONV_IN_H,  L14_CONV_IN_W,   L14_CONV_STRIDE,  L14_CONV_PADDING,   INPUT_ZP_CONV_14,  0,                  OUTPUT_ZP_CONV_14,   ACT_RELU, 0,               0,                0},
  (LAYER) {AXI_WEIGHT_15_LOAD_ADDR, AXI_RQ_15_LOAD_ADDR,  L15_DCONV_FILTER_K, L15_DCONV_IN_CH,  L15_DCONV_IN_H, L15_DCONV_IN_W,  L15_DCONV_STRIDE, L15_DCONV_PADDING,  INPUT_ZP_DCONV_15, 0,                  OUTPUT_ZP_DCONV_15,  ACT_RELU, 0,               0,                0},
  (LAYER) {AXI_WEIGHT_16_LOAD_ADDR, AXI_RQ_16_LOAD_ADDR,  L16_CONV_FILTER_K,  L16_CONV_IN_CH,   L16_CONV_IN_H,  L16_CONV_IN_W,   L16_CONV_STRIDE,  L16_CONV_PADDING,   INPUT_ZP_CONV_16,  0,                  OUTPUT_ZP_CONV_16,   ACT_NO,   0,               0,                0},
  (LAYER) {0                      , 0,                    0,                  L17_ADD_IN_CH,    L17_ADD_IN_H,   L17_ADD_IN_W,    0,                0,                  INPUT0_ZP_ADD_17,  INPUT1_ZP_ADD_17,   OUTPUT_ZP_ADD_17,    0,        RESCALE0_ADD_17, RESCALE1_ADD_17,  0},
  (LAYER) {AXI_WEIGHT_18_LOAD_ADDR, AXI_RQ_18_LOAD_ADDR,  L18_CONV_FILTER_K,  L18_CONV_IN_CH,   L18_CONV_IN_H,  L18_CONV_IN_W,   L18_CONV_STRIDE,  L18_CONV_PADDING,   INPUT_ZP_CONV_18,  0,                  OUTPUT_ZP_CONV_18,   ACT_RELU, 0,               0,                0},
  (LAYER) {AXI_WEIGHT_19_LOAD_ADDR, AXI_RQ_19_LOAD_ADDR,  L19_DCONV_FILTER_K, L19_DCONV_IN_CH,  L19_DCONV_IN_H, L19_DCONV_IN_W,  L19_DCONV_STRIDE, L19_DCONV_PADDING,  INPUT_ZP_DCONV_19, 0,                  OUTPUT_ZP_DCONV_19,  ACT_RELU, 0,               0,                0},
  (LAYER) {AXI_WEIGHT_20_LOAD_ADDR, AXI_RQ_20_LOAD_ADDR,  L20_CONV_FILTER_K,  L20_CONV_IN_CH,   L20_CONV_IN_H,  L20_CONV_IN_W,   L20_CONV_STRIDE,  L20_CONV_PADDING,   INPUT_ZP_CONV_20,  0,                  OUTPUT_ZP_CONV_20,   ACT_NO,   0,               0,                0},
  (LAYER) {0,                       0,                    0,                  L21_ADD_IN_CH,    L21_ADD_IN_H,   L21_ADD_IN_W,    0,                0,                  INPUT0_ZP_ADD_21,  INPUT1_ZP_ADD_21,   OUTPUT_ZP_ADD_21,    0,        RESCALE0_ADD_21, RESCALE1_ADD_21,  0},
  (LAYER) {AXI_WEIGHT_22_LOAD_ADDR, AXI_RQ_22_LOAD_ADDR,  L22_CONV_FILTER_K,  L22_CONV_IN_CH,   L22_CONV_IN_H,  L22_CONV_IN_W,   L22_CONV_STRIDE,  L22_CONV_PADDING,   INPUT_ZP_CONV_22,  0,                  OUTPUT_ZP_CONV_22,   ACT_RELU, 0,               0,                0},
  (LAYER) {AXI_WEIGHT_23_LOAD_ADDR, AXI_RQ_23_LOAD_ADDR,  L23_DCONV_FILTER_K, L23_DCONV_IN_CH,  L23_DCONV_IN_H, L23_DCONV_IN_W,  L23_DCONV_STRIDE, L23_DCONV_PADDING,  INPUT_ZP_DCONV_23, 0,                  OUTPUT_ZP_DCONV_23,  ACT_RELU, 0,               0,                0},
  (LAYER) {AXI_WEIGHT_24_LOAD_ADDR, AXI_RQ_24_LOAD_ADDR,  L24_CONV_FILTER_K,  L24_CONV_IN_CH,   L24_CONV_IN_H,  L24_CONV_IN_W,   L24_CONV_STRIDE,  L24_CONV_PADDING,   INPUT_ZP_CONV_24,  0,                  OUTPUT_ZP_CONV_24,   ACT_NO,   0,               0,                0},
  (LAYER) {AXI_WEIGHT_25_LOAD_ADDR, AXI_RQ_25_LOAD_ADDR,  L25_CONV_FILTER_K,  L25_CONV_IN_CH,   L25_CONV_IN_H,  L25_CONV_IN_W,   L25_CONV_STRIDE,  L25_CONV_PADDING,   INPUT_ZP_CONV_25,  0,                  OUTPUT_ZP_CONV_25,   ACT_RELU, 0,               0,                0},
  (LAYER) {AXI_WEIGHT_26_LOAD_ADDR, AXI_RQ_26_LOAD_ADDR,  L26_DCONV_FILTER_K, L26_DCONV_IN_CH,  L26_DCONV_IN_H, L26_DCONV_IN_W,  L26_DCONV_STRIDE, L26_DCONV_PADDING,  INPUT_ZP_DCONV_26, 0,                  OUTPUT_ZP_DCONV_26,  ACT_RELU, 0,               0,                0},
  (LAYER) {AXI_WEIGHT_27_LOAD_ADDR, AXI_RQ_27_LOAD_ADDR,  L27_CONV_FILTER_K,  L27_CONV_IN_CH,   L27_CONV_IN_H,  L27_CONV_IN_W,   L27_CONV_STRIDE,  L27_CONV_PADDING,   INPUT_ZP_CONV_27,  0,                  OUTPUT_ZP_CONV_27,   ACT_NO,   0,               0,                0},
  (LAYER) {0,                       0,                    0,                  L28_ADD_IN_CH,    L28_ADD_IN_H,   L28_ADD_IN_W,    0,                0,                  INPUT0_ZP_ADD_28,  INPUT1_ZP_ADD_28,   OUTPUT_ZP_ADD_28,    0,        RESCALE0_ADD_28, RESCALE1_ADD_28,  0},
  (LAYER) {AXI_WEIGHT_29_LOAD_ADDR, AXI_RQ_29_LOAD_ADDR,  L29_CONV_FILTER_K,  L29_CONV_IN_CH,   L29_CONV_IN_H,  L29_CONV_IN_W,   L29_CONV_STRIDE,  L29_CONV_PADDING,   INPUT_ZP_CONV_29,  0,                  OUTPUT_ZP_CONV_29,   ACT_RELU, 0,               0,                0},
  (LAYER) {AXI_WEIGHT_30_LOAD_ADDR, AXI_RQ_30_LOAD_ADDR,  L30_DCONV_FILTER_K, L30_DCONV_IN_CH,  L30_DCONV_IN_H, L30_DCONV_IN_W,  L30_DCONV_STRIDE, L30_DCONV_PADDING,  INPUT_ZP_DCONV_30, 0,                  OUTPUT_ZP_DCONV_30,  ACT_RELU, 0,               0,                0},
  (LAYER) {AXI_WEIGHT_31_LOAD_ADDR, AXI_RQ_31_LOAD_ADDR,  L31_CONV_FILTER_K,  L31_CONV_IN_CH,   L31_CONV_IN_H,  L31_CONV_IN_W,   L31_CONV_STRIDE,  L31_CONV_PADDING,   INPUT_ZP_CONV_31,  0,                  OUTPUT_ZP_CONV_31,   ACT_NO,   0,               0,                0},
  (LAYER) {0,                       0,                    0,                  L32_ADD_IN_CH,    L32_ADD_IN_H,   L32_ADD_IN_W,    0,                0,                  INPUT0_ZP_ADD_32,  INPUT1_ZP_ADD_32,   OUTPUT_ZP_ADD_32,    0,        RESCALE0_ADD_32, RESCALE1_ADD_32,  0},
  (LAYER) {AXI_WEIGHT_33_LOAD_ADDR, AXI_RQ_33_LOAD_ADDR,  L33_CONV_FILTER_K,  L33_CONV_IN_CH,   L33_CONV_IN_H,  L33_CONV_IN_W,   L33_CONV_STRIDE,  L33_CONV_PADDING,   INPUT_ZP_CONV_33,  0,                  OUTPUT_ZP_CONV_33,   ACT_RELU, 0,               0,                0},
  (LAYER) {AXI_WEIGHT_34_LOAD_ADDR, AXI_RQ_34_LOAD_ADDR,  L34_DCONV_FILTER_K, L34_DCONV_IN_CH,  L34_DCONV_IN_H, L34_DCONV_IN_W,  L34_DCONV_STRIDE, L34_DCONV_PADDING,  INPUT_ZP_DCONV_34, 0,                  OUTPUT_ZP_DCONV_34,  ACT_RELU, 0,               0,                0},
  (LAYER) {AXI_WEIGHT_35_LOAD_ADDR, AXI_RQ_35_LOAD_ADDR,  L35_CONV_FILTER_K,  L35_CONV_IN_CH,   L35_CONV_IN_H,  L35_CONV_IN_W,   L35_CONV_STRIDE,  L35_CONV_PADDING,   INPUT_ZP_CONV_35,  0,                  OUTPUT_ZP_CONV_35,   ACT_NO,   0,               0,                0},
  (LAYER) {0,                       0,                    0,                  L36_ADD_IN_CH,    L36_ADD_IN_H,   L36_ADD_IN_W,    0,                0,                  INPUT0_ZP_ADD_36,  INPUT1_ZP_ADD_36,   OUTPUT_ZP_ADD_36,    0,        RESCALE0_ADD_36, RESCALE1_ADD_36,  0},
  (LAYER) {AXI_WEIGHT_37_LOAD_ADDR, AXI_RQ_37_LOAD_ADDR,  L37_CONV_FILTER_K,  L37_CONV_IN_CH,   L37_CONV_IN_H,  L37_CONV_IN_W,   L37_CONV_STRIDE,  L37_CONV_PADDING,   INPUT_ZP_CONV_37,  0,                  OUTPUT_ZP_CONV_37,   ACT_RELU, 0,               0,                0},
  (LAYER) {AXI_WEIGHT_38_LOAD_ADDR, AXI_RQ_38_LOAD_ADDR,  L38_DCONV_FILTER_K, L38_DCONV_IN_CH,  L38_DCONV_IN_H, L38_DCONV_IN_W,  L38_DCONV_STRIDE, L38_DCONV_PADDING,  INPUT_ZP_DCONV_38, 0,                  OUTPUT_ZP_DCONV_38,  ACT_RELU, 0,               0,                0},
  (LAYER) {AXI_WEIGHT_39_LOAD_ADDR, AXI_RQ_39_LOAD_ADDR,  L39_CONV_FILTER_K,  L39_CONV_IN_CH,   L39_CONV_IN_H,  L39_CONV_IN_W,   L39_CONV_STRIDE,  L39_CONV_PADDING,   INPUT_ZP_CONV_39,  0,                  OUTPUT_ZP_CONV_39,   ACT_NO,   0,               0,                0},
  (LAYER) {AXI_WEIGHT_40_LOAD_ADDR, AXI_RQ_40_LOAD_ADDR,  L40_CONV_FILTER_K,  L40_CONV_IN_CH,   L40_CONV_IN_H,  L40_CONV_IN_W,   L40_CONV_STRIDE,  L40_CONV_PADDING,   INPUT_ZP_CONV_40,  0,                  OUTPUT_ZP_CONV_40,   ACT_RELU, 0,               0,                0},
  (LAYER) {AXI_WEIGHT_41_LOAD_ADDR, AXI_RQ_41_LOAD_ADDR,  L41_DCONV_FILTER_K, L41_DCONV_IN_CH,  L41_DCONV_IN_H, L41_DCONV_IN_W,  L41_DCONV_STRIDE, L41_DCONV_PADDING,  INPUT_ZP_DCONV_41, 0,                  OUTPUT_ZP_DCONV_41,  ACT_RELU, 0,               0,                0},
  (LAYER) {AXI_WEIGHT_42_LOAD_ADDR, AXI_RQ_42_LOAD_ADDR,  L42_CONV_FILTER_K,  L42_CONV_IN_CH,   L42_CONV_IN_H,  L42_CONV_IN_W,   L42_CONV_STRIDE,  L42_CONV_PADDING,   INPUT_ZP_CONV_42,  0,                  OUTPUT_ZP_CONV_42,   ACT_NO,   0,               0,                0},
  (LAYER) {0,                       0,                    0,                  L43_ADD_IN_CH,    L43_ADD_IN_H,   L43_ADD_IN_W,    0,                0,                  INPUT0_ZP_ADD_43,  INPUT1_ZP_ADD_43,   OUTPUT_ZP_ADD_43,    0,        RESCALE0_ADD_43, RESCALE1_ADD_43,  0},
  (LAYER) {AXI_WEIGHT_44_LOAD_ADDR, AXI_RQ_44_LOAD_ADDR,  L44_CONV_FILTER_K,  L44_CONV_IN_CH,   L44_CONV_IN_H,  L44_CONV_IN_W,   L44_CONV_STRIDE,  L44_CONV_PADDING,   INPUT_ZP_CONV_44,  0,                  OUTPUT_ZP_CONV_44,   ACT_RELU, 0,               0,                0},
  (LAYER) {AXI_WEIGHT_45_LOAD_ADDR, AXI_RQ_45_LOAD_ADDR,  L45_DCONV_FILTER_K, L45_DCONV_IN_CH,  L45_DCONV_IN_H, L45_DCONV_IN_W,  L45_DCONV_STRIDE, L45_DCONV_PADDING,  INPUT_ZP_DCONV_45, 0,                  OUTPUT_ZP_DCONV_45,  ACT_RELU, 0,               0,                0},
  (LAYER) {AXI_WEIGHT_46_LOAD_ADDR, AXI_RQ_46_LOAD_ADDR,  L46_CONV_FILTER_K,  L46_CONV_IN_CH,   L46_CONV_IN_H,  L46_CONV_IN_W,   L46_CONV_STRIDE,  L46_CONV_PADDING,   INPUT_ZP_CONV_46,  0,                  OUTPUT_ZP_CONV_46,   ACT_NO,   0,               0,                0},
  (LAYER) {0,                       0,                    0,                  L47_ADD_IN_CH,    L47_ADD_IN_H,   L47_ADD_IN_W,    0,                0,                  INPUT0_ZP_ADD_47,  INPUT1_ZP_ADD_47,   OUTPUT_ZP_ADD_47,    0,        RESCALE0_ADD_47, RESCALE1_ADD_47,  0},
  (LAYER) {AXI_WEIGHT_48_LOAD_ADDR, AXI_RQ_48_LOAD_ADDR,  L48_CONV_FILTER_K,  L48_CONV_IN_CH,   L48_CONV_IN_H,  L48_CONV_IN_W,   L48_CONV_STRIDE,  L48_CONV_PADDING,   INPUT_ZP_CONV_48,  0,                  OUTPUT_ZP_CONV_48,   ACT_RELU, 0,               0,                0},
  (LAYER) {AXI_WEIGHT_49_LOAD_ADDR, AXI_RQ_49_LOAD_ADDR,  L49_DCONV_FILTER_K, L49_DCONV_IN_CH,  L49_DCONV_IN_H, L49_DCONV_IN_W,  L49_DCONV_STRIDE, L49_DCONV_PADDING,  INPUT_ZP_DCONV_49, 0,                  OUTPUT_ZP_DCONV_49,  ACT_RELU, 0,               0,                0},
  (LAYER) {AXI_WEIGHT_50_LOAD_ADDR, AXI_RQ_50_LOAD_ADDR,  L50_CONV_FILTER_K,  L50_CONV_IN_CH,   L50_CONV_IN_H,  L50_CONV_IN_W,   L50_CONV_STRIDE,  L50_CONV_PADDING,   INPUT_ZP_CONV_50,  0,                  OUTPUT_ZP_CONV_50,   ACT_NO,   0,               0,                0},
  (LAYER) {AXI_WEIGHT_51_LOAD_ADDR, AXI_RQ_51_LOAD_ADDR,  L51_CONV_FILTER_K,  L51_CONV_IN_CH,   L51_CONV_IN_H,  L51_CONV_IN_W,   L51_CONV_STRIDE,  L51_CONV_PADDING,   INPUT_ZP_CONV_51,  0,                  OUTPUT_ZP_CONV_51,   ACT_RELU, 0,               0,                0},
  (LAYER) {AXI_WEIGHT_52_LOAD_ADDR, AXI_RQ_52_LOAD_ADDR,  L52_DCONV_FILTER_K, L52_DCONV_IN_CH,  L52_DCONV_IN_H, L52_DCONV_IN_W,  L52_DCONV_STRIDE, L52_DCONV_PADDING,  INPUT_ZP_DCONV_52, 0,                  OUTPUT_ZP_DCONV_52,  ACT_RELU, 0,               0,                0},
  (LAYER) {AXI_WEIGHT_53_LOAD_ADDR, AXI_RQ_53_LOAD_ADDR,  L53_CONV_FILTER_K,  L53_CONV_IN_CH,   L53_CONV_IN_H,  L53_CONV_IN_W,   L53_CONV_STRIDE,  L53_CONV_PADDING,   INPUT_ZP_CONV_53,  0,                  OUTPUT_ZP_CONV_53,   ACT_NO,   0,               0,                0},
  (LAYER) {0,                       0,                    0,                  L54_ADD_IN_CH,    L54_ADD_IN_H,   L54_ADD_IN_W,    0,                0,                  INPUT0_ZP_ADD_54,  INPUT1_ZP_ADD_54,   OUTPUT_ZP_ADD_54,    0,        RESCALE0_ADD_54, RESCALE1_ADD_54,  0},
  (LAYER) {AXI_WEIGHT_55_LOAD_ADDR, AXI_RQ_55_LOAD_ADDR,  L55_CONV_FILTER_K,  L55_CONV_IN_CH,   L55_CONV_IN_H,  L55_CONV_IN_W,   L55_CONV_STRIDE,  L55_CONV_PADDING,   INPUT_ZP_CONV_55,  0,                  OUTPUT_ZP_CONV_55,   ACT_RELU, 0,               0,                0},
  (LAYER) {AXI_WEIGHT_56_LOAD_ADDR, AXI_RQ_56_LOAD_ADDR,  L56_DCONV_FILTER_K, L56_DCONV_IN_CH,  L56_DCONV_IN_H, L56_DCONV_IN_W,  L56_DCONV_STRIDE, L56_DCONV_PADDING,  INPUT_ZP_DCONV_56, 0,                  OUTPUT_ZP_DCONV_56,  ACT_RELU, 0,               0,                0},
  (LAYER) {AXI_WEIGHT_57_LOAD_ADDR, AXI_RQ_57_LOAD_ADDR,  L57_CONV_FILTER_K,  L57_CONV_IN_CH,   L57_CONV_IN_H,  L57_CONV_IN_W,   L57_CONV_STRIDE,  L57_CONV_PADDING,   INPUT_ZP_CONV_57,  0,                  OUTPUT_ZP_CONV_57,   ACT_NO,   0,               0,                0},
  (LAYER) {0,                       0,                    0,                  L58_ADD_IN_CH,    L58_ADD_IN_H,   L58_ADD_IN_W,    0,                0,                  INPUT0_ZP_ADD_58,  INPUT1_ZP_ADD_58,   OUTPUT_ZP_ADD_58,    0,        RESCALE0_ADD_58, RESCALE1_ADD_58,  0},
  (LAYER) {AXI_WEIGHT_59_LOAD_ADDR, AXI_RQ_59_LOAD_ADDR,  L59_CONV_FILTER_K,  L59_CONV_IN_CH,   L59_CONV_IN_H,  L59_CONV_IN_W,   L59_CONV_STRIDE,  L59_CONV_PADDING,   INPUT_ZP_CONV_59,  0,                  OUTPUT_ZP_CONV_59,   ACT_RELU, 0,               0,                0},
  (LAYER) {AXI_WEIGHT_60_LOAD_ADDR, AXI_RQ_60_LOAD_ADDR,  L60_DCONV_FILTER_K, L60_DCONV_IN_CH,  L60_DCONV_IN_H, L60_DCONV_IN_W,  L60_DCONV_STRIDE, L60_DCONV_PADDING,  INPUT_ZP_DCONV_60, 0,                  OUTPUT_ZP_DCONV_60,  ACT_RELU, 0,               0,                0},
  (LAYER) {AXI_WEIGHT_61_LOAD_ADDR, AXI_RQ_61_LOAD_ADDR,  L61_CONV_FILTER_K,  L61_CONV_IN_CH,   L61_CONV_IN_H,  L61_CONV_IN_W,   L61_CONV_STRIDE,  L61_CONV_PADDING,   INPUT_ZP_CONV_61,  0,                  OUTPUT_ZP_CONV_61,   ACT_NO,   0,               0,                0},
  (LAYER) {AXI_WEIGHT_62_LOAD_ADDR, AXI_RQ_62_LOAD_ADDR,  L62_CONV_FILTER_K,  L62_CONV_IN_CH,   L62_CONV_IN_H,  L62_CONV_IN_W,   L62_CONV_STRIDE,  L62_CONV_PADDING,   INPUT_ZP_CONV_62,  0,                  OUTPUT_ZP_CONV_62,   ACT_RELU, 0,               0,                0},
  (LAYER) {0,                       0,                    0,                  L63_AVG_IN_CH,    L63_AVG_IN_H,   L63_AVG_IN_W,    0,                0,                  INPUT_ZP_AVG_63,   0,                  OUTPUT_ZP_AVG_63,    0,        RESCALE_AVG_63,  0,                0},
  (LAYER) {AXI_WEIGHT_64_LOAD_ADDR, AXI_RQ_64_LOAD_ADDR,  L64_CONV_FILTER_K,  L64_CONV_IN_CH,   L64_CONV_IN_H,  L64_CONV_IN_W,   L64_CONV_STRIDE,  L64_CONV_PADDING,   INPUT_ZP_CONV_64,  0,                  OUTPUT_ZP_CONV_64,   ACT_NO,   0,               0,                0},
  (LAYER) {0,                       0,                    0,                  L65_CONV_IN_CH,   L65_CONV_IN_H,  L65_CONV_IN_W,   0,                0,                  0,                 0,                  0,                   0,        0,               0,                0}

};

void RisaTestBench::Control_In_Transfer_Conv_Sequence(int lid, uint32_t in_buf_addr,  uint32_t out_buf_addr, uint32_t weight_addr)  {
  LAYER l,nl;
  l = MB[lid];
  nl = MB[lid+1];

  Control_Load(l.AXI_WEIGHT_LOAD_ADDR,l.L_IN_CH*l.L_FILTER_K*l.L_FILTER_K*CEILDIV(nl.L_IN_CH,ARRAY_WIDTH)*ARRAY_WIDTH,weight_addr);      
  Control_LoadRQ(l.AXI_RQ_LOAD_ADDR,nl.L_IN_CH);
  Control_ConvInTransfer(l.L_IN_H,l.L_IN_W,l.L_IN_CH,nl.L_IN_CH,l.L_FILTER_K,l.L_STRIDE,l.L_PADDING,l.INPUT_ZP0,l.OUTPUT_ZP,in_buf_addr,out_buf_addr,weight_addr,lid,l.ACT);
}


void RisaTestBench::Control_Dconv_Sequence(int lid, uint32_t in_buf_addr,  uint32_t out_buf_addr, uint32_t weight_addr)  {
  LAYER l,nl;
  l = MB[lid];
  nl = MB[lid+1];

  Control_Load(l.AXI_WEIGHT_LOAD_ADDR,l.L_FILTER_K*l.L_FILTER_K*CEILDIV(nl.L_IN_CH,ARRAY_WIDTH)*ARRAY_WIDTH,weight_addr);              
  Control_LoadRQ(l.AXI_RQ_LOAD_ADDR,nl.L_IN_CH);        
  Control_Dconv(l.L_IN_H,l.L_IN_W,nl.L_IN_CH,l.L_FILTER_K,l.L_STRIDE,l.L_PADDING,l.INPUT_ZP0,l.OUTPUT_ZP,in_buf_addr,out_buf_addr,weight_addr,lid,l.ACT);
}


void RisaTestBench::Control_Add_Sequence(int lid, uint32_t in_buf0_addr,  uint32_t in_buf1_addr, uint32_t out_buf_addr)  {
  LAYER l;
  l = MB[lid];
  Control_Add(l.L_IN_H,l.L_IN_W,l.L_IN_CH,l.INPUT_ZP0,l.INPUT_ZP1,l.RESCALE0,l.RESCALE1,l.OUTPUT_ZP,in_buf0_addr,in_buf1_addr,out_buf_addr,lid,l.ACT);
}

void RisaTestBench::Control_Avg_Sequence(int lid, uint32_t in_buf_addr,  uint32_t out_buf_addr)  {
  LAYER l;
  l = MB[lid];
  Control_Avg(l.L_IN_H,l.L_IN_W,l.L_IN_CH,l.INPUT_ZP0,l.RESCALE0,l.OUTPUT_ZP,in_buf_addr,out_buf_addr,lid);
}


void RisaTestBench::host_function()  {
  // std::cout << "hello from member function" << std::endl;
  CommandDataPort command;

  usleep(10000);

  command.valid = 1;  
  command.command = BUFFER_QUANT_MODESET_PE_RESET;
  host_setcommand(COMMAND_RB,command);

  usleep(10000);

  Control_Load(AXI_IN_FMAP_LOAD_ADDR, L1_CONV_FILTER_K*L1_CONV_FILTER_K*IN_FMAP_CH*IN_FMAP_H*IN_FMAP_W_MEM , BUFFER_WEIGHT_FMAP_ADDR0);      
  
  Control_TrTransfer(IN_FMAP_CH * L1_CONV_FILTER_K * L1_CONV_FILTER_K, 1, IN_FMAP_H, CEILDIV(IN_FMAP_W,ARRAY_WIDTH), IN_FMAP_W % ARRAY_WIDTH,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_QUANT_FMAP_ADDR0,1);

  Control_Load(AXI_WEIGHT_1_LOAD_ADDR,L1_CONV_IN_CH*L1_CONV_FILTER_K*L1_CONV_FILTER_K*CEILDIV(L2_DCONV_IN_CH,ARRAY_WIDTH)*ARRAY_WIDTH,BUFFER_WEIGHT_BUFFER_ADDR0);      

  Control_LoadRQ(AXI_RQ_1_LOAD_ADDR,L2_DCONV_IN_CH);      

  Control_IConv(L1_CONV_IN_H,L1_CONV_IN_W,L1_CONV_IN_CH,L2_DCONV_IN_CH,L1_CONV_FILTER_K,L1_CONV_STRIDE,L1_CONV_PADDING,INPUT_ZP_CONV_1,OUTPUT_ZP_CONV_1,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_BUFFER_ADDR0,1,ACT_RELU);

  // Control_Dump(BUFFER_WEIGHT_FMAP_ADDR1, L2_DCONV_IN_W * L2_DCONV_IN_H * CEILDIV(L2_DCONV_IN_CH,ARRAY_WIDTH));
  std::cout << "Input conv 1 done" << std::endl;

  Control_Dconv_Sequence(2,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_BUFFER_ADDR1);
  Control_In_Transfer_Conv_Sequence(3,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_BUFFER_ADDR0);
  Control_In_Transfer_Conv_Sequence(4,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_BUFFER_ADDR1);
  Control_Dconv_Sequence(5,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_BUFFER_ADDR0);
  Control_In_Transfer_Conv_Sequence(6,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_BUFFER_ADDR1);
  Control_In_Transfer_Conv_Sequence(7,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_BUFFER_ADDR0);
  Control_Dconv_Sequence(8,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_FMAP_ADDR2,BUFFER_WEIGHT_BUFFER_ADDR1);
  Control_In_Transfer_Conv_Sequence(9,BUFFER_WEIGHT_FMAP_ADDR2,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_BUFFER_ADDR0);
  Control_Add_Sequence(10,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_FMAP_ADDR1);
  Control_In_Transfer_Conv_Sequence(11,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_BUFFER_ADDR1);
  Control_Dconv_Sequence(12,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_BUFFER_ADDR0);
  Control_In_Transfer_Conv_Sequence(13,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_BUFFER_ADDR1);
  Control_In_Transfer_Conv_Sequence(14,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_BUFFER_ADDR0);
  Control_Dconv_Sequence(15,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_FMAP_ADDR2,BUFFER_WEIGHT_BUFFER_ADDR1);
  Control_In_Transfer_Conv_Sequence(16,BUFFER_WEIGHT_FMAP_ADDR2,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_BUFFER_ADDR0);
  Control_Add_Sequence(17,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_FMAP_ADDR0);
  Control_In_Transfer_Conv_Sequence(18,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_BUFFER_ADDR1);
  Control_Dconv_Sequence(19,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_FMAP_ADDR2,BUFFER_WEIGHT_BUFFER_ADDR0);
  Control_In_Transfer_Conv_Sequence(20,BUFFER_WEIGHT_FMAP_ADDR2,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_BUFFER_ADDR1);
  Control_Add_Sequence(21,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_FMAP_ADDR0);



  Control_In_Transfer_Conv_Sequence(22,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_BUFFER_ADDR0);
  Control_Dconv_Sequence(23,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_BUFFER_ADDR1);
  Control_In_Transfer_Conv_Sequence(24,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_BUFFER_ADDR0);
  Control_In_Transfer_Conv_Sequence(25,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_BUFFER_ADDR1);
  Control_Dconv_Sequence(26,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_FMAP_ADDR2,BUFFER_WEIGHT_BUFFER_ADDR0);
  Control_In_Transfer_Conv_Sequence(27,BUFFER_WEIGHT_FMAP_ADDR2,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_BUFFER_ADDR1);
  Control_Add_Sequence(28,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_FMAP_ADDR0);
  Control_In_Transfer_Conv_Sequence(29,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_BUFFER_ADDR0);
  Control_Dconv_Sequence(30,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_FMAP_ADDR2,BUFFER_WEIGHT_BUFFER_ADDR1);
  Control_In_Transfer_Conv_Sequence(31,BUFFER_WEIGHT_FMAP_ADDR2,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_BUFFER_ADDR0);
  Control_Add_Sequence(32,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_FMAP_ADDR0);
  Control_In_Transfer_Conv_Sequence(33,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_BUFFER_ADDR1);
  Control_Dconv_Sequence(34,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_FMAP_ADDR2,BUFFER_WEIGHT_BUFFER_ADDR0);
  Control_In_Transfer_Conv_Sequence(35,BUFFER_WEIGHT_FMAP_ADDR2,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_BUFFER_ADDR1);
  Control_Add_Sequence(36,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_FMAP_ADDR0);

  Control_In_Transfer_Conv_Sequence(37,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_BUFFER_ADDR0);
  Control_Dconv_Sequence(38,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_BUFFER_ADDR1);
  Control_In_Transfer_Conv_Sequence(39,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_BUFFER_ADDR0);
  Control_In_Transfer_Conv_Sequence(40,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_BUFFER_ADDR1);
  Control_Dconv_Sequence(41,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_FMAP_ADDR2,BUFFER_WEIGHT_BUFFER_ADDR0);
  Control_In_Transfer_Conv_Sequence(42,BUFFER_WEIGHT_FMAP_ADDR2,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_BUFFER_ADDR1);
  Control_Add_Sequence(43,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_FMAP_ADDR0);
  Control_In_Transfer_Conv_Sequence(44,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_BUFFER_ADDR0);
  Control_Dconv_Sequence(45,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_FMAP_ADDR2,BUFFER_WEIGHT_BUFFER_ADDR1);
  Control_In_Transfer_Conv_Sequence(46,BUFFER_WEIGHT_FMAP_ADDR2,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_BUFFER_ADDR0);
  Control_Add_Sequence(47,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_FMAP_ADDR0);
  
  Control_In_Transfer_Conv_Sequence(48,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_BUFFER_ADDR1);
  Control_Dconv_Sequence(49,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_BUFFER_ADDR0);
  Control_In_Transfer_Conv_Sequence(50,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_BUFFER_ADDR1);
  Control_In_Transfer_Conv_Sequence(51,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_BUFFER_ADDR0);
  Control_Dconv_Sequence(52,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_FMAP_ADDR2,BUFFER_WEIGHT_BUFFER_ADDR1);
  Control_In_Transfer_Conv_Sequence(53,BUFFER_WEIGHT_FMAP_ADDR2,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_BUFFER_ADDR0);
  Control_Add_Sequence(54,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_FMAP_ADDR0);
  Control_In_Transfer_Conv_Sequence(55,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_BUFFER_ADDR1);
  Control_Dconv_Sequence(56,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_FMAP_ADDR2,BUFFER_WEIGHT_BUFFER_ADDR0);
  Control_In_Transfer_Conv_Sequence(57,BUFFER_WEIGHT_FMAP_ADDR2,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_BUFFER_ADDR1);
  Control_Add_Sequence(58,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_FMAP_ADDR0);

  Control_In_Transfer_Conv_Sequence(59,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_BUFFER_ADDR0);
  Control_Dconv_Sequence(60,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_BUFFER_ADDR1);
  Control_In_Transfer_Conv_Sequence(61,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_BUFFER_ADDR0);
  Control_In_Transfer_Conv_Sequence(62,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_BUFFER_ADDR1);

  Control_Avg_Sequence(63,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_FMAP_ADDR1);

  Control_In_Transfer_Conv_Sequence(64,BUFFER_WEIGHT_FMAP_ADDR1,BUFFER_WEIGHT_FMAP_ADDR0,BUFFER_WEIGHT_BUFFER_ADDR0);

  Control_Dump(BUFFER_WEIGHT_FMAP_ADDR0, MB[65].L_IN_W * MB[65].L_IN_H * CEILDIV(MB[65].L_IN_CH,ARRAY_WIDTH));


  std::cout << "conv 65 done" << std::endl;
  
  // `CONTROL_AVG_EVEN_ODD(63,64,STATE_LOAD_RQ_CONV64)

  // `CONTROL_IN_TRANSFER_CONV_ODD_EVEN_EVEN_NO_LOAD(64,ACT_NO,65,CONV,STATE_LOAD_RQ_CONV65)
    
    



  host_setcommand(COMMAND_STOP,command);  

}




void RisaTestBench::prepare_ext_data() {
  load_ext_data(AXI_IN_FMAP_LOAD_ADDR,"dat/converted_in00000001.dat");
  // load_ext_data(AXI_IN_FMAP_LOAD_ADDR,"dump/output_dconv2.dat");

  load_ext_data(AXI_WEIGHT_1_LOAD_ADDR,"dat/converted_weight_conv_1");
  load_ext_data(AXI_WEIGHT_2_LOAD_ADDR,"dat/converted_weight_conv_2");
  load_ext_data(AXI_WEIGHT_3_LOAD_ADDR,"dat/converted_weight_conv_3");
  load_ext_data(AXI_WEIGHT_4_LOAD_ADDR,"dat/converted_weight_conv_4");
  load_ext_data(AXI_WEIGHT_5_LOAD_ADDR,"dat/converted_weight_conv_5");
  load_ext_data(AXI_WEIGHT_6_LOAD_ADDR,"dat/converted_weight_conv_6");
  load_ext_data(AXI_WEIGHT_7_LOAD_ADDR,"dat/converted_weight_conv_7");
  load_ext_data(AXI_WEIGHT_8_LOAD_ADDR,"dat/converted_weight_conv_8");
  load_ext_data(AXI_WEIGHT_9_LOAD_ADDR,"dat/converted_weight_conv_9");
  load_ext_data(AXI_WEIGHT_11_LOAD_ADDR,"dat/converted_weight_conv_11");
  load_ext_data(AXI_WEIGHT_12_LOAD_ADDR,"dat/converted_weight_conv_12");
  load_ext_data(AXI_WEIGHT_13_LOAD_ADDR,"dat/converted_weight_conv_13");
  load_ext_data(AXI_WEIGHT_14_LOAD_ADDR,"dat/converted_weight_conv_14");
  load_ext_data(AXI_WEIGHT_15_LOAD_ADDR,"dat/converted_weight_conv_15");
  load_ext_data(AXI_WEIGHT_16_LOAD_ADDR,"dat/converted_weight_conv_16");
  load_ext_data(AXI_WEIGHT_18_LOAD_ADDR,"dat/converted_weight_conv_18");
  load_ext_data(AXI_WEIGHT_19_LOAD_ADDR,"dat/converted_weight_conv_19");
  load_ext_data(AXI_WEIGHT_20_LOAD_ADDR,"dat/converted_weight_conv_20");
  load_ext_data(AXI_WEIGHT_22_LOAD_ADDR,"dat/converted_weight_conv_22");
  load_ext_data(AXI_WEIGHT_23_LOAD_ADDR,"dat/converted_weight_conv_23");
  load_ext_data(AXI_WEIGHT_24_LOAD_ADDR,"dat/converted_weight_conv_24");
  load_ext_data(AXI_WEIGHT_25_LOAD_ADDR,"dat/converted_weight_conv_25");
  load_ext_data(AXI_WEIGHT_26_LOAD_ADDR,"dat/converted_weight_conv_26");
  load_ext_data(AXI_WEIGHT_27_LOAD_ADDR,"dat/converted_weight_conv_27");
  load_ext_data(AXI_WEIGHT_29_LOAD_ADDR,"dat/converted_weight_conv_29");
  load_ext_data(AXI_WEIGHT_30_LOAD_ADDR,"dat/converted_weight_conv_30");
  load_ext_data(AXI_WEIGHT_31_LOAD_ADDR,"dat/converted_weight_conv_31");
  load_ext_data(AXI_WEIGHT_33_LOAD_ADDR,"dat/converted_weight_conv_33");
  load_ext_data(AXI_WEIGHT_34_LOAD_ADDR,"dat/converted_weight_conv_34");
  load_ext_data(AXI_WEIGHT_35_LOAD_ADDR,"dat/converted_weight_conv_35");
  load_ext_data(AXI_WEIGHT_37_LOAD_ADDR,"dat/converted_weight_conv_37");
  load_ext_data(AXI_WEIGHT_38_LOAD_ADDR,"dat/converted_weight_conv_38");
  load_ext_data(AXI_WEIGHT_39_LOAD_ADDR,"dat/converted_weight_conv_39");
  load_ext_data(AXI_WEIGHT_40_LOAD_ADDR,"dat/converted_weight_conv_40");
  load_ext_data(AXI_WEIGHT_41_LOAD_ADDR,"dat/converted_weight_conv_41");
  load_ext_data(AXI_WEIGHT_42_LOAD_ADDR,"dat/converted_weight_conv_42");
  load_ext_data(AXI_WEIGHT_44_LOAD_ADDR,"dat/converted_weight_conv_44");
  load_ext_data(AXI_WEIGHT_45_LOAD_ADDR,"dat/converted_weight_conv_45");
  load_ext_data(AXI_WEIGHT_46_LOAD_ADDR,"dat/converted_weight_conv_46");
  load_ext_data(AXI_WEIGHT_48_LOAD_ADDR,"dat/converted_weight_conv_48");
  load_ext_data(AXI_WEIGHT_49_LOAD_ADDR,"dat/converted_weight_conv_49");
  load_ext_data(AXI_WEIGHT_50_LOAD_ADDR,"dat/converted_weight_conv_50");
  load_ext_data(AXI_WEIGHT_51_LOAD_ADDR,"dat/converted_weight_conv_51");
  load_ext_data(AXI_WEIGHT_52_LOAD_ADDR,"dat/converted_weight_conv_52");
  load_ext_data(AXI_WEIGHT_53_LOAD_ADDR,"dat/converted_weight_conv_53");
  load_ext_data(AXI_WEIGHT_55_LOAD_ADDR,"dat/converted_weight_conv_55");
  load_ext_data(AXI_WEIGHT_56_LOAD_ADDR,"dat/converted_weight_conv_56");
  load_ext_data(AXI_WEIGHT_57_LOAD_ADDR,"dat/converted_weight_conv_57");
  load_ext_data(AXI_WEIGHT_59_LOAD_ADDR,"dat/converted_weight_conv_59");
  load_ext_data(AXI_WEIGHT_60_LOAD_ADDR,"dat/converted_weight_conv_60");
  load_ext_data(AXI_WEIGHT_61_LOAD_ADDR,"dat/converted_weight_conv_61");
  load_ext_data(AXI_WEIGHT_62_LOAD_ADDR,"dat/converted_weight_conv_62");
  load_ext_data(AXI_WEIGHT_64_LOAD_ADDR,"dat/converted_weight_conv_64");

  load_ext_data(AXI_RQ_1_LOAD_ADDR,"dat/converted_rq_conv_1");
  load_ext_data(AXI_RQ_2_LOAD_ADDR,"dat/converted_rq_conv_2");
  load_ext_data(AXI_RQ_3_LOAD_ADDR,"dat/converted_rq_conv_3");
  load_ext_data(AXI_RQ_4_LOAD_ADDR,"dat/converted_rq_conv_4");
  load_ext_data(AXI_RQ_5_LOAD_ADDR,"dat/converted_rq_conv_5");
  load_ext_data(AXI_RQ_6_LOAD_ADDR,"dat/converted_rq_conv_6");
  load_ext_data(AXI_RQ_7_LOAD_ADDR,"dat/converted_rq_conv_7");
  load_ext_data(AXI_RQ_8_LOAD_ADDR,"dat/converted_rq_conv_8");
  load_ext_data(AXI_RQ_9_LOAD_ADDR,"dat/converted_rq_conv_9");
  load_ext_data(AXI_RQ_11_LOAD_ADDR,"dat/converted_rq_conv_11");
  load_ext_data(AXI_RQ_12_LOAD_ADDR,"dat/converted_rq_conv_12");
  load_ext_data(AXI_RQ_13_LOAD_ADDR,"dat/converted_rq_conv_13");
  load_ext_data(AXI_RQ_14_LOAD_ADDR,"dat/converted_rq_conv_14");
  load_ext_data(AXI_RQ_15_LOAD_ADDR,"dat/converted_rq_conv_15");
  load_ext_data(AXI_RQ_16_LOAD_ADDR,"dat/converted_rq_conv_16");
  load_ext_data(AXI_RQ_18_LOAD_ADDR,"dat/converted_rq_conv_18");
  load_ext_data(AXI_RQ_19_LOAD_ADDR,"dat/converted_rq_conv_19");
  load_ext_data(AXI_RQ_20_LOAD_ADDR,"dat/converted_rq_conv_20");
  load_ext_data(AXI_RQ_22_LOAD_ADDR,"dat/converted_rq_conv_22");
  load_ext_data(AXI_RQ_23_LOAD_ADDR,"dat/converted_rq_conv_23");
  load_ext_data(AXI_RQ_24_LOAD_ADDR,"dat/converted_rq_conv_24");
  load_ext_data(AXI_RQ_25_LOAD_ADDR,"dat/converted_rq_conv_25");
  load_ext_data(AXI_RQ_26_LOAD_ADDR,"dat/converted_rq_conv_26");
  load_ext_data(AXI_RQ_27_LOAD_ADDR,"dat/converted_rq_conv_27");
  load_ext_data(AXI_RQ_29_LOAD_ADDR,"dat/converted_rq_conv_29");
  load_ext_data(AXI_RQ_30_LOAD_ADDR,"dat/converted_rq_conv_30");
  load_ext_data(AXI_RQ_31_LOAD_ADDR,"dat/converted_rq_conv_31");
  load_ext_data(AXI_RQ_33_LOAD_ADDR,"dat/converted_rq_conv_33");
  load_ext_data(AXI_RQ_34_LOAD_ADDR,"dat/converted_rq_conv_34");
  load_ext_data(AXI_RQ_35_LOAD_ADDR,"dat/converted_rq_conv_35");
  load_ext_data(AXI_RQ_37_LOAD_ADDR,"dat/converted_rq_conv_37");
  load_ext_data(AXI_RQ_38_LOAD_ADDR,"dat/converted_rq_conv_38");
  load_ext_data(AXI_RQ_39_LOAD_ADDR,"dat/converted_rq_conv_39");
  load_ext_data(AXI_RQ_40_LOAD_ADDR,"dat/converted_rq_conv_40");
  load_ext_data(AXI_RQ_41_LOAD_ADDR,"dat/converted_rq_conv_41");
  load_ext_data(AXI_RQ_42_LOAD_ADDR,"dat/converted_rq_conv_42");
  load_ext_data(AXI_RQ_44_LOAD_ADDR,"dat/converted_rq_conv_44");
  load_ext_data(AXI_RQ_45_LOAD_ADDR,"dat/converted_rq_conv_45");
  load_ext_data(AXI_RQ_46_LOAD_ADDR,"dat/converted_rq_conv_46");
  load_ext_data(AXI_RQ_48_LOAD_ADDR,"dat/converted_rq_conv_48");
  load_ext_data(AXI_RQ_49_LOAD_ADDR,"dat/converted_rq_conv_49");
  load_ext_data(AXI_RQ_50_LOAD_ADDR,"dat/converted_rq_conv_50");
  load_ext_data(AXI_RQ_51_LOAD_ADDR,"dat/converted_rq_conv_51");
  load_ext_data(AXI_RQ_52_LOAD_ADDR,"dat/converted_rq_conv_52");
  load_ext_data(AXI_RQ_53_LOAD_ADDR,"dat/converted_rq_conv_53");
  load_ext_data(AXI_RQ_55_LOAD_ADDR,"dat/converted_rq_conv_55");
  load_ext_data(AXI_RQ_56_LOAD_ADDR,"dat/converted_rq_conv_56");
  load_ext_data(AXI_RQ_57_LOAD_ADDR,"dat/converted_rq_conv_57");
  load_ext_data(AXI_RQ_59_LOAD_ADDR,"dat/converted_rq_conv_59");
  load_ext_data(AXI_RQ_60_LOAD_ADDR,"dat/converted_rq_conv_60");
  load_ext_data(AXI_RQ_61_LOAD_ADDR,"dat/converted_rq_conv_61");
  load_ext_data(AXI_RQ_62_LOAD_ADDR,"dat/converted_rq_conv_62");
  load_ext_data(AXI_RQ_64_LOAD_ADDR,"dat/converted_rq_conv_64");
}


