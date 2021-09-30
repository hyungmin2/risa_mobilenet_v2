`timescale 1 ns / 1 ns

`include "defines.vh"


import RISA_PKG::*;


module BufferColumn #(
		parameter BUFFER_ID        = 0
	) (
    input rstn,
    input clk,

    input CommandDataPort i_command,
    output CommandDataPort o_command,

    output BufferColumnState o_state,
    input BufferColumnState i_state,
    
    output PEInput o_PE,
    input PEInput i_requant,

    output logic o_weight_load_done,
    input logic i_feed_started,
    output logic o_feed_started,
    
    input  logic [QSIZE-1:0] i_AL,
    input logic i_AL_valid,
    output logic o_AL_ready,

    output  logic [QSIZE-1:0] o_AW,
    output logic o_AW_valid,
    
    output BufferRAMTQsizeInputs buffer_ram_inputs,
    input BufferRAMTQsizeOutputs buffer_ram_outputs,

    input BufferColumnRelayAddrs i_addr_relay,
    output BufferColumnRelayAddrs o_addr_relay
	);
  (* keep = "true" , max_fanout = 32 *) logic rstn_b;

//lower 4-bit: mode
//upper 4-bit: options
localparam VALID_MASK           =  8'h0F;
localparam VALID_LOAD           =  8'h01;
localparam VALID_LOAD_TERMINAL  =  (8'h10);

localparam VALID_LT_FEED         =  8'h02;
localparam VALID_LT_FEED_POINT   =  8'h03;
localparam VALID_SWITCH         =  8'h04;

localparam VALID_NORMAL         =  8'h05;
localparam VALID_PADDING        =  (8'h10);

localparam VALID_ADD            =  8'h06;
localparam VALID_ADD1           =  (8'h10);

localparam VALID_FEED_TOKEN     =  8'h07;

localparam VALID_FEED           =  8'h08;

localparam VALID_LOAD_BY_TOKEN  =  8'h09;

localparam VALID_DUMP  =  8'hA;

localparam VALID_AVG  =  8'hB;
localparam VALID_AVG_LAST           =  (8'h10);

localparam PEOUT_MODE_LOAD     = 0;
localparam PEOUT_MODE_SWITCH   = 1;
localparam PEOUT_MODE_NORMAL   = 2;


  typedef struct packed {
    logic [COMMAND_WIDTH-1:0] command;        
    logic [FSIZE-1:0]  command_data0;
    logic [FSIZE-1:0]  command_data1;

    BufferColumnState state;
    BufferColumnState state_relay;

    BufferColumnRelayAddrs addr_relay;

    logic feed_started;
    logic feed_started_relay;

   
    BufferRAMTQsizeInputs buffer_ram_in;
    BufferRAMTQsizeInputs buffer_ram_in_b;

    logic [QSIZE-1:0] buffer_ram_read_data;
    logic [USIZE-1:0] buffer_ram_user_buf;
    logic [USIZE-1:0] buffer_ram_user_resadd_buf;

    CommandDataPort command_relay;

    logic [COMMAND_WIDTH-1:0] peout_conv_mode;        
    logic [2:0] peout_filter_h;
    logic [2:0] peout_filter_w;
    logic [$clog2(SLICE_CONV_CH)-1:0] peout_in_ch_slice;
    logic [$clog2(SLICE_CONV_CH)-1:0] peout_out_ch_slice;
    logic [$clog2(ARRAY_HEIGHT)-1:0] peout_feed_cycle;  

    logic peout_wait_for_feed_start;
    logic [1:0] peout_filter_size;
    logic [1:0] peout_filter_last;
    logic [$clog2(SLICE_CONV_CH)-1:0] peout_in_ch_slice_size;
    logic [$clog2(SLICE_CONV_CH)-1:0] peout_in_ch_slice_last;
    logic [$clog2(SLICE_CONV_CH)-1:0] peout_out_ch_slice_last;
    logic [$clog2(FMAP_MAX_H)-1:0] peout_fmap_h;
    logic [$clog2(FMAP_MAX_W)-1:0] peout_fmap_w;
    logic peout_fmap_h_end;
    logic peout_fmap_w_end;
    logic [$clog2(FMAP_MAX_H)-1:0] peout_fmap_h_size;  
    logic [$clog2(FMAP_MAX_W)-1:0] peout_fmap_w_size;  
    logic [$clog2(FMAP_MAX_H)-1:0] peout_fmap_h_last;  
    logic [$clog2(FMAP_MAX_W)-1:0] peout_fmap_w_last;  
        
    logic peout_fmap_h_stream;
    logic pein_fmap_h_stream;

        
    logic [1:0] peout_mode;    
        
    logic [$clog2(FMAP_MAX_H)-1:0] pein_fmap_h;  
    logic [$clog2(FMAP_MAX_W)-1:0] pein_fmap_w;  
    logic [$clog2(FMAP_MAX_H)-1:0] pein_fmap_h_size;  
    logic [$clog2(FMAP_MAX_W)-1:0] pein_fmap_w_size;  
    logic [$clog2(FMAP_MAX_H)-1:0] pein_fmap_h_last;  
    logic [$clog2(FMAP_MAX_W)-1:0] pein_fmap_w_last;  
    logic [$clog2(SLICE_CONV_CH)-1:0] pein_out_ch_slice;
    logic [$clog2(SLICE_CONV_CH)-1:0] pein_out_ch_slice_last;

    logic [2:0] peout_fmap_filter_offset_h;

    logic [BUFFER_READ_LATENCY+2:0][USIZE-1:0] buffer_ram_user ;        
    logic [BUFFER_READ_LATENCY+2:0][USIZE-1:0] buffer_ram_user_resadd; 

    logic [$clog2(BUFFER_WEIGHT_SIZE)-1:0] alin_idx;
    logic [$clog2(BUFFER_WEIGHT_SIZE)-1:0] alin_end;
    logic [$clog2(BUFFER_WEIGHT_SIZE)-1:0] alout_idx;
    logic [$clog2(BUFFER_WEIGHT_SIZE)-1:0] alout_end;
    logic alout_throttle;
    
    logic [$clog2(BUFFER_WEIGHT_SIZE)-1:0] transfer_idx;
    logic [$clog2(BUFFER_WEIGHT_SIZE)-1:0] transfer_end;
    logic [$clog2(BUFFER_WEIGHT_SIZE)-1:0] transfer_chunk_size;
    logic [$clog2(BUFFER_WEIGHT_SIZE)-1:0] transfer_chunk_last;
    logic [$clog2(BUFFER_WEIGHT_SIZE)-1:0] transfer_chunk_idx;
    logic transfer_one_chunk;
    
    logic [$clog2(BUFFER_WEIGHT_SIZE)-1:0] peout_base_addr;
    logic [$clog2(BUFFER_WEIGHT_SIZE)-1:0] peout_base_addr1;
    logic [$clog2(BUFFER_WEIGHT_SIZE)-1:0] peout_filter_base_addr;
    logic [$clog2(BUFFER_WEIGHT_SIZE)-1:0] pein_base_addr;
    logic [7:0] layer_id;    

    logic [$clog2(MAX_CHANNEL)-1:0] peout_in_ch;
    logic [$clog2(MAX_CHANNEL)-1:0] peout_out_ch;

    logic [$clog2(MAX_CHANNEL)-1:0] pein_in_ch;
    logic [$clog2(MAX_CHANNEL)-1:0] pein_out_ch;

    logic [1:0] peout_pad;
    logic [QSIZE-1:0] peout_input_zp;
    
    logic signed [QSIZE-1:0] peout_input_zp0;
    logic signed [QSIZE-1:0] peout_input_zp1;
    logic signed [FSIZE-1:0] peout_rescale_int0;
    logic signed [FSIZE-1:0] peout_rescale_int1;
    logic signed [QSIZE-1:0] peout_output_zp;
    
    logic [1:0] peout_stride;
    logic peout_phase;

    logic signed [FSIZE-1:0] Stage_1A_res;
    logic Stage_1A_valid0;          
    logic Stage_1A_valid1;          

    logic signed [FSIZE+24-1:0] Stage_1B_res;
    logic Stage_1B_valid0;          
    logic Stage_1B_valid1;          
    
    logic signed [FSIZE+24-1:0] Stage_1C_res;
    logic Stage_1C_valid0;          
    logic Stage_1C_valid1;          

    logic signed [FSIZE+24-1:0] Stage_1D_res;
    logic Stage_1D_valid0;          
    //logic Stage_1D_valid1;          
    
    logic signed [FSIZE+24-1:0] Stage_1E_res;
    logic Stage_1E_valid;          
            
    logic signed [FSIZE+24-1:0] Stage_1F_res;
    logic Stage_1F_valid;          

    
    logic signed [FSIZE-1:0] Stage_1G_res;
    logic Stage_1G_valid;          
    logic Stage_1G_negative;
    logic Stage_1G_roundup;

    logic signed [FSIZE-1:0] Stage_1H_res;
    logic Stage_1H_valid;          

    logic signed [FSIZE-1:0] Stage_1I_res;
    logic Stage_1I_valid;  


    logic AVGStage_1B_valid;          
    logic AVGStage_1C_valid;          
    logic signed [FSIZE-1:0] AVGStage_1A_res;
    logic signed [FSIZE-1:0] AVGStage_1B_res;
    logic signed [FSIZE+24-1:0] AVGStage_1C_res;
    logic signed [FSIZE-1:0] AVGStage_1D_res;
    logic signed [FSIZE-1:0] AVGStage_1E_res;
    logic AVGStage_1D_valid;          
    logic AVGStage_1D_negative;
    logic AVGStage_1D_roundup;
    logic AVGStage_1E_valid;          

    
    logic [$clog2(ARRAY_HEIGHT+1)-1:0] peout_transfer_repeat_stride;    
    
    logic send_tr_token;    
    logic [$clog2(ARRAY_WIDTH*2+2)-1:0] tr_transfer_interval;    
    logic [$clog2(ARRAY_WIDTH+1)-1:0] peout_last_line_width;    
    logic [7:0] peout_line;    
    logic [7:0] peout_line_size;    
    logic [7:0] peout_line_last;    
    logic [$clog2(MAX_CHANNEL)-1:0] peout_in_ch_idx;
    logic [$clog2(MAX_CHANNEL)-1:0] peout_in_ch_idx_last;
    logic [$clog2(ARRAY_HEIGHT)-1:0] peout_repeat;
    logic [$clog2(ARRAY_HEIGHT)-1:0] peout_repeat_last;
    logic peout_feed_token;
    
    logic [$clog2(ARRAY_HEIGHT+1)-1:0] sync_count;  

    BufferRAMTQsizeOutputs buffer_ram_outputs;

    PEInput i_requant;
    logic [QSIZE-1:0] i_AL;
    logic i_AL_valid;

    logic weight_load_done;

    logic pein_dconv_discard_last;
    logic peout_dconv_discard_last;

    logic peout_tr_stream;
  } Registers;
  
  Registers reg_current,reg_next;
  
  logic[USIZE-1:0] buffer_ram_user_buf;
  logic[USIZE-1:0] buffer_ram_user_resadd_buf;


  always_comb begin
    reg_next = reg_current;
   
    reg_next.command_relay = i_command;
    
    reg_next.i_requant = i_requant;

    reg_next.feed_started_relay = i_feed_started;

    //Reset temp values;
    reg_next.command = 0;
    reg_next.weight_load_done = 0;

    reg_next.addr_relay = i_addr_relay;


    if(i_feed_started)begin
      reg_next.feed_started = 1;
    end

    if(i_command.valid) begin
      reg_next.command = i_command.command;       
      reg_next.command_data0 = i_command.data0;       
      reg_next.command_data1 = i_command.data1;       

      // $display("CB(%d) receive command %d %x(%d) %x(%d) at %d",BUFFER_ID,i_command.command,i_command.data0,i_command.data0,i_command.data1,i_command.data1,$time()/2);
    end
    
    reg_next.buffer_ram_outputs = buffer_ram_outputs;

    if(reg_current.command == BUFFER_WEIGHT_MODESET_CONV0) begin 
      reg_next.pein_fmap_h_size = reg_current.command_data0;
      reg_next.pein_fmap_w_size = reg_current.command_data1;
      reg_next.pein_fmap_h_last = reg_current.command_data0-1;
      reg_next.pein_fmap_w_last = reg_current.command_data1-1;
    end
    if(reg_current.command == BUFFER_WEIGHT_MODESET_CONV1) begin 
      reg_next.peout_in_ch_slice_size = reg_current.command_data0;
      reg_next.peout_in_ch_slice_last = reg_current.command_data0 -1;
      reg_next.peout_out_ch_slice_last = reg_current.command_data1 -1;
      reg_next.pein_out_ch_slice_last = reg_current.command_data1 -1;
    end
    if(reg_current.command == BUFFER_WEIGHT_MODESET_CONV2) begin 
      reg_next.peout_filter_size = reg_current.command_data0;
      reg_next.peout_filter_last = reg_current.command_data0-1;
      reg_next.peout_stride = reg_current.command_data1;
    end
    if(reg_current.command == BUFFER_WEIGHT_MODESET_CONV3) begin 
      reg_next.peout_pad = reg_current.command_data0;              
      reg_next.peout_input_zp = reg_current.command_data1;              
    end    
    if(reg_current.command == BUFFER_WEIGHT_MODESET_CONV4) begin 
      reg_next.peout_base_addr = reg_current.command_data0;              
      reg_next.pein_base_addr = reg_current.command_data1;
    end    
    if(reg_current.command == BUFFER_WEIGHT_MODESET_CONV5) begin 
      reg_next.peout_in_ch = reg_current.command_data0;              
      reg_next.peout_out_ch = reg_current.command_data1;              
      reg_next.pein_out_ch = reg_current.command_data1;              
    end 
    if(reg_current.command == BUFFER_WEIGHT_MODESET_CONV6) begin       
      reg_next.peout_fmap_h_size = reg_current.command_data0;
      reg_next.peout_fmap_w_size = reg_current.command_data1;
      reg_next.peout_fmap_h_last = reg_current.command_data0-1;
      reg_next.peout_fmap_w_last = reg_current.command_data1-1;
    end   
    if(reg_current.command == BUFFER_WEIGHT_MODESET_CONV7) begin       
      reg_next.peout_filter_base_addr = reg_current.command_data0;
    end   
    if(reg_current.command == BUFFER_WEIGHT_MODESET_CONV_IN_TRANSFER_LAYERID ||
        reg_current.command == BUFFER_WEIGHT_MODESET_ICONV_LAYERID) begin 
      reg_next.layer_id = reg_current.command_data0;

      reg_next.peout_wait_for_feed_start = 0;
    
      reg_next.state.peout =  BUFFER_WEIGHT_WORKING;      
      if(reg_current.command == BUFFER_WEIGHT_MODESET_ICONV_LAYERID)
        reg_next.state.peout =  BUFFER_WEIGHT_WORKING_ICONV;      
      if(reg_current.command == BUFFER_WEIGHT_MODESET_CONV_IN_TRANSFER_LAYERID) begin
        reg_next.state.peout =  BUFFER_WEIGHT_WORKING_TRANSFER_CONV0;   
        reg_next.transfer_idx = reg_current.peout_base_addr;
        reg_next.transfer_end = reg_current.peout_base_addr + reg_current.peout_in_ch_slice_size * reg_current.peout_fmap_h_size * reg_current.peout_fmap_w_size;
        reg_next.transfer_chunk_idx = 0;
        reg_next.transfer_chunk_last = reg_current.peout_fmap_h_size * reg_current.peout_fmap_w_size - 1;
        reg_next.transfer_chunk_size = reg_current.peout_fmap_h_size * reg_current.peout_fmap_w_size;
        reg_next.transfer_one_chunk = 1;

        reg_next.peout_transfer_repeat_stride = ARRAY_HEIGHT; 

      end
      reg_next.state.pein =  BUFFER_WEIGHT_WORKING;      
      reg_next.pein_fmap_h = 0;
      reg_next.pein_fmap_w = 0;
      reg_next.pein_out_ch_slice = 0;

      reg_next.peout_fmap_h = 0;      
      reg_next.peout_fmap_w = 0;      
      reg_next.peout_filter_h = 0;
      reg_next.peout_filter_w = 0;
      reg_next.peout_in_ch_slice = 0;
      reg_next.peout_out_ch_slice = 0;  
      reg_next.peout_feed_cycle = 0;    

      reg_next.peout_in_ch_idx = 0;

      reg_next.feed_started = 0;  
      reg_next.peout_feed_token = 1;        
    end
    if(reg_current.command == BUFFER_WEIGHT_MODESET_DCONV_LAYERID) begin 
      reg_next.layer_id = reg_current.command_data0;

      reg_next.peout_mode = PEOUT_MODE_LOAD;
      
      reg_next.state.peout =  BUFFER_WEIGHT_WORKING_DCONV;      
      reg_next.state.pein =  BUFFER_WEIGHT_WORKING_DCONV;      

      reg_next.pein_fmap_h_stream = 0;
      reg_next.pein_fmap_h = 0;
      reg_next.pein_fmap_w = 0;
      reg_next.pein_out_ch_slice = 0;

      reg_next.peout_fmap_h = 0;      
      reg_next.peout_fmap_h_stream = 0;      
      reg_next.peout_fmap_w = 0;      
      reg_next.peout_filter_h = reg_current.peout_filter_last;
      reg_next.peout_filter_w = reg_current.peout_filter_last;
      reg_next.peout_out_ch_slice = 0;  
      reg_next.peout_fmap_filter_offset_h = 0;      
      
      reg_next.peout_fmap_w_last = reg_current.peout_fmap_w_size + reg_current.peout_filter_size -1 -reg_current.peout_stride;
      reg_next.peout_fmap_h_last = reg_current.peout_fmap_h_size /2 -reg_current.peout_stride;
      
      reg_next.peout_dconv_discard_last = 0;
      if((reg_current.peout_fmap_h_size/reg_current.peout_stride) % 2 == 1) begin
        reg_next.peout_fmap_h_last = (reg_current.peout_fmap_h_size/2)/reg_current.peout_stride * reg_current.peout_stride;
        reg_next.peout_dconv_discard_last = 1;
      end

      reg_next.pein_fmap_w_last = reg_current.pein_fmap_w_size-1;
      reg_next.pein_fmap_h_last = reg_current.pein_fmap_h_size/2-1;
      reg_next.pein_dconv_discard_last = 0;
      if(reg_current.pein_fmap_h_size%2 == 1) begin
        reg_next.pein_fmap_h_last = reg_next.pein_fmap_h_last + 1;
        reg_next.pein_dconv_discard_last = 1;
      end
    end

    
    
    if(reg_current.command == BUFFER_WEIGHT_MODESET_ADD0) begin 
      reg_next.pein_fmap_h_size = reg_current.command_data0;
      reg_next.pein_fmap_w_size = reg_current.command_data1;
      reg_next.pein_fmap_h_last = reg_current.command_data0-1;
      reg_next.pein_fmap_w_last = reg_current.command_data1-1;
      reg_next.peout_fmap_h_size = reg_current.command_data0;
      reg_next.peout_fmap_w_size = reg_current.command_data1;
      reg_next.peout_fmap_h_last = reg_current.command_data0-1;
      reg_next.peout_fmap_w_last = reg_current.command_data1-1;
    end
    if(reg_current.command == BUFFER_WEIGHT_MODESET_ADD1) begin 
      reg_next.peout_in_ch = reg_current.command_data0;
      reg_next.pein_out_ch = reg_current.command_data0;
      reg_next.peout_in_ch_slice_last = reg_current.command_data1 -1;
      reg_next.peout_out_ch_slice_last = reg_current.command_data1 -1;
      reg_next.pein_out_ch_slice_last = reg_current.command_data1 -1;
    end
    if(reg_current.command == BUFFER_WEIGHT_MODESET_ADD2) begin 
      reg_next.peout_input_zp0 = reg_current.command_data0; 
      reg_next.peout_input_zp1 = reg_current.command_data1;
    end
    if(reg_current.command == BUFFER_WEIGHT_MODESET_ADD3) begin 
      reg_next.peout_rescale_int0 = reg_current.command_data0;              
      reg_next.peout_rescale_int1 = reg_current.command_data1;          
    end    
    if(reg_current.command == BUFFER_WEIGHT_MODESET_ADD4) begin 
      reg_next.peout_output_zp = reg_current.command_data0;             
    end    
    if(reg_current.command == BUFFER_WEIGHT_MODESET_ADD5) begin 
      reg_next.peout_base_addr = reg_current.command_data0;     //in     input0
      reg_next.peout_base_addr1 = reg_current.command_data1;     //in     input0
    end    
    if(reg_current.command == BUFFER_WEIGHT_MODESET_ADD_LAYERID) begin 
      reg_next.layer_id = reg_current.command_data0;
      reg_next.pein_base_addr = reg_current.command_data1;      //in+out input1

      reg_next.state.peout =  BUFFER_WEIGHT_WORKING_ADD;      
      reg_next.state.pein =  BUFFER_WEIGHT_WORKING_ADD;      

      reg_next.pein_fmap_h = 0;
      reg_next.pein_fmap_w = 0;
      reg_next.pein_out_ch_slice = 0;

      reg_next.peout_phase = 0;
      reg_next.peout_fmap_h = 0;      
      reg_next.peout_fmap_w = 0;     
      reg_next.peout_in_ch_slice = 0;
      reg_next.peout_out_ch_slice = 0;    
    end



    
    
    if(reg_current.command == BUFFER_WEIGHT_MODESET_AVG0) begin 
      reg_next.peout_fmap_h_size = reg_current.command_data0;
      reg_next.peout_fmap_w_size = reg_current.command_data1;
      reg_next.peout_fmap_h_last = reg_current.command_data0-1;
      reg_next.peout_fmap_w_last = reg_current.command_data1-1;
    end
    if(reg_current.command == BUFFER_WEIGHT_MODESET_AVG1) begin 
      reg_next.peout_in_ch = reg_current.command_data0;
      reg_next.pein_out_ch = reg_current.command_data0;
      reg_next.peout_in_ch_slice_last = reg_current.command_data1 -1;
      reg_next.peout_out_ch_slice_last = reg_current.command_data1 -1;
      reg_next.pein_out_ch_slice_last = reg_current.command_data1 -1;
    end
    if(reg_current.command == BUFFER_WEIGHT_MODESET_AVG2) begin 
      reg_next.peout_input_zp0 = reg_current.command_data0; 
      reg_next.peout_output_zp = reg_current.command_data1;
    end
    if(reg_current.command == BUFFER_WEIGHT_MODESET_AVG3) begin 
      reg_next.peout_rescale_int0 = reg_current.command_data0;          
    end    
    if(reg_current.command == BUFFER_WEIGHT_MODESET_AVG4) begin 
      reg_next.peout_base_addr = reg_current.command_data0;     //in     input0
      reg_next.pein_base_addr = reg_current.command_data1;      //in+out input1
    end    
    if(reg_current.command == BUFFER_WEIGHT_MODESET_AVG_LAYERID) begin 
      reg_next.layer_id = reg_current.command_data0;

      reg_next.state.peout =  BUFFER_WEIGHT_WORKING_AVG;      
      reg_next.state.pein =  BUFFER_WEIGHT_WORKING_AVG;      

      reg_next.pein_fmap_h = 0;
      reg_next.pein_fmap_w = 0;
      reg_next.pein_out_ch_slice = 0;

      reg_next.peout_phase = 0;
      reg_next.peout_fmap_h = 0;      
      reg_next.peout_fmap_w = 0;     
      reg_next.peout_in_ch_slice = 0;
      reg_next.peout_out_ch_slice = 0;    

      reg_next.AVGStage_1A_res= 0;
    end




    if(reg_current.command == BUFFER_WEIGHT_MODESET_LOAD)  begin
      reg_next.state.al_in =  BUFFER_WEIGHT_WORKING;      
      reg_next.alin_idx = reg_current.command_data0;
      reg_next.alin_end = reg_current.command_data0 + reg_current.command_data1 - 1;
    end

    if(reg_current.command == BUFFER_WEIGHT_MODESET_DUMP)  begin
      reg_next.state.peout =  BUFFER_WEIGHT_DUMP;      
      reg_next.alout_idx = reg_current.command_data0;
      reg_next.alout_end = reg_current.command_data0 + reg_current.command_data1 - 1;
      reg_next.alout_throttle = 1;
    end

    if(reg_current.command == BUFFER_WEIGHT_MODESET_TRTRANSFER0) begin
      reg_next.peout_in_ch_idx_last = reg_current.command_data0-1;
      reg_next.peout_repeat_last = reg_current.command_data1-1;
    end
    if(reg_current.command == BUFFER_WEIGHT_MODESET_TRTRANSFER1) begin
      reg_next.peout_line_size = reg_current.command_data0;
      reg_next.peout_line_last = reg_current.command_data0-1;
      reg_next.peout_last_line_width = reg_current.command_data1;
    end
    if(reg_current.command == BUFFER_WEIGHT_MODESET_TRTRANSFER2) begin
      reg_next.state.peout = BUFFER_WEIGHT_TRTRANSFER;

      reg_next.transfer_idx = reg_current.command_data0;
      reg_next.peout_fmap_h_size = reg_current.command_data1;
      reg_next.peout_fmap_h_last = reg_current.command_data1/2-1;

      reg_next.tr_transfer_interval = 0;
      reg_next.send_tr_token = 1;
      reg_next.peout_in_ch_idx = 0;
      reg_next.peout_repeat = 0;
      reg_next.peout_line = 0;
      reg_next.peout_fmap_h = 0;
      reg_next.peout_tr_stream = 0;
    end

    reg_next.buffer_ram_in.raddr = 0;
    reg_next.buffer_ram_in.waddr = 0;
    reg_next.buffer_ram_in.wren = 0;
    reg_next.buffer_ram_in.wdata = reg_current.i_requant.data;
    
    reg_next.buffer_ram_user[0] = 0;
    reg_next.buffer_ram_user_resadd[0] = 0;
    for(int i = 0; i < BUFFER_READ_LATENCY+2; i ++) begin
      reg_next.buffer_ram_user[i+1] = reg_current.buffer_ram_user[i];    
      reg_next.buffer_ram_user_resadd[i+1] = reg_current.buffer_ram_user_resadd[i];    
    end
    
    
    
    //++mat out //
    if(reg_current.state.peout == BUFFER_WEIGHT_WORKING_DCONV) begin
      if(reg_current.peout_mode == PEOUT_MODE_LOAD )  begin
        reg_next.buffer_ram_user[0] = VALID_LOAD;

        reg_next.peout_filter_h = reg_current.peout_filter_h - 1;          
        if(reg_current.peout_filter_h == 0)begin //CONV1_K-1
          reg_next.peout_filter_h = reg_current.peout_filter_last;

          reg_next.peout_filter_w = reg_current.peout_filter_w - 1;          
          if(reg_current.peout_filter_w == 0)begin //CONV1_K-1
            reg_next.peout_filter_w = reg_current.peout_filter_last;

            reg_next.buffer_ram_user[0] = reg_next.buffer_ram_user[0] | VALID_LOAD_TERMINAL;
            reg_next.peout_mode = PEOUT_MODE_SWITCH;
          end            
        end
        

        reg_next.buffer_ram_in.raddr = reg_current.peout_filter_base_addr + 
              reg_current.peout_out_ch_slice  *  reg_current.peout_filter_size * reg_current.peout_filter_size + 
              reg_current.peout_filter_h * reg_current.peout_filter_size + 
              reg_current.peout_filter_w
              ;
      end
      else if(reg_current.peout_mode == PEOUT_MODE_SWITCH )  begin
        reg_next.buffer_ram_user[0] = VALID_SWITCH;
        reg_next.peout_mode = PEOUT_MODE_NORMAL;  
      end
      else if(reg_current.peout_mode == PEOUT_MODE_NORMAL )  begin
        reg_next.buffer_ram_user[0] = VALID_NORMAL;

        reg_next.peout_fmap_h_stream = !reg_current.peout_fmap_h_stream;
        if(reg_current.peout_fmap_h_stream)begin 
          reg_next.peout_fmap_filter_offset_h = reg_current.peout_fmap_filter_offset_h + 1;
          if(reg_current.peout_fmap_filter_offset_h == reg_current.peout_filter_last) begin //FMAP_W-1
            reg_next.peout_fmap_filter_offset_h = 0;

            reg_next.peout_fmap_w = reg_current.peout_fmap_w + 1;
            if(reg_current.peout_fmap_w == reg_current.peout_fmap_w_last) begin //FMAP_W-1
              reg_next.peout_fmap_w = 0;

              reg_next.peout_fmap_h = reg_current.peout_fmap_h + reg_current.peout_stride;
              if(reg_current.peout_fmap_h == reg_current.peout_fmap_h_last) begin //FMAP_H-1
                reg_next.peout_fmap_h = 0;

                reg_next.peout_mode = PEOUT_MODE_LOAD; 

                reg_next.peout_out_ch_slice = reg_current.peout_out_ch_slice + 1;          
                if(reg_current.peout_out_ch_slice == reg_current.peout_out_ch_slice_last)begin //SLICE_CONV1_OUT-1
                  reg_next.peout_out_ch_slice = 0;
                  reg_next.state.peout = BUFFER_QUANT_IDLE;     
                end
              end         
            end
          end
        end

        if((reg_current.peout_fmap_w < reg_current.peout_pad)  ||
          (reg_current.peout_fmap_h * 2 + (reg_current.peout_fmap_h_stream)*reg_current.peout_stride + reg_current.peout_fmap_filter_offset_h < reg_current.peout_pad)  ||
          (reg_current.peout_fmap_w - reg_current.peout_pad) > reg_current.peout_fmap_w_size -1  || 
          (reg_current.peout_fmap_h * 2 + (reg_current.peout_fmap_h_stream)*reg_current.peout_stride + reg_current.peout_fmap_filter_offset_h - reg_current.peout_pad) > reg_current.peout_fmap_h_size -1  ) begin
          reg_next.buffer_ram_user[0] = reg_next.buffer_ram_user[0] | VALID_PADDING;
        end

        reg_next.buffer_ram_in.raddr = reg_current.peout_base_addr + 
              reg_current.peout_out_ch_slice *  reg_current.peout_fmap_h_size * reg_current.peout_fmap_w_size  +
              (reg_current.peout_fmap_h * 2 + (reg_current.peout_fmap_h_stream)*reg_current.peout_stride + reg_current.peout_fmap_filter_offset_h - reg_current.peout_pad) *  reg_current.peout_fmap_w_size  +
              (reg_current.peout_fmap_w - reg_current.peout_pad) 
              ;
      end
    end

    if(reg_current.state.peout == BUFFER_WEIGHT_WORKING_TRANSFER_CONV0) begin
      reg_next.buffer_ram_user[0] = VALID_LT_FEED_POINT;
      reg_next.state.peout = BUFFER_WEIGHT_WORKING_TRANSFER_CONV1;
    end
    if(reg_current.state.peout == BUFFER_WEIGHT_WORKING_TRANSFER_CONV1) begin

      if(!( reg_current.peout_wait_for_feed_start )) begin
        if(reg_current.peout_feed_token ) begin
          reg_next.buffer_ram_user[0] = VALID_FEED_TOKEN;

          reg_next.peout_feed_token = 0;
        end
        else if(!reg_current.i_requant.command)begin

          if(reg_current.peout_feed_cycle < `MIN(ARRAY_HEIGHT,reg_current.peout_in_ch)) begin
            reg_next.buffer_ram_user[0] = VALID_LOAD_BY_TOKEN;            
          end

          reg_next.peout_feed_cycle = reg_current.peout_feed_cycle + 1;          
          if(reg_current.peout_feed_cycle == ARRAY_HEIGHT-1) begin
            reg_next.peout_feed_cycle = 0;

            reg_next.weight_load_done = 1;
            reg_next.peout_wait_for_feed_start = 1;
            reg_next.peout_feed_token  = 1;
          end
        end
    
        reg_next.buffer_ram_in.raddr = reg_current.peout_filter_base_addr + 
                reg_current.peout_out_ch_slice  *  reg_current.peout_filter_size * reg_current.peout_filter_size * reg_current.peout_in_ch + 
                reg_current.peout_filter_h * reg_current.peout_filter_size * reg_current.peout_in_ch + 
                reg_current.peout_filter_w * reg_current.peout_in_ch + 
                reg_current.peout_in_ch_slice * ARRAY_HEIGHT + reg_current.peout_feed_cycle 
                ;
        
      end        
      else if(reg_current.transfer_one_chunk && reg_current.transfer_idx < reg_current.transfer_end) begin
        reg_next.buffer_ram_user[0] = VALID_LT_FEED;
        reg_next.transfer_idx = reg_current.transfer_idx + 1;
        reg_next.transfer_chunk_idx = reg_current.transfer_chunk_idx + 1;
        if(reg_current.transfer_chunk_idx == reg_current.transfer_chunk_last) begin
          reg_next.transfer_chunk_idx = 0;

          reg_next.transfer_one_chunk = 0;          
        end 

        reg_next.buffer_ram_in.raddr = reg_current.transfer_idx;        
      end            
      else begin
        if(reg_current.feed_started) begin
          reg_next.feed_started = 0;
          reg_next.peout_wait_for_feed_start = 0;

          if( reg_current.transfer_idx < reg_current.transfer_end ) begin
            reg_next.transfer_one_chunk = 1;
          end

          reg_next.peout_in_ch_slice = reg_current.peout_in_ch_slice + 1;          
          if(reg_current.peout_in_ch_slice == reg_current.peout_in_ch_slice_last)begin 
            reg_next.peout_in_ch_slice = 0;

            reg_next.peout_filter_w = reg_current.peout_filter_w + 1;          
            if(reg_current.peout_filter_w == reg_current.peout_filter_last)begin 
              reg_next.peout_filter_w = 0;

              reg_next.peout_filter_h = reg_current.peout_filter_h + 1;          
              if(reg_current.peout_filter_h == reg_current.peout_filter_last)begin
                reg_next.peout_filter_h = 0;

                reg_next.peout_out_ch_slice = reg_current.peout_out_ch_slice + 1;          
                if(reg_current.peout_out_ch_slice == reg_current.peout_out_ch_slice_last)begin 
                  reg_next.peout_out_ch_slice = 0;

                  reg_next.state.peout = BUFFER_WEIGHT_IDLE;
                end
              end
            end
          end
        end
      end
    end


    if(reg_current.state.peout == BUFFER_WEIGHT_WORKING_ICONV) begin
      if( reg_current.peout_wait_for_feed_start ) begin
        if(reg_current.feed_started) begin
          reg_next.feed_started = 0;
          reg_next.peout_wait_for_feed_start = 0;
          reg_next.peout_feed_token = 1;
        end        
      end
      else if( reg_current.peout_feed_token ) begin
        reg_next.buffer_ram_user[0] = VALID_FEED_TOKEN;

        reg_next.peout_feed_token = 0;
      end
      else begin
        

        if(reg_current.peout_feed_cycle < reg_current.peout_in_ch * reg_current.peout_filter_size* reg_current.peout_filter_size ) begin
          reg_next.buffer_ram_user[0] = VALID_LOAD_BY_TOKEN;
          reg_next.peout_in_ch_idx = reg_current.peout_in_ch_idx + 1;          
          if(reg_current.peout_in_ch_idx == reg_current.peout_in_ch -1) begin
            reg_next.peout_in_ch_idx = 0;        

            reg_next.peout_filter_w = reg_current.peout_filter_w + 1;          
            if(reg_current.peout_filter_w == reg_current.peout_filter_last)begin 
              reg_next.peout_filter_w = 0;

              reg_next.peout_filter_h = reg_current.peout_filter_h + 1;          
              if(reg_current.peout_filter_h == reg_current.peout_filter_last)begin
                reg_next.peout_filter_h = 0;
              end
            end
          end
          reg_next.buffer_ram_user[0] = VALID_LOAD_BY_TOKEN;            
        end

        reg_next.peout_feed_cycle = reg_current.peout_feed_cycle + 1;          
        if(reg_current.peout_feed_cycle == ARRAY_HEIGHT-1) begin
          reg_next.peout_feed_cycle = 0;

          reg_next.weight_load_done = 1;
          reg_next.peout_wait_for_feed_start = 1;

          reg_next.peout_out_ch_slice = reg_current.peout_out_ch_slice + 1;          
          if(reg_current.peout_out_ch_slice == reg_current.peout_out_ch_slice_last)begin
            reg_next.peout_out_ch_slice = 0;

            reg_next.state.peout = BUFFER_QUANT_IDLE; 
          end
        end
      end
    
      reg_next.buffer_ram_in.raddr = reg_current.peout_filter_base_addr + 
              reg_current.peout_out_ch_slice  *  reg_current.peout_filter_size * reg_current.peout_filter_size * reg_current.peout_in_ch + 
              reg_current.peout_filter_h * reg_current.peout_filter_size * reg_current.peout_in_ch + 
              reg_current.peout_filter_w * reg_current.peout_in_ch + 
              reg_current.peout_in_ch_idx 
              ;
    end
    if(reg_current.state.peout == BUFFER_WEIGHT_WORKING_ADD) begin
      reg_next.buffer_ram_user_resadd[0] = VALID_ADD;
      
      if(reg_current.peout_phase==1) 
        reg_next.buffer_ram_user_resadd[0] = reg_next.buffer_ram_user_resadd[0] | VALID_ADD1;
      
      reg_next.peout_phase = !reg_current.peout_phase;
      if(reg_current.peout_phase) begin
        reg_next.peout_fmap_w = reg_current.peout_fmap_w + 1;
        if(reg_current.peout_fmap_w == reg_current.peout_fmap_w_last) begin
          reg_next.peout_fmap_w = 0;
  
          reg_next.peout_fmap_h = reg_current.peout_fmap_h + 1;
          if(reg_current.peout_fmap_h == reg_current.peout_fmap_h_last) begin
            reg_next.peout_fmap_h = 0;
  
            reg_next.peout_in_ch_slice = reg_current.peout_in_ch_slice + 1;
            if(reg_current.peout_in_ch_slice == reg_current.peout_in_ch_slice_last) begin
              reg_next.peout_in_ch_slice = 0;
              reg_next.state.peout = BUFFER_WEIGHT_IDLE;               
            end
          end
        end
      end

      if(reg_current.peout_phase==0)
        reg_next.buffer_ram_in.raddr = reg_current.peout_base_addr;
      else
        reg_next.buffer_ram_in.raddr = reg_current.peout_base_addr1;

      reg_next.buffer_ram_in.raddr = reg_next.buffer_ram_in.raddr +
        reg_current.peout_in_ch_slice * reg_current.peout_fmap_h_size * reg_current.peout_fmap_w_size +
        reg_current.peout_fmap_h * reg_current.peout_fmap_w_size +
        reg_current.peout_fmap_w
      ;
    end

    if(reg_current.state.peout == BUFFER_WEIGHT_WORKING_AVG) begin
      reg_next.buffer_ram_user_resadd[0] = VALID_AVG;
      
      reg_next.peout_fmap_w = reg_current.peout_fmap_w + 1;
      if(reg_current.peout_fmap_w == reg_current.peout_fmap_w_last) begin
        reg_next.peout_fmap_w = 0;
  
        reg_next.peout_fmap_h = reg_current.peout_fmap_h + 1;
        if(reg_current.peout_fmap_h == reg_current.peout_fmap_h_last) begin
          reg_next.peout_fmap_h = 0;
  
          reg_next.buffer_ram_user_resadd[0] = VALID_AVG | VALID_AVG_LAST;

          reg_next.peout_in_ch_slice = reg_current.peout_in_ch_slice + 1;
          if(reg_current.peout_in_ch_slice == reg_current.peout_in_ch_slice_last) begin
            reg_next.peout_in_ch_slice = 0;
            reg_next.state.peout = BUFFER_WEIGHT_IDLE;               
          end
        end
      end

      reg_next.buffer_ram_in.raddr = reg_current.peout_base_addr +
        reg_current.peout_in_ch_slice * reg_current.peout_fmap_h_size * reg_current.peout_fmap_w_size +
        reg_current.peout_fmap_h * reg_current.peout_fmap_w_size +
        reg_current.peout_fmap_w
      ;
    end

    if(reg_current.state.peout == BUFFER_WEIGHT_TRTRANSFER) begin
      if(reg_current.tr_transfer_interval > 0) begin
        reg_next.tr_transfer_interval = reg_current.tr_transfer_interval-1;
      end
      
      if(reg_current.send_tr_token) begin
        if(reg_current.tr_transfer_interval == 0) begin        
          reg_next.buffer_ram_user[0] = VALID_FEED_TOKEN;
          reg_next.tr_transfer_interval = ARRAY_WIDTH;
          reg_next.send_tr_token = 0;
        end
      end      
      else begin
        reg_next.buffer_ram_user[0] = VALID_FEED;
        
        reg_next.peout_in_ch_idx = reg_current.peout_in_ch_idx + 1;
        if(reg_current.peout_in_ch_idx == reg_current.peout_in_ch_idx_last) begin
          reg_next.peout_in_ch_idx = 0;          

          reg_next.peout_repeat = reg_current.peout_repeat + 1;
          if(reg_current.peout_repeat == reg_current.peout_repeat_last) begin
            reg_next.peout_repeat = 0;  

            reg_next.send_tr_token = 1;        

            reg_next.peout_tr_stream = !reg_current.peout_tr_stream;

            if(reg_current.peout_tr_stream) begin
              reg_next.peout_line = reg_current.peout_line + 1;
              if(reg_current.peout_line == reg_current.peout_line_last) begin
                reg_next.peout_line = 0;

                reg_next.peout_fmap_h = reg_current.peout_fmap_h + 1;
                if(reg_current.peout_fmap_h == reg_current.peout_fmap_h_last) begin
                  reg_next.peout_fmap_h = 0;

                  reg_next.state.peout = BUFFER_WEIGHT_IDLE;   
                end
              end
            end
          end
        end 
      end

      reg_next.buffer_ram_in.raddr = reg_current.transfer_idx 
            + reg_current.peout_in_ch_idx * reg_current.peout_fmap_h_size * reg_current.peout_line_size 
             + (reg_current.peout_tr_stream * reg_current.peout_fmap_h_size/2 + reg_current.peout_fmap_h ) * reg_current.peout_line_size 
             + reg_current.peout_line;

     
    end    
    if(reg_current.state.peout == BUFFER_WEIGHT_DUMP)  begin
      reg_next.alout_throttle = reg_current.alout_throttle -1;
      if(reg_current.alout_throttle == 0) begin
        reg_next.alout_throttle = 1;
        reg_next.buffer_ram_user[0] = VALID_DUMP;      
        
        reg_next.alout_idx = reg_current.alout_idx + 1;
        if(reg_current.alout_idx == reg_current.alout_end) begin
          reg_next.alout_idx = 0;
          reg_next.state.peout = BUFFER_WEIGHT_IDLE;               
        end
        reg_next.buffer_ram_in.raddr = reg_current.alout_idx;
      end
    end

    reg_next.buffer_ram_read_data = reg_current.buffer_ram_outputs.rdata;
    reg_next.buffer_ram_user_buf = reg_current.buffer_ram_user[BUFFER_READ_LATENCY+2];
    reg_next.buffer_ram_user_resadd_buf = reg_current.buffer_ram_user_resadd[BUFFER_READ_LATENCY+2];
    //--mat out //


    //++mat in //
    if(reg_current.state.pein == BUFFER_WEIGHT_WORKING_DCONV) begin
      if(reg_current.i_requant.command) begin
        reg_next.buffer_ram_in.wren = 1;
        reg_next.buffer_ram_in.wdata = reg_current.i_requant.data;

        reg_next.pein_fmap_h_stream = !reg_current.pein_fmap_h_stream;
        if(reg_current.pein_dconv_discard_last && reg_current.pein_fmap_h == reg_current.pein_fmap_h_last) reg_next.pein_fmap_h_stream = 0;

        if(reg_current.pein_fmap_h_stream || (reg_current.pein_dconv_discard_last && reg_current.pein_fmap_h == reg_current.pein_fmap_h_last)) begin
          reg_next.pein_fmap_w = reg_current.pein_fmap_w + 1;     
          if(reg_current.pein_fmap_w == reg_current.pein_fmap_w_last) begin                     
            reg_next.pein_fmap_w = 0;

            reg_next.pein_fmap_h = reg_current.pein_fmap_h + 1;         
            if(reg_current.pein_fmap_h == reg_current.pein_fmap_h_last) begin  
              reg_next.pein_fmap_h = 0;      

              reg_next.pein_out_ch_slice = reg_current.pein_out_ch_slice + 1;         
              if(reg_current.pein_out_ch_slice == reg_current.pein_out_ch_slice_last) begin  
                reg_next.pein_out_ch_slice = 0;      

                reg_next.state.pein = BUFFER_QUANT_IDLE;                                    
              end
            end
          end
        end

        reg_next.buffer_ram_in.waddr =  reg_current.pein_base_addr + 
                reg_current.pein_out_ch_slice * reg_current.pein_fmap_h_size * reg_current.pein_fmap_w_size + 
                (reg_current.pein_fmap_h*2 +reg_current.pein_fmap_h_stream) * reg_current.pein_fmap_w_size + 
                reg_current.pein_fmap_w
                ;
      end
    end        
    if(reg_current.state.pein == BUFFER_WEIGHT_WORKING) begin
      if(reg_current.i_requant.command) begin
        reg_next.buffer_ram_in.wren = 1;
        reg_next.buffer_ram_in.wdata = reg_current.i_requant.data;

        reg_next.pein_fmap_w = reg_current.pein_fmap_w + 1;     
        if(reg_current.pein_fmap_w == reg_current.pein_fmap_w_last) begin                     
          reg_next.pein_fmap_w = 0;                              

          reg_next.pein_fmap_h = reg_current.pein_fmap_h + 1;         
          if(reg_current.pein_fmap_h == reg_current.pein_fmap_h_last) begin  
            reg_next.pein_fmap_h = 0;      

            reg_next.pein_out_ch_slice = reg_current.pein_out_ch_slice + 1;         
            if(reg_current.pein_out_ch_slice == reg_current.pein_out_ch_slice_last) begin  
              reg_next.pein_out_ch_slice = 0;      

              reg_next.state.pein = BUFFER_QUANT_IDLE;             
            end
          end
        end
        reg_next.buffer_ram_in.waddr = reg_current.pein_base_addr + 
                reg_current.pein_out_ch_slice * reg_current.pein_fmap_h_size * reg_current.pein_fmap_w_size + 
                reg_current.pein_fmap_h * reg_current.pein_fmap_w_size + 
                reg_current.pein_fmap_w
                ;
      end
    end       

    if(reg_current.state.pein == BUFFER_WEIGHT_WORKING_ADD) begin      
      if( reg_current.Stage_1I_valid ) begin
        reg_next.buffer_ram_in.wren = 1;
        reg_next.buffer_ram_in.wdata = reg_current.Stage_1I_res;

        reg_next.pein_fmap_w = reg_current.pein_fmap_w + 1;     
        if(reg_current.pein_fmap_w == reg_current.pein_fmap_w_last) begin                     
          reg_next.pein_fmap_w = 0;                              

          reg_next.pein_fmap_h = reg_current.pein_fmap_h + 1;         
          if(reg_current.pein_fmap_h == reg_current.pein_fmap_h_last) begin  
            reg_next.pein_fmap_h = 0;      

            reg_next.pein_out_ch_slice = reg_current.pein_out_ch_slice + 1;         
            if(reg_current.pein_out_ch_slice == reg_current.pein_out_ch_slice_last) begin  
              reg_next.pein_out_ch_slice = 0;      

              reg_next.state.pein = BUFFER_WEIGHT_IDLE;                        
            end
          end
        end
        reg_next.buffer_ram_in.waddr = reg_current.pein_base_addr + 
                reg_current.pein_out_ch_slice * reg_current.pein_fmap_w_size * reg_current.pein_fmap_h_size + 
                reg_current.pein_fmap_h * reg_current.pein_fmap_h_size + 
                reg_current.pein_fmap_w
                ;

      end
    end  
    if(reg_current.state.pein == BUFFER_WEIGHT_WORKING_AVG) begin      
      if( reg_current.AVGStage_1E_valid ) begin
        reg_next.buffer_ram_in.wren = 1;
        reg_next.buffer_ram_in.wdata = reg_current.AVGStage_1E_res;
        
        reg_next.pein_out_ch_slice = reg_current.pein_out_ch_slice + 1;         
        if(reg_current.pein_out_ch_slice == reg_current.pein_out_ch_slice_last) begin  
          reg_next.pein_out_ch_slice = 0;      

          reg_next.state.pein = BUFFER_WEIGHT_IDLE;                        
        end
        reg_next.buffer_ram_in.waddr = reg_current.pein_base_addr + 
                reg_current.pein_out_ch_slice
                ;

      end
    end  
    
    //--mat in //
    
    

    //++axi_loader in //
    o_AL_ready = 0;

    if(reg_current.state.al_in == BUFFER_WEIGHT_WORKING)  begin
      if((reg_current.i_requant.command==0)) begin
        o_AL_ready = 1;
        
        reg_next.buffer_ram_in.wren = i_AL_valid;
        reg_next.buffer_ram_in.wdata = i_AL;

        if(i_AL_valid) begin
          reg_next.alin_idx = reg_current.alin_idx + 1;
          if(reg_current.alin_idx == reg_current.alin_end) begin
            reg_next.alin_idx = 0;
            reg_next.state.al_in = BUFFER_WEIGHT_IDLE;               
          end
        end

        reg_next.buffer_ram_in.waddr = reg_current.alin_idx; 
      end
    end
    //--axi_loader in //
    

    
    reg_next.Stage_1A_valid0 = 0;
    reg_next.Stage_1A_valid1 = 0;

    buffer_ram_user_resadd_buf = reg_current.buffer_ram_user_resadd_buf;
    if(BUFFER_ID != 0) 
      buffer_ram_user_resadd_buf = reg_current.addr_relay.buffer_ram_user_resadd_buf;

    if(buffer_ram_user_resadd_buf[3:0] == VALID_ADD) begin      
      reg_next.Stage_1A_res = $signed(reg_current.buffer_ram_read_data) - reg_current.peout_input_zp0;
      if(buffer_ram_user_resadd_buf & VALID_ADD1)
        reg_next.Stage_1A_res =$signed(reg_current.buffer_ram_read_data) -reg_current.peout_input_zp1;


      if(buffer_ram_user_resadd_buf & VALID_ADD1)
        reg_next.Stage_1A_valid1 = 1;    
      else
        reg_next.Stage_1A_valid0 = 1;  
    end

    reg_next.Stage_1B_valid0 = 0;
    reg_next.Stage_1B_valid1 = 0;
    if( reg_current.Stage_1A_valid0 ) begin
      reg_next.Stage_1B_res = reg_current.Stage_1A_res * reg_current.peout_rescale_int0;
      reg_next.Stage_1B_valid0 = 1;
    end
    if( reg_current.Stage_1A_valid1 ) begin
      reg_next.Stage_1B_res = reg_current.Stage_1A_res * reg_current.peout_rescale_int1;
      reg_next.Stage_1B_valid1 = 1;
    end

    reg_next.Stage_1C_res = reg_current.Stage_1B_res;
    reg_next.Stage_1C_valid0 = reg_current.Stage_1B_valid0;
    reg_next.Stage_1C_valid1 = reg_current.Stage_1B_valid1;
    reg_next.Stage_1D_res = reg_current.Stage_1C_res;
    reg_next.Stage_1D_valid0 = reg_current.Stage_1C_valid0;
        
    reg_next.Stage_1E_valid = 0;
    if( reg_current.Stage_1C_valid1 ) begin
      reg_next.Stage_1E_res = reg_current.Stage_1D_res + reg_current.Stage_1C_res;
      reg_next.Stage_1E_valid = 1;    
    end
    
    reg_next.Stage_1F_res = reg_current.Stage_1E_res;
    reg_next.Stage_1F_valid = reg_current.Stage_1E_valid;

    reg_next.Stage_1G_valid = 0;
    if( reg_current.Stage_1F_valid ) begin
      reg_next.Stage_1G_res = reg_current.Stage_1F_res[FSIZE+24-1:24];
      reg_next.Stage_1G_negative = reg_current.Stage_1F_res[FSIZE+24-1];
      reg_next.Stage_1G_roundup = reg_current.Stage_1F_res[23];
      reg_next.Stage_1G_valid = 1;
    end

    reg_next.Stage_1H_valid = 0;
    if( reg_current.Stage_1G_valid ) begin
      reg_next.Stage_1H_valid = 1;
      if(reg_current.Stage_1G_negative && reg_current.Stage_1G_roundup)begin
        reg_next.Stage_1H_res = reg_current.Stage_1G_res + 1;
      end
      else if(!reg_current.Stage_1G_negative && reg_current.Stage_1G_roundup)begin
        reg_next.Stage_1H_res = reg_current.Stage_1G_res + 1;
      end
      else begin
        reg_next.Stage_1H_res = reg_current.Stage_1G_res;
      end
    end

   
    //Stage 1E
    reg_next.Stage_1I_valid = 0;    
    if( reg_current.Stage_1H_valid ) begin
      reg_next.Stage_1I_res = reg_current.Stage_1H_res + reg_current.peout_output_zp;
      reg_next.Stage_1I_valid = 1; 
    end

    ////////


    reg_next.AVGStage_1B_valid = 0;
    if(buffer_ram_user_resadd_buf[3:0] == VALID_AVG) begin      
      reg_next.AVGStage_1A_res = $signed(reg_current.buffer_ram_read_data) + reg_current.AVGStage_1A_res;
      
      if(buffer_ram_user_resadd_buf & VALID_AVG_LAST) begin
        reg_next.AVGStage_1A_res = 0;
        reg_next.AVGStage_1B_res = $signed(reg_current.buffer_ram_read_data) + reg_current.AVGStage_1A_res;
        reg_next.AVGStage_1B_valid = 1;
      end
    end

    reg_next.AVGStage_1C_valid = 0;
    if( reg_current.AVGStage_1B_valid ) begin
      reg_next.AVGStage_1C_res = reg_current.AVGStage_1B_res * reg_current.peout_rescale_int0;
      reg_next.AVGStage_1C_valid = 1;
    end

    
    reg_next.AVGStage_1D_valid = 0;
    if( reg_current.AVGStage_1C_valid ) begin
      reg_next.AVGStage_1D_res = reg_current.AVGStage_1C_res[FSIZE+24-1:24];
      reg_next.AVGStage_1D_negative = reg_current.AVGStage_1C_res[FSIZE+24-1];
      reg_next.AVGStage_1D_roundup = reg_current.AVGStage_1C_res[23];
      reg_next.AVGStage_1D_valid = 1;
    end

    reg_next.AVGStage_1E_valid = 0;
    if( reg_current.AVGStage_1D_valid ) begin
      reg_next.AVGStage_1E_valid = 1;
    
      if(reg_current.AVGStage_1D_negative && reg_current.AVGStage_1D_roundup)begin
        reg_next.AVGStage_1E_res = reg_current.AVGStage_1D_res + 1;
      end
      else if(!reg_current.AVGStage_1D_negative && reg_current.AVGStage_1D_roundup)begin
        reg_next.AVGStage_1E_res = reg_current.AVGStage_1D_res + 1;
      end
      else begin
        reg_next.AVGStage_1E_res = reg_current.AVGStage_1D_res;
      end
    end

   
    reg_next.state_relay.pein = (reg_next.state.pein != BUFFER_WEIGHT_IDLE) ? BUFFER_WEIGHT_WORKING : BUFFER_WEIGHT_IDLE;
    reg_next.state_relay.peout = (reg_next.state.peout != BUFFER_WEIGHT_IDLE) ? BUFFER_WEIGHT_WORKING : BUFFER_WEIGHT_IDLE;
    reg_next.state_relay.al_in = (reg_next.state.al_in != BUFFER_WEIGHT_IDLE) ? BUFFER_WEIGHT_WORKING : BUFFER_WEIGHT_IDLE;


    reg_next.buffer_ram_in_b = reg_current.buffer_ram_in;

    if(rstn_b == 0) begin
      reg_next.state = '{default:'0};
      reg_next.state_relay = '{default:'0};
      reg_next.feed_started = 0;
    end

    ///outputs	  
    o_command  = reg_current.command_relay;   
    o_state    = reg_current.state_relay;    
    o_feed_started = reg_current.feed_started_relay;

     if(BUFFER_ID != 0) begin
       o_feed_started = 0;
     end

    o_addr_relay = reg_current.addr_relay;

    buffer_ram_user_buf = reg_current.buffer_ram_user_buf;
    if(BUFFER_ID!=0) begin    
      buffer_ram_user_buf = reg_current.addr_relay.buffer_ram_user_buf;
    end

    buffer_ram_inputs = reg_current.buffer_ram_in_b;
    if(BUFFER_ID!=0) begin
      buffer_ram_inputs.raddr = reg_current.addr_relay.raddr;
      buffer_ram_inputs.waddr = reg_current.addr_relay.waddr;
      buffer_ram_inputs.wren = reg_current.addr_relay.wren;
    end

      o_PE.data = reg_current.buffer_ram_read_data;
    o_PE.command = PE_COMMAND_IDLE;
    
    o_AW = reg_current.buffer_ram_read_data;
    o_AW_valid = 0;

    if(buffer_ram_user_buf[3:0] == VALID_LOAD) begin
      o_PE.command = PE_COMMAND_LOAD;      
       
      if(buffer_ram_user_buf & VALID_LOAD_TERMINAL) begin
        o_PE.command = PE_COMMAND_LOAD_TERMINAL;      
      end
    end        
    else if(buffer_ram_user_buf[3:0] == VALID_LOAD_BY_TOKEN) begin
      o_PE.command = PE_COMMAND_LOAD_BY_TOKEN;      
    end
    else if(buffer_ram_user_buf[3:0] == VALID_LT_FEED) begin
      o_PE.command = PE_COMMAND_LT_FEED;      
    end
    else if(buffer_ram_user_buf[3:0] == VALID_LT_FEED_POINT) begin
      o_PE.command = PE_COMMAND_LT_TURNING_POINT;      
      o_PE.data = reg_current.peout_transfer_repeat_stride;
    end
    else if(buffer_ram_user_buf[3:0] == VALID_SWITCH) begin
      o_PE.command = PE_COMMAND_SWITCH;
    end
    else if(buffer_ram_user_buf[3:0] == VALID_NORMAL) begin
      o_PE.command = PE_COMMAND_NORMAL;
      if(buffer_ram_user_buf & VALID_PADDING) begin
        o_PE.data = reg_current.peout_input_zp;
      end
    end
    else if(buffer_ram_user_buf[3:0] == VALID_FEED_TOKEN) begin
      o_PE.command = PE_COMMAND_FEEDTOKEN;
    end
    else if(buffer_ram_user_buf[3:0] == VALID_FEED) begin
      o_PE.command = PE_COMMAND_FEED;      
    end
    
    else if(buffer_ram_user_buf[3:0] == VALID_DUMP) begin
      o_AW_valid = 1;
    end
        
    o_weight_load_done = reg_current.weight_load_done;
    if(BUFFER_ID!=0) begin  
      o_weight_load_done = 0;
    end
    
    if(BUFFER_ID ==0) begin
      o_addr_relay.buffer_ram_user_buf = reg_current.buffer_ram_user_buf;
      o_addr_relay.buffer_ram_user_resadd_buf = reg_current.buffer_ram_user_resadd_buf;
      o_addr_relay.raddr = buffer_ram_inputs.raddr;
      o_addr_relay.waddr = buffer_ram_inputs.waddr;
      o_addr_relay.wren = buffer_ram_inputs.wren;
    end
  end
        
    
  always @ (posedge clk) begin
    rstn_b <= rstn;
    reg_current <= reg_next;
	end

endmodule
