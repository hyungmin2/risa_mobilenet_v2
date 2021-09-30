`timescale 1 ns / 1 ns

`include "defines.vh"

import RISA_PKG::*;

module BufferRow #(
		parameter BUFFER_ID        = 0
	) (
    input clk,

    input rstn,
    input CommandDataPort i_command,
    output CommandDataPort o_command,
    output BufferRowState o_state,
    input BufferRowState i_state,
    
    output PEInput o_PE,
    input PEInput i_PE_relay,
    
    input logic i_weight_load_done,
    output logic o_weight_load_done,

    input logic i_feed_started,
    output logic o_feed_started,

    output BufferRAMTQsizeInputs buffer_ram_inputs,
    input BufferRAMTQsizeOutputs buffer_ram_outputs,

    input BufferRowRelayAddrs i_addr_relay,
    output BufferRowRelayAddrs o_addr_relay
	);
  logic rstn_b;
  
  localparam VALID_PE       = (8'b00000001);
  localparam VALID_PE_RESET = (8'b00000010);
  localparam VALID_SWITCH   = (8'b00000100);
  localparam VALID_PADDING  = (8'b00001000);
  localparam VALID_LAST_PE_ID  = (8'b00100000);
  localparam VALID_ZERO     = (8'b00010000);

  typedef struct packed{
    logic [COMMAND_WIDTH-1:0] command;        
    logic [FSIZE-1:0]  command_data0;
    logic [FSIZE-1:0]  command_data1;
    logic  weight_load_done_relay;
    logic  weight_load_done;
    logic  feed_started;
    logic  feed_started_relay;

    BufferRowState state;
    BufferRowState state_relay;

    BufferRowRelayAddrs addr_relay;
        
    logic [$clog2(ARRAY_HEIGHT)-1:0] last_pe_id;  
    logic [$clog2(ARRAY_HEIGHT)-1:0] last_pe_id_buffer;  

    
    logic [1:0] sync_count;  
    
		logic [COMMAND_WIDTH-1:0] peout_conv_mode;        
    logic [$clog2(FMAP_MAX_H+1)-1:0] peout_fmap_h_idx;  
    logic [$clog2(FMAP_MAX_W+1)-1:0] peout_fmap_w_idx;  
    logic [$clog2(FMAP_MAX_H)-1:0] peout_fmap_h;  
    logic [$clog2(FMAP_MAX_W)-1:0] peout_fmap_w;  
    logic [1:0] peout_filter_h;
    logic [1:0] peout_filter_w;
    logic [$clog2(SLICE_CONV_CH)-1:0] peout_in_ch_slice;
    logic [$clog2(SLICE_CONV_CH)-1:0] peout_out_ch_slice;

    logic peout_padding;

    logic peout_switch;

    logic [$clog2(FMAP_MAX_H)-1:0] peout_fmap_h_size;  
    logic [$clog2(FMAP_MAX_W)-1:0] peout_fmap_w_size;  
    logic [$clog2(FMAP_MAX_H)-1:0] peout_fmap_h_last;  
    logic [$clog2(FMAP_MAX_W)-1:0] peout_fmap_w_last;  
    logic [1:0] peout_filter_size;
    logic [1:0] peout_filter_last;
    logic [$clog2(SLICE_CONV_CH)-1:0] peout_in_ch_slice_size;
    logic [$clog2(SLICE_CONV_CH)-1:0] peout_in_ch_slice_last;
    logic [$clog2(SLICE_CONV_CH)-1:0] peout_out_ch_slice_last;
    logic [$clog2(ARRAY_HEIGHT)-1:0] peout_repeat_num;

    logic [$clog2(MAX_CHANNEL)-1:0] peout_in_ch;

    BufferRAMTQsizeInputs buffer_ram_in;        
    BufferRAMTQsizeInputs buffer_ram_in_b;        
    logic [QSIZE-1:0] buffer_ram_read_data;
    logic [USIZE-1:0] buffer_ram_user_buf;
    
    CommandDataPort command_relay;
    
    logic [BUFFER_READ_LATENCY+2:0][USIZE-1:0] buffer_ram_user;

    logic [$clog2(BUFFER_QUANT_SIZE)-1:0] transfer_idx;
    logic [$clog2(BUFFER_QUANT_SIZE)-1:0] transfer_end;
    logic [$clog2(BUFFER_QUANT_SIZE)-1:0] transfer_idx1;
    logic [$clog2(BUFFER_QUANT_SIZE)-1:0] transfer_end1;
    logic trtransfer_stream;
    logic [$clog2(ARRAY_WIDTH/2+1)-1:0] trtransfer_skip;
    logic [$clog2(ARRAY_WIDTH/2+1)-1:0] trtransfer_skip1;

    logic [$clog2(BUFFER_QUANT_SIZE)-1:0] transfer_in_idx;
    logic [$clog2(BUFFER_QUANT_SIZE)-1:0] transfer_in_end;
    logic [$clog2(BUFFER_QUANT_SIZE)-1:0] transfer_chunk_idx;
    logic [$clog2(BUFFER_QUANT_SIZE)-1:0] transfer_chunk_last;
    logic [$clog2(BUFFER_QUANT_SIZE)-1:0] transfer_chunk_done_num;

    logic [$clog2(BUFFER_QUANT_SIZE)-1:0] peout_base_addr;
    logic [$clog2(BUFFER_QUANT_SIZE)-1:0] pein_base_addr;

    logic [1:0] peout_stride;
    
    logic [1:0] peout_pad;
    logic [QSIZE-1:0] peout_input_zp;
    logic [7:0] layer_id;    

    BufferRAMTQsizeOutputs buffer_ram_outputs;
  } Registers;
  
  Registers reg_current,reg_next;

  logic[USIZE-1:0] buffer_ram_user_buf;

  always_comb begin
    reg_next = reg_current;
    

    reg_next.command_relay = i_command;
    reg_next.weight_load_done_relay = i_weight_load_done;
    
    reg_next.feed_started_relay = 0;

    //Reset temp values;
    reg_next.command = 0;

    reg_next.buffer_ram_outputs = buffer_ram_outputs;


    reg_next.buffer_ram_in.raddr = 0;
    reg_next.buffer_ram_in.waddr = 0;
    reg_next.buffer_ram_in.wren = 0;
    reg_next.peout_padding = 0;

    if(i_weight_load_done) begin
      reg_next.weight_load_done = 1;
    end
    if(i_feed_started) begin
      reg_next.feed_started = 1;
    end

    reg_next.addr_relay = i_addr_relay;

    reg_next.buffer_ram_user[0] = 0;
    for(int i = 0; i < BUFFER_READ_LATENCY+2; i ++) begin
      reg_next.buffer_ram_user[i+1] = reg_current.buffer_ram_user[i];    
    end


    if(i_command.valid) begin
      reg_next.command = i_command.command;       
      reg_next.command_data0 = i_command.data0;       
      reg_next.command_data1 = i_command.data1;       
    end
    
    if(reg_current.command == BUFFER_QUANT_MODESET_PE_RESET) begin
      reg_next.buffer_ram_user[0] = reg_next.buffer_ram_user[0] | VALID_PE_RESET;
    end
    
    if(reg_current.command == BUFFER_QUANT_MODESET_CONV0) begin 
      reg_next.peout_fmap_h_size = reg_current.command_data0;
      reg_next.peout_fmap_w_size = reg_current.command_data1;
    end
    if(reg_current.command == BUFFER_QUANT_MODESET_CONV1) begin 
      reg_next.peout_in_ch_slice_size = reg_current.command_data0;
      reg_next.peout_in_ch_slice_last = reg_current.command_data0 -1;
      reg_next.peout_out_ch_slice_last = reg_current.command_data1 -1;
    end
    if(reg_current.command == BUFFER_QUANT_MODESET_CONV2) begin 
      reg_next.peout_filter_size = reg_current.command_data0;
      reg_next.peout_filter_last = reg_current.command_data0-1;
      reg_next.peout_stride = reg_current.command_data1;
    end
    if(reg_current.command == BUFFER_QUANT_MODESET_CONV3) begin 
      reg_next.peout_pad = reg_current.command_data0;              
      reg_next.peout_input_zp = reg_current.command_data1;              
    end    
    if(reg_current.command == BUFFER_QUANT_MODESET_CONV4) begin 
      reg_next.peout_base_addr = reg_current.command_data0;              
      reg_next.pein_base_addr = reg_current.command_data1;              
    end    
    if(reg_current.command == BUFFER_QUANT_MODESET_CONV5) begin 
      reg_next.peout_in_ch = reg_current.command_data0;              
    end           
    if(reg_current.command == BUFFER_QUANT_MODESET_CONV6) begin 
      reg_next.transfer_idx = reg_current.command_data0;
      reg_next.transfer_end = reg_current.command_data0 + reg_current.command_data1 - 1;
    end        
    if( reg_current.command == BUFFER_QUANT_MODESET_CONV_IN_TRANSFER_LAYERID) begin 
      reg_next.layer_id = reg_current.command_data0;
 
      reg_next.peout_fmap_h_last = reg_current.peout_fmap_h_size-reg_current.peout_stride;
      reg_next.peout_fmap_w_last = reg_current.peout_fmap_w_size-reg_current.peout_stride;

      reg_next.peout_fmap_h = 0;      
      reg_next.peout_fmap_w = 0;      
      reg_next.peout_filter_h = 0;
      reg_next.peout_filter_w = 0;
      reg_next.peout_in_ch_slice = 0;
      reg_next.peout_out_ch_slice = 0;  
      reg_next.peout_switch = 1;  
      reg_next.feed_started = 0;  

      reg_next.last_pe_id = reg_current.peout_in_ch % ARRAY_HEIGHT -1;
      reg_next.last_pe_id_buffer =ARRAY_HEIGHT -1;
            
      reg_next.state.peout =  BUFFER_QUANT_SYNC_CONV_TRANSFER;            

      reg_next.transfer_in_idx = reg_current.peout_base_addr;   
      reg_next.transfer_in_end = reg_current.peout_base_addr + reg_current.peout_in_ch_slice_size * reg_current.peout_fmap_h_size * reg_current.peout_fmap_w_size - 1;

      reg_next.transfer_chunk_idx = 0;
      reg_next.transfer_chunk_done_num = 0;
      reg_next.transfer_chunk_last = reg_current.peout_fmap_h_size * reg_current.peout_fmap_w_size - 1;

      reg_next.state.pein = BUFFER_QUANT_TRANSFER_IN_ONLY;

      reg_next.peout_fmap_h_idx = 0 - reg_current.peout_pad;
      reg_next.peout_fmap_w_idx = 0 - reg_current.peout_pad;

      if(reg_next.peout_fmap_h_idx >= reg_current.peout_fmap_h_size ||reg_next.peout_fmap_w_idx >=reg_current.peout_fmap_w_size ) reg_next.peout_padding = 1;

      reg_next.sync_count = 2;    //adding 2 to make sure the weights are loaded      
    end

    if(reg_current.command == BUFFER_QUANT_MODESET_ICONV0) begin 
      reg_next.peout_fmap_h_size = reg_current.command_data0;
      reg_next.peout_fmap_w_size = reg_current.command_data1;
    end
    if(reg_current.command == BUFFER_QUANT_MODESET_ICONV1) begin 
      reg_next.peout_out_ch_slice_last = reg_current.command_data1 -1;
    end
    if(reg_current.command == BUFFER_QUANT_MODESET_ICONV2) begin 
      reg_next.peout_filter_size = reg_current.command_data0;
      reg_next.peout_stride = reg_current.command_data1;
    end
    if(reg_current.command == BUFFER_QUANT_MODESET_ICONV3) begin 
      reg_next.peout_pad = reg_current.command_data0;              
      reg_next.peout_input_zp = reg_current.command_data1;              
    end    
    if(reg_current.command == BUFFER_QUANT_MODESET_ICONV4) begin 
      reg_next.peout_base_addr = reg_current.command_data0;              
    end    
    if(reg_current.command == BUFFER_QUANT_MODESET_ICONV5) begin 
      reg_next.peout_in_ch = reg_current.command_data0;              
    end    
    if(reg_current.command == BUFFER_QUANT_MODESET_ICONV6) begin 
      reg_next.peout_repeat_num = reg_current.command_data0;
    end        
    if(reg_current.command == BUFFER_QUANT_MODESET_ICONV_LAYERID) begin 
      reg_next.layer_id = reg_current.command_data0;
 
      reg_next.peout_fmap_h_last = reg_current.peout_fmap_h_size-reg_current.peout_stride;
      reg_next.peout_fmap_w_last = reg_current.peout_fmap_w_size-reg_current.peout_stride;

      reg_next.state.peout =  BUFFER_QUANT_SYNC_ICONV;      
      
      reg_next.peout_fmap_h = 0;      
      reg_next.peout_fmap_w = 0;      
      reg_next.peout_out_ch_slice = 0;  
      reg_next.peout_switch = 1;  

      reg_next.peout_fmap_h_idx = 0 - reg_current.peout_pad;
      reg_next.peout_fmap_w_idx = 0 - reg_current.peout_pad;

      if(reg_next.peout_fmap_h_idx >= reg_current.peout_fmap_h_size || reg_next.peout_fmap_w_idx >= reg_current.peout_fmap_w_size ) reg_next.peout_padding = 1;

      reg_next.feed_started = 0;  

      reg_next.sync_count = 2;   //adding 2 to make sure the weights are loaded  

      reg_next.last_pe_id = IN_FMAP_CH*L1_CONV_FILTER_K*L1_CONV_FILTER_K-1;
      reg_next.last_pe_id_buffer = IN_FMAP_CH*L1_CONV_FILTER_K*L1_CONV_FILTER_K-1;
    end

    if(reg_current.command == BUFFER_QUANT_MODESET_TRTRANSFER0) begin
      reg_next.transfer_idx = reg_current.command_data0;
      reg_next.transfer_idx1 = reg_current.command_data1;
    end
    if(reg_current.command == BUFFER_QUANT_MODESET_TRTRANSFER1) begin
      reg_next.state.pein = BUFFER_QUANT_TRTRANSFER;
      reg_next.trtransfer_stream = 0;
      reg_next.trtransfer_skip = 0;
      reg_next.trtransfer_skip1 = ARRAY_WIDTH/2;

      reg_next.transfer_end = reg_current.transfer_idx + reg_current.command_data0 - 1;
      reg_next.transfer_end1 = reg_current.transfer_idx1 + reg_current.command_data0 - 1;

      reg_next.layer_id = reg_current.command_data1;

      reg_next.last_pe_id = ARRAY_HEIGHT-1;
      reg_next.last_pe_id_buffer = ARRAY_HEIGHT-1;
    end

    if( reg_current.state.peout == BUFFER_QUANT_SYNC_ICONV || reg_current.state.peout == BUFFER_QUANT_SYNC_CONV_TRANSFER ) begin
      if(reg_current.sync_count == 0) begin
        if(reg_current.state.peout == BUFFER_QUANT_SYNC_ICONV) 
          reg_next.state.peout =  BUFFER_QUANT_WORKING_ICONV;        
        else if(reg_current.state.peout == BUFFER_QUANT_SYNC_CONV_TRANSFER)  
          reg_next.state.peout =  BUFFER_QUANT_WORKING_CONV_TRANSFER;        
      end
      else begin
        reg_next.sync_count = reg_current.sync_count - 1;
      end
    end



    //++mat out //
    if(reg_current.state.peout == BUFFER_QUANT_WORKING_CONV_TRANSFER) begin
      if( reg_current.peout_switch ) begin
        if(reg_current.state.peout == BUFFER_QUANT_WORKING_CONV_TRANSFER) begin
          if(reg_current.weight_load_done == 1&& reg_current.feed_started == 1 && reg_current.transfer_chunk_done_num > reg_current.peout_in_ch_slice ) begin
            reg_next.weight_load_done = 0;
            reg_next.feed_started = 0;
            reg_next.buffer_ram_user[0] = reg_next.buffer_ram_user[0] | VALID_SWITCH;
            reg_next.peout_switch = 0;
          end          
        end
      end
      else begin
        reg_next.buffer_ram_user[0] = reg_next.buffer_ram_user[0] | VALID_PE;

        reg_next.peout_fmap_w_idx = reg_current.peout_fmap_w_idx + reg_current.peout_stride;
        reg_next.peout_fmap_w = reg_current.peout_fmap_w + reg_current.peout_stride;
        if(reg_current.peout_fmap_w == reg_current.peout_fmap_w_last) begin 
          reg_next.peout_fmap_w = 0;
          reg_next.peout_fmap_w_idx = 0 - reg_current.peout_pad + reg_current.peout_filter_w;

          reg_next.peout_fmap_h_idx = reg_current.peout_fmap_h_idx + reg_current.peout_stride;
          reg_next.peout_fmap_h = reg_current.peout_fmap_h + reg_current.peout_stride;
          if(reg_current.peout_fmap_h == reg_current.peout_fmap_h_last) begin 
            reg_next.peout_fmap_h = 0;
            reg_next.peout_fmap_h_idx = 0 - reg_current.peout_pad + reg_current.peout_filter_h;

            reg_next.peout_switch = 1;

            
            reg_next.peout_in_ch_slice = reg_current.peout_in_ch_slice + 1;          

            if(reg_current.peout_in_ch_slice == reg_current.peout_in_ch_slice_last ) begin
              reg_next.peout_in_ch_slice = 0;

              reg_next.peout_filter_w = reg_current.peout_filter_w + 1;    
              reg_next.peout_fmap_w_idx = 0 - reg_current.peout_pad + reg_next.peout_filter_w;      
              if(reg_current.peout_filter_w == reg_current.peout_filter_last ) begin
                reg_next.peout_filter_w = 0;
                reg_next.peout_fmap_w_idx = 0 - reg_current.peout_pad + 0;      
              
                reg_next.peout_filter_h = reg_current.peout_filter_h + 1;          
                reg_next.peout_fmap_h_idx = 0 - reg_current.peout_pad + reg_next.peout_filter_h;                    
                if(reg_current.peout_filter_h == reg_current.peout_filter_last ) begin
                  reg_next.peout_filter_h = 0;
                  reg_next.peout_fmap_h_idx = 0 - reg_current.peout_pad + 0;                    

                  reg_next.peout_out_ch_slice = reg_current.peout_out_ch_slice + 1;          
                  if(reg_current.peout_out_ch_slice == reg_current.peout_out_ch_slice_last ) begin
                    reg_next.peout_out_ch_slice = 0;

                    reg_next.state.peout = BUFFER_QUANT_IDLE;     
                  end
                end
              end
            end
          end  
        end

        if(reg_next.peout_fmap_h_idx >= reg_current.peout_fmap_h_size || reg_next.peout_fmap_w_idx >= reg_current.peout_fmap_w_size ) reg_next.peout_padding = 1;

        reg_next.buffer_ram_in.raddr = reg_current.peout_base_addr + 
                reg_current.peout_in_ch_slice * reg_current.peout_fmap_h_size * reg_current.peout_fmap_w_size + 
                reg_current.peout_fmap_h_idx * reg_current.peout_fmap_w_size + 
                reg_current.peout_fmap_w_idx
                ;


        if(reg_current.peout_in_ch_slice == reg_current.peout_in_ch_slice_last ) begin
          reg_next.buffer_ram_user[0] = reg_next.buffer_ram_user[0] | VALID_LAST_PE_ID;
        end

        if(reg_current.peout_padding) begin
          reg_next.buffer_ram_user[0] = reg_next.buffer_ram_user[0] | VALID_PADDING;
        end

        if(reg_current.peout_in_ch_slice * ARRAY_HEIGHT + BUFFER_ID >= reg_current.peout_in_ch)  begin
          reg_next.buffer_ram_user[0] = reg_next.buffer_ram_user[0] | VALID_ZERO;
        end
      end
    end
    

    if(reg_current.state.peout == BUFFER_QUANT_WORKING_ICONV) begin
      if( reg_current.peout_switch ) begin
        if(reg_current.weight_load_done == 1&& reg_current.feed_started == 1 ) begin
          reg_next.buffer_ram_user[0] = reg_next.buffer_ram_user[0] | VALID_SWITCH;
          reg_next.weight_load_done = 0;
          reg_next.feed_started = 0;
          reg_next.peout_switch = 0;
        end
      end
      else begin
        reg_next.buffer_ram_user[0] = reg_next.buffer_ram_user[0] | VALID_PE;

        reg_next.peout_fmap_w_idx = reg_current.peout_fmap_w_idx + reg_current.peout_stride;
        reg_next.peout_fmap_w = reg_current.peout_fmap_w + reg_current.peout_stride;
        if(reg_current.peout_fmap_w == reg_current.peout_fmap_w_last) begin 
          reg_next.peout_fmap_w = 0;
          reg_next.peout_fmap_w_idx = 0 - reg_current.peout_pad ;

          reg_next.peout_fmap_h_idx = reg_current.peout_fmap_h_idx + reg_current.peout_stride;
          reg_next.peout_fmap_h = reg_current.peout_fmap_h + reg_current.peout_stride;
          if(reg_current.peout_fmap_h == reg_current.peout_fmap_h_last) begin
            reg_next.peout_fmap_h = 0;
            reg_next.peout_fmap_h_idx = 0 - reg_current.peout_pad;

            reg_next.peout_switch = 1;            

            reg_next.peout_fmap_w_idx = 0 - reg_current.peout_pad;
            reg_next.peout_fmap_h_idx = 0 - reg_current.peout_pad;

            reg_next.peout_out_ch_slice = reg_current.peout_out_ch_slice + 1;          
            if(reg_current.peout_out_ch_slice == reg_current.peout_out_ch_slice_last ) begin 
              reg_next.peout_out_ch_slice = 0;
              reg_next.state.peout = BUFFER_QUANT_IDLE;   
            end
          end  
        end

        if(reg_next.peout_fmap_h_idx >= reg_current.peout_fmap_h_size || reg_next.peout_fmap_w_idx >= reg_current.peout_fmap_w_size ) reg_next.peout_padding = 1;

        reg_next.buffer_ram_in.raddr = 0 + 
                reg_current.peout_fmap_h_idx * reg_current.peout_fmap_w_size + 
                reg_current.peout_fmap_w_idx
                ;

        if(reg_current.peout_padding) begin
          reg_next.buffer_ram_user[0] = reg_next.buffer_ram_user[0] | VALID_PADDING;
        end

        if(BUFFER_ID >= reg_current.peout_in_ch * reg_current.peout_repeat_num)  begin
          reg_next.buffer_ram_user[0] = reg_next.buffer_ram_user[0] | VALID_ZERO;
        end

        reg_next.buffer_ram_user[0] = reg_next.buffer_ram_user[0] | VALID_LAST_PE_ID;
      end
    end


    reg_next.buffer_ram_read_data = reg_current.buffer_ram_outputs.rdata;
    reg_next.buffer_ram_user_buf = reg_current.buffer_ram_user[BUFFER_READ_LATENCY+2];    
    //--mat out //

    //++mat in //
    if(reg_current.state.pein == BUFFER_QUANT_TRANSFER_IN_ONLY ) begin
      if(i_PE_relay.command) begin

        reg_next.buffer_ram_in.wren = 1;
        reg_next.buffer_ram_in.wdata = i_PE_relay.data;

        reg_next.transfer_in_idx = reg_current.transfer_in_idx + 1;        
        reg_next.transfer_chunk_idx = reg_current.transfer_chunk_idx + 1;        
        
        if(reg_current.transfer_chunk_idx == 1 || reg_current.transfer_chunk_last == 0) begin
          reg_next.transfer_chunk_done_num = reg_current.transfer_chunk_done_num + 1;          
        end
        if(reg_current.transfer_chunk_idx == reg_current.transfer_chunk_last) begin
          reg_next.transfer_chunk_idx = 0;
        end
        

        if(reg_current.transfer_in_idx == reg_current.transfer_in_end) begin
          reg_next.transfer_in_idx = 0;
          reg_next.state.pein = BUFFER_QUANT_IDLE;          
        end       
      end

      reg_next.buffer_ram_in.waddr = reg_current.transfer_in_idx;
    end
    if(reg_current.state.pein == BUFFER_QUANT_TRTRANSFER) begin
      if(i_PE_relay.command) begin
        reg_next.buffer_ram_in.wren = 1;
        reg_next.buffer_ram_in.wdata = i_PE_relay.data;

        
        if( (reg_current.trtransfer_stream == 0 && reg_current.trtransfer_skip==0) || (reg_current.trtransfer_skip1>0) ) begin
          if(reg_current.trtransfer_skip1>0) begin
            reg_next.trtransfer_skip1 = reg_current.trtransfer_skip1-1;        
          end
          else begin
            reg_next.trtransfer_stream = !reg_current.trtransfer_stream;
          end

          if(reg_current.transfer_idx % ARRAY_WIDTH == ARRAY_WIDTH-1) reg_next.trtransfer_skip = 1;

          reg_next.transfer_idx = reg_current.transfer_idx + 1;   
          if(reg_current.transfer_idx == reg_current.transfer_end) begin
            reg_next.transfer_idx = 0;
            reg_next.trtransfer_skip = ARRAY_WIDTH/2;
          end

        end
        else begin
          if(reg_current.trtransfer_skip>0) begin            
            reg_next.trtransfer_skip = reg_current.trtransfer_skip-1;
          end
          else begin
            reg_next.trtransfer_stream = !reg_current.trtransfer_stream;
          end
          
          if(reg_current.transfer_idx1 % ARRAY_WIDTH == ARRAY_WIDTH-1) reg_next.trtransfer_skip1 = 1;

          reg_next.transfer_idx1 = reg_current.transfer_idx1 + 1;   
          if(reg_current.transfer_idx1 == reg_current.transfer_end1) begin
            reg_next.transfer_idx1 = 0;
            reg_next.state.pein = BUFFER_QUANT_IDLE;               
          end

        end
        

        if( reg_current.trtransfer_stream==1 ) 
          reg_next.buffer_ram_in.waddr = reg_current.transfer_idx1;
        else
          reg_next.buffer_ram_in.waddr = reg_current.transfer_idx;
      end

      

    end
    //--mat in //

    //relay state
    reg_next.state_relay.fin = (reg_next.state.fin != BUFFER_QUANT_IDLE) ? BUFFER_QUANT_WORKING : BUFFER_QUANT_IDLE;
    reg_next.state_relay.pein = (reg_next.state.pein != BUFFER_QUANT_IDLE) ? BUFFER_QUANT_WORKING : BUFFER_QUANT_IDLE;
    reg_next.state_relay.peout = reg_next.state.peout;

    reg_next.buffer_ram_in_b = reg_current.buffer_ram_in;    

    if(rstn_b == 0) begin
      reg_next.state = '{default:'0};
      reg_next.state_relay = '{default:'0};
      reg_next.weight_load_done = 0;
      reg_next.peout_switch = 0;
      reg_next.feed_started = 0;
      reg_next.last_pe_id = ARRAY_HEIGHT-1;
      reg_next.last_pe_id_buffer = ARRAY_HEIGHT-1;
    end

    //outputs

    o_command = reg_current.command_relay;   
    o_state   = reg_current.state_relay;        
    o_weight_load_done = reg_current.weight_load_done_relay;   
    o_feed_started = 0;

    o_addr_relay = reg_current.addr_relay;

    if(BUFFER_ID!=0) begin
      o_feed_started = o_addr_relay.feed_started;
    end
    else begin
      if(reg_current.state.peout == BUFFER_QUANT_WORKING_CONV_TRANSFER &&  reg_current.peout_switch && reg_current.weight_load_done == 1 && reg_current.feed_started == 1 && reg_current.transfer_chunk_done_num > reg_current.peout_in_ch_slice) begin
        o_feed_started = 1;
      end
      if(reg_current.state.peout == BUFFER_QUANT_WORKING_ICONV &&  reg_current.peout_switch && reg_current.weight_load_done == 1 && reg_current.feed_started == 1) begin
          o_feed_started = 1;
      end
    end

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

    if(buffer_ram_user_buf & VALID_PE) begin
      o_PE.command = PE_COMMAND_NORMAL;      
      if(buffer_ram_user_buf & VALID_ZERO) begin
        o_PE.data = 0;
      end
      else if(buffer_ram_user_buf & VALID_PADDING) begin
        o_PE.data = reg_current.peout_input_zp;
      end
    end        
    else if(buffer_ram_user_buf & VALID_SWITCH) begin
      o_PE.command = PE_COMMAND_SWITCH;
    end 
    else if(buffer_ram_user_buf & VALID_PE_RESET) begin
      o_PE.command = PE_COMMAND_RESET;
    end
 
    if(BUFFER_ID ==0) begin
      o_addr_relay.last_pe_id = reg_current.last_pe_id;
      o_addr_relay.last_pe_id_buffer= reg_current.last_pe_id_buffer;
      o_addr_relay.feed_started = o_feed_started;
      o_addr_relay.buffer_ram_user_buf = reg_current.buffer_ram_user_buf;
      o_addr_relay.raddr = buffer_ram_inputs.raddr;
      o_addr_relay.waddr = buffer_ram_inputs.waddr;
      o_addr_relay.wren = buffer_ram_inputs.wren;
    end

    if(BUFFER_ID != 0 && BUFFER_ID == reg_current.addr_relay.last_pe_id) begin
      if((reg_current.addr_relay.buffer_ram_user_buf & (VALID_PE | VALID_LAST_PE_ID)) == (VALID_PE | VALID_LAST_PE_ID)) begin
        o_addr_relay.buffer_ram_user_buf  = VALID_PE | VALID_LAST_PE_ID | VALID_ZERO;
      end
    end
    if(BUFFER_ID != 0 &&  BUFFER_ID == reg_current.addr_relay.last_pe_id_buffer) begin
      o_addr_relay.wren = 0;
      o_addr_relay.waddr = 0;
    end

  end
    
  always @ (posedge clk) begin
    rstn_b <= rstn;
    reg_current <= reg_next;
	end

endmodule
