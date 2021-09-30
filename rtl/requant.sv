`timescale 1 ns / 1 ns

`include "defines.vh"


import RISA_PKG::*;


module Requant #(
		parameter ID        = 0
		,parameter ILA        = 0
	) (
    input clk,

    input rstn,

    input CommandDataPort i_command,
    output CommandDataPort o_command,
    
    output RequantState o_state,
    input RequantState i_state,

    input PEResult i_input,
    output PEInput o_output,
    
    input  logic [QSIZE-1:0] i_AL,
    input logic i_AL_valid,
    output logic o_AL_ready,

    output BufferRAMTRsizeInputs buffer_ram_inputs,
    input BufferRAMTRsizeOutputs buffer_ram_outputs
	);
  logic rstn_b;


  localparam VALID_RELOAD       = (8'b00000001);
  localparam VALID_ACCUM_FIRST  = (8'b00000010);
  localparam VALID_ACCUM_LAST   = (8'b00000100);
  localparam VALID_LOG          = (8'b10000000);

  typedef struct packed{
    logic [COMMAND_WIDTH-1:0] command;        
    logic [FSIZE-1:0] command_data0;
    logic [FSIZE-1:0] command_data1;

    RequantState state;
    RequantState state_relay;

    CommandDataPort command_relay;

    logic signed [BUFFER_READ_LATENCY+1:0][RSIZE-1:0] input_buffer ;        
    logic [BUFFER_READ_LATENCY+1:0]input_buffer_valid;

    logic signed [QSIZE-1:0] result_buf;
    logic result_valid;

    logic [$clog2(32)-1:0] pein_skip;
    logic pein_stream;
        
    logic [COMMAND_WIDTH-1:0] requant_mode;
    
    logic [$clog2(FMAP_MAX_H)-1:0] pein_fmap_h;  
    logic [$clog2(FMAP_MAX_H)-1:0] pein_fmap_w;  
    logic [1:0] pein_filter_h;
    logic [1:0] pein_filter_w;
    logic [$clog2(SLICE_CONV_CH)-1:0] pein_in_ch_slice;
    logic [$clog2(SLICE_CONV_CH)-1:0] pein_out_ch_slice;

    logic [$clog2(MAX_CHANNEL)-1:0] pein_in_ch;
    logic [$clog2(MAX_CHANNEL)-1:0] pein_out_ch;

    logic [$clog2(FMAP_MAX_H)-1:0] pein_fmap_h_size;  
    logic [$clog2(FMAP_MAX_W)-1:0] pein_fmap_w_size;  
    logic [$clog2(FMAP_MAX_H)-1:0] pein_fmap_h_last;  
    logic [$clog2(FMAP_MAX_W)-1:0] pein_fmap_w_last;  
    logic [1:0] pein_filter_size;
    logic [1:0] pein_filter_last;
    logic [$clog2(SLICE_CONV_CH)-1:0] pein_in_ch_slice_last;
    logic [$clog2(SLICE_CONV_CH)-1:0] pein_out_ch_slice_last;

    logic [$clog2(SLICE_CONV_CH)-1:0] __bias_out_ch_slice;
    logic [$clog2(FMAP_MAX_H*FMAP_MAX_W)-1:0] __bias_out_ch_slice_count;
    logic [$clog2(SLICE_CONV_CH)-1:0] __rescale_out_ch_slice;
    logic [$clog2(FMAP_MAX_H*FMAP_MAX_W)-1:0] __rescale_out_ch_slice_count;

    logic [$clog2(FMAP_MAX_H)-1:0] accumin_fmap_h;  
    logic [$clog2(FMAP_MAX_W)-1:0] accumin_fmap_w;  
            
    logic begin_requant;          

    logic signed [FSIZE-1:0] Stage_1A_res; // input - input_zp_weight_accum
    logic Stage_1A_valid;          

    logic signed [FSIZE+24-1:0] Stage_1B_res;
    logic Stage_1B_valid;          
    
    logic signed [FSIZE+24-1:0] Stage_1C_res;
    logic Stage_1C_valid;          

    logic signed [FSIZE+24-1:0] Stage_1D_res;
    logic Stage_1D_valid;          
    
    logic signed [FSIZE-1:0] Stage_1E_res;
    logic Stage_1E_valid;          
    logic Stage_1E_negative;
    logic Stage_1E_roundup;

    logic signed [FSIZE-1:0] Stage_1F_res;
    logic Stage_1F_valid;          

    logic signed [FSIZE-1:0] output_zp;
    logic signed [FSIZE-1:0] Stage_1G_res;
    logic Stage_1G_valid;    

    BufferRAMTRsizeInputs buffer_ram_in;      
    BufferRAMTRsizeInputs buffer_ram_in_b;      
    logic [BUFFER_READ_LATENCY+1:0][USIZE-1:0] buffer_ram_user ;

    logic[7:0] layer_id;    
    logic relu;    
    logic[1:0] pein_stride;    

    logic signed [SLICE_CONV_CH-1:0][FSIZE-1:0] rescale_int;
    logic signed [SLICE_CONV_CH-1:0][FSIZE-1:0] bias_input_zp_weight_accum;
    
    logic [$clog2(SLICE_CONV_CH)-1:0] alin_ch_current;
    logic [$clog2(SLICE_CONV_CH)-1:0] alin_ch_last;
    logic [$clog2(8)-1:0] alin_ch_part;
    logic [2:0][QSIZE-1:0] alin_ch_part_data;
      
    logic dconv_discard_2nd_stream_last_line;    
  } Registers;
  
  Registers reg_current,reg_next;


  always_comb begin
    reg_next = reg_current;
    reg_next.command_relay = i_command;

    //Reset temp values;
    reg_next.command = 0;

    if(i_command.valid) begin
      reg_next.command = i_command.command;     
      reg_next.command_data0 = i_command.data0;       
      reg_next.command_data1 = i_command.data1;         
    end
    
    if(reg_current.command == REQUANT_MODESET_ACCUM_CONV0) begin
      reg_next.pein_fmap_w_size = reg_current.command_data0;
      reg_next.pein_fmap_h_size = reg_current.command_data1;
      reg_next.pein_fmap_w_last = reg_current.command_data0-1;
      reg_next.pein_fmap_h_last = reg_current.command_data1-1;
    end
    if(reg_current.command == REQUANT_MODESET_ACCUM_CONV1) begin
      reg_next.pein_in_ch_slice_last = reg_current.command_data0 -1;
      reg_next.pein_out_ch_slice_last = reg_current.command_data1 -1;
    end
    if(reg_current.command == REQUANT_MODESET_ACCUM_CONV2) begin
      reg_next.pein_filter_size = reg_current.command_data0;
      reg_next.pein_filter_last = reg_current.command_data0-1;
      reg_next.pein_stride = reg_current.command_data1;
    end
    if(reg_current.command == REQUANT_MODESET_ACCUM_CONV3) begin
      reg_next.output_zp = reg_current.command_data0;
    end
    if(reg_current.command == REQUANT_MODESET_ACCUM_CONV5) begin
      reg_next.pein_in_ch = reg_current.command_data0;
      reg_next.pein_out_ch = reg_current.command_data1;
    end
    if(reg_current.command == REQUANT_MODESET_ACCUM_CONV_LAYERID) begin
      reg_next.layer_id = reg_current.command_data0;
      reg_next.relu = reg_current.command_data1;

      reg_next.requant_mode = REQUANT_MODE_CONV;

      reg_next.pein_fmap_h = 0;
      reg_next.pein_fmap_w = 0;
      reg_next.pein_filter_h = 0;
      reg_next.pein_filter_w = 0;
      reg_next.pein_in_ch_slice = 0;
      reg_next.pein_out_ch_slice = 0;
      reg_next.accumin_fmap_h = 0;
      reg_next.accumin_fmap_w = 0;

      reg_next.pein_stream = 0;
    end
    
    if(reg_current.command == REQUANT_MODESET_ACCUM_DCONV_LAYERID) begin
      reg_next.layer_id = reg_current.command_data0;
 
      reg_next.requant_mode = REQUANT_MODE_DCONV;

      reg_next.pein_fmap_h = 0;
      reg_next.pein_fmap_w = 0;
      reg_next.pein_filter_h = 0;
      reg_next.pein_filter_w = 0;
      reg_next.pein_in_ch_slice = 0;
      reg_next.pein_out_ch_slice = 0;
      reg_next.accumin_fmap_h = 0;
      reg_next.accumin_fmap_w = 0;
      reg_next.pein_stream = 0;
      
      reg_next.pein_skip = reg_current.pein_filter_size * reg_current.pein_filter_size * 2 - 2;

      reg_next.pein_fmap_w_last = reg_current.pein_fmap_w_size -1;
      reg_next.pein_fmap_h_last = reg_current.pein_fmap_h_size/2-1;

      reg_next.dconv_discard_2nd_stream_last_line = 0;
      if(reg_current.pein_fmap_h_size[0] == 1) begin
        reg_next.pein_fmap_h_last = reg_next.pein_fmap_h_last + 1;
        reg_next.dconv_discard_2nd_stream_last_line = 1;
      end
    end

    if(reg_current.command == REQUANT_MODESET_LOAD_RQ) begin
      reg_next.state.al_in =  REQUANT_WORKING;      
      reg_next.alin_ch_current = 0;
      reg_next.alin_ch_part = 0;
      reg_next.alin_ch_last = reg_current.command_data0-1;
    end

    reg_next.result_buf = 0;
    reg_next.result_valid = 0;

    reg_next.buffer_ram_in.wren = 0;
    reg_next.buffer_ram_user[0] = 0;

    reg_next.begin_requant = 0;

    reg_next.input_buffer[0] = i_input.data;
    reg_next.input_buffer_valid[0] = i_input.valid;
        
    for(int i = 0; i < BUFFER_READ_LATENCY+1; i ++) begin
      reg_next.input_buffer[i+1] = reg_current.input_buffer[i];    
      reg_next.input_buffer_valid[i+1] = reg_current.input_buffer_valid[i];    
    end

    for(int i = 0; i < BUFFER_READ_LATENCY+1; i ++) begin
      reg_next.buffer_ram_user[i+1] = reg_current.buffer_ram_user[i];    
    end
    
    ///+++ normal convolution
    if(reg_current.requant_mode == REQUANT_MODE_CONV && i_input.valid) begin      
      reg_next.buffer_ram_user[0] = reg_next.buffer_ram_user[0] | VALID_RELOAD;

      reg_next.pein_fmap_w = reg_current.pein_fmap_w + 1;
      if(reg_current.pein_fmap_w == reg_current.pein_fmap_w_last)begin //FMAP_W -1
        reg_next.pein_fmap_w = 0;

        reg_next.pein_fmap_h = reg_current.pein_fmap_h + 1;
        if(reg_current.pein_fmap_h == reg_current.pein_fmap_h_last) begin //FMAP_H -1
          reg_next.pein_fmap_h = 0;

          reg_next.pein_in_ch_slice = reg_current.pein_in_ch_slice + 1;
          if(reg_current.pein_in_ch_slice == reg_current.pein_in_ch_slice_last) begin //SLICE_CONV1_IN -1
            reg_next.pein_in_ch_slice = 0;

            reg_next.pein_filter_w = reg_current.pein_filter_w + 1;
            if(reg_current.pein_filter_w == reg_current.pein_filter_last)begin //CONV1_K -1
              reg_next.pein_filter_w = 0;

              reg_next.pein_filter_h = reg_current.pein_filter_h + 1;
              if(reg_current.pein_filter_h == reg_current.pein_filter_last)begin //CONV1_K -1
                reg_next.pein_filter_h = 0;

                reg_next.pein_out_ch_slice = reg_current.pein_out_ch_slice + 1;
                if(reg_current.pein_out_ch_slice == reg_current.pein_out_ch_slice_last)begin //SLICE_CONV1_OUT -1
                  reg_next.pein_out_ch_slice = 0;
                
                end
              end
            end
          end  
        end  
      end

      if( reg_current.pein_in_ch_slice == 0 && reg_current.pein_filter_w == 0 && reg_current.pein_filter_h  == 0) begin
        reg_next.buffer_ram_user[0] = reg_next.buffer_ram_user[0] | VALID_ACCUM_FIRST;
      end
      
      if( reg_current.pein_out_ch_slice == 0 && reg_current.pein_fmap_w == 0 && reg_current.pein_fmap_h  == 0) begin
        reg_next.buffer_ram_user[0] = reg_next.buffer_ram_user[0] | VALID_LOG;
      end
      
      if( reg_current.pein_in_ch_slice == reg_current.pein_in_ch_slice_last && reg_current.pein_filter_w == reg_current.pein_filter_last && reg_current.pein_filter_h  == reg_current.pein_filter_last) begin
        reg_next.buffer_ram_user[0] = reg_next.buffer_ram_user[0] | VALID_ACCUM_LAST;
      end

      reg_next.buffer_ram_in.raddr = 
            reg_current.pein_fmap_h * reg_current.pein_fmap_w_size +
            reg_current.pein_fmap_w
            ;
    end
    ///--- normal convolution

    ///+++ depthwise convolution
    if(reg_current.requant_mode == REQUANT_MODE_DCONV && i_input.valid) begin  
      if( reg_current.pein_skip > 0 ) begin
        reg_next.pein_skip = reg_current.pein_skip - 1;        
      end
      else begin
        reg_next.begin_requant = 1;
        reg_next.input_buffer[0] = i_input.data;

        reg_next.pein_stream = !reg_current.pein_stream;
        if(reg_current.pein_stream) begin
          reg_next.pein_skip = reg_current.pein_filter_size * 2 * reg_current.pein_stride -1 -1;

          reg_next.pein_fmap_w = reg_current.pein_fmap_w + 1;     
          if(reg_current.pein_fmap_w == reg_current.pein_fmap_w_last) begin //FMAP_W-1
            reg_next.pein_fmap_w = 0;

            reg_next.pein_skip = reg_current.pein_filter_size * reg_current.pein_filter_size * 2 -1 -1;

            reg_next.pein_fmap_h = reg_current.pein_fmap_h + 1;         
            if(reg_current.pein_fmap_h == reg_current.pein_fmap_h_last) begin //FMAP_H-1
              reg_next.pein_fmap_h = 0;      

              reg_next.pein_out_ch_slice = reg_current.pein_out_ch_slice + 1;         
              if(reg_current.pein_out_ch_slice == reg_current.pein_out_ch_slice_last)begin //SLICE_CONV1_OUT -1
                reg_next.pein_out_ch_slice = 0;                                           
              end
            end
          end
        end

        if(reg_current.dconv_discard_2nd_stream_last_line &&  reg_current.pein_fmap_h == reg_current.pein_fmap_h_last && reg_current.pein_stream)
          reg_next.begin_requant = 0;
      end
      reg_next.buffer_ram_in.raddr = 
            (reg_current.pein_fmap_h*2 + reg_current.pein_stream) * reg_current.pein_fmap_w_size +
            reg_current.pein_fmap_w
            ;
    end
    ///--- depthwise convolution
    
    if((reg_current.buffer_ram_user[BUFFER_READ_LATENCY+1] & VALID_RELOAD) == VALID_RELOAD) begin
      if((reg_current.buffer_ram_user[BUFFER_READ_LATENCY+1] & VALID_ACCUM_FIRST) == VALID_ACCUM_FIRST) begin
        reg_next.buffer_ram_in.wdata = reg_current.input_buffer[BUFFER_READ_LATENCY+1];
      end
      else begin
        reg_next.buffer_ram_in.wdata = buffer_ram_outputs.rdata + reg_current.input_buffer[BUFFER_READ_LATENCY+1];
      end

      reg_next.buffer_ram_in.waddr = reg_current.accumin_fmap_h * reg_current.pein_fmap_w_size + reg_current.accumin_fmap_w;      
      reg_next.buffer_ram_in.wren = 1;

      reg_next.accumin_fmap_w = reg_current.accumin_fmap_w + 1;
      if(reg_current.accumin_fmap_w == reg_current.pein_fmap_w_last) begin
        reg_next.accumin_fmap_w = 0;

        reg_next.accumin_fmap_h = reg_current.accumin_fmap_h + 1;
        if(reg_current.accumin_fmap_h == reg_current.pein_fmap_h_last) begin
          reg_next.accumin_fmap_h = 0;
        end
      end

      if((reg_current.buffer_ram_user[BUFFER_READ_LATENCY+1] & VALID_ACCUM_LAST) == VALID_ACCUM_LAST)  begin
        reg_next.begin_requant = 1;
      end      
    end
    
    //Stage 1A
    reg_next.Stage_1A_valid = 0;
    if(reg_current.begin_requant) begin      
      // $display("accum(%d) accum:%d",ID, $signed(reg_current.buffer_ram_in.wdata));


      reg_next.Stage_1A_res = reg_current.buffer_ram_in.wdata + reg_current.bias_input_zp_weight_accum[reg_current.__bias_out_ch_slice];
      if(reg_current.requant_mode == REQUANT_MODE_DCONV)
        reg_next.Stage_1A_res = reg_current.input_buffer[0] + reg_current.bias_input_zp_weight_accum[reg_current.__bias_out_ch_slice];
      reg_next.Stage_1A_valid = 1;    

      reg_next.__bias_out_ch_slice_count = reg_current.__bias_out_ch_slice_count + 1;
      if(reg_current.__bias_out_ch_slice_count == reg_current.pein_fmap_w_size * reg_current.pein_fmap_h_size -1 ) begin
        reg_next.__bias_out_ch_slice_count = 0;

        reg_next.__bias_out_ch_slice = reg_current.__bias_out_ch_slice + 1;
        if(reg_current.__bias_out_ch_slice == reg_current.pein_out_ch_slice_last )begin
          reg_next.__bias_out_ch_slice = 0;
        end
      end
    end


    reg_next.Stage_1B_valid = 0;
    if( reg_current.Stage_1A_valid ) begin
      reg_next.Stage_1B_res = reg_current.Stage_1A_res * reg_current.rescale_int[reg_current.__rescale_out_ch_slice];
      reg_next.Stage_1B_valid = 1;

      reg_next.__rescale_out_ch_slice_count = reg_current.__rescale_out_ch_slice_count + 1;
      if(reg_current.__rescale_out_ch_slice_count == reg_current.pein_fmap_w_size * reg_current.pein_fmap_h_size -1 ) begin
        reg_next.__rescale_out_ch_slice_count = 0;

        reg_next.__rescale_out_ch_slice = reg_current.__rescale_out_ch_slice + 1;
        if(reg_current.__rescale_out_ch_slice == reg_current.pein_out_ch_slice_last ) begin
          reg_next.__rescale_out_ch_slice = 0;
        end
      end
    end

    

    reg_next.Stage_1C_res = reg_current.Stage_1B_res;
    reg_next.Stage_1C_valid = reg_current.Stage_1B_valid;
    reg_next.Stage_1D_res = reg_current.Stage_1C_res;
    reg_next.Stage_1D_valid = reg_current.Stage_1C_valid;

    reg_next.Stage_1E_valid = 0;
    if( reg_current.Stage_1D_valid ) begin
      reg_next.Stage_1E_res = reg_current.Stage_1D_res[FSIZE+24-1:24];
      reg_next.Stage_1E_negative = reg_current.Stage_1D_res[FSIZE+24-1];
      reg_next.Stage_1E_roundup = reg_current.Stage_1D_res[23];
      reg_next.Stage_1E_valid = 1;
    end

    reg_next.Stage_1F_valid = 0;
    if( reg_current.Stage_1E_valid ) begin
      reg_next.Stage_1F_valid = 1;
    
      if(reg_current.Stage_1E_negative && reg_current.relu) begin
        reg_next.Stage_1F_res = 0;
      end
      else if(reg_current.Stage_1E_negative && reg_current.Stage_1E_roundup)begin
        reg_next.Stage_1F_res = reg_current.Stage_1E_res + 1;
      end
      else if(!reg_current.Stage_1E_negative && reg_current.Stage_1E_roundup)begin
        reg_next.Stage_1F_res = reg_current.Stage_1E_res + 1;
      end
      else begin
        reg_next.Stage_1F_res = reg_current.Stage_1E_res;
      end
    end

   
    //Stage 1E
    reg_next.Stage_1G_valid = 0;    
    if( reg_current.Stage_1F_valid ) begin
      reg_next.Stage_1G_res = reg_current.Stage_1F_res + reg_current.output_zp;
      reg_next.Stage_1G_valid = 1;    
    end

    //State output
    if( reg_current.Stage_1G_valid ) begin
      reg_next.result_buf = ( reg_current.Stage_1G_res >= 127) ? 127 : (( reg_current.Stage_1G_res <= -128) ? -128 :  reg_current.Stage_1G_res);
      reg_next.result_valid = 1;
    end


    //++axi_loader in //
    o_AL_ready = 0;
    if(reg_current.state.al_in == REQUANT_WORKING) begin
      o_AL_ready = 1;
      if(i_AL_valid) begin
        reg_next.alin_ch_part = reg_current.alin_ch_part + 1;

        if(reg_current.alin_ch_part == 0) reg_next.alin_ch_part_data[0] = i_AL;
        if(reg_current.alin_ch_part == 1) reg_next.alin_ch_part_data[1] = i_AL;
        if(reg_current.alin_ch_part == 2) reg_next.alin_ch_part_data[2] = i_AL;
        if(reg_current.alin_ch_part == 3) begin
          reg_next.rescale_int[reg_current.alin_ch_current] = {i_AL,reg_next.alin_ch_part_data[2],reg_next.alin_ch_part_data[1],reg_next.alin_ch_part_data[0]};
        end 
        if(reg_current.alin_ch_part == 4) reg_next.alin_ch_part_data[0] = i_AL;
        if(reg_current.alin_ch_part == 5) reg_next.alin_ch_part_data[1] = i_AL;
        if(reg_current.alin_ch_part == 6) reg_next.alin_ch_part_data[2] = i_AL;
        if(reg_current.alin_ch_part == 7) begin
          reg_next.bias_input_zp_weight_accum[reg_current.alin_ch_current] = {i_AL,reg_next.alin_ch_part_data[2],reg_next.alin_ch_part_data[1],reg_next.alin_ch_part_data[0]};

          reg_next.alin_ch_part = 0;
          reg_next.alin_ch_current = reg_current.alin_ch_current + 1;
          if(reg_current.alin_ch_current == reg_current.alin_ch_last) begin
            reg_next.state.al_in = REQUANT_IDLE;  
          end
        end 
      end
    end    
    //--axi_loader in //
    


    //relay state
    if(ID != ARRAY_WIDTH-1 && i_state.al_in != REQUANT_IDLE) begin
      reg_next.state_relay.al_in = REQUANT_WORKING;
    end
    else begin
      reg_next.state_relay.al_in = (reg_next.state.al_in != REQUANT_IDLE) ? REQUANT_WORKING : REQUANT_IDLE;
    end   


    
    if(rstn_b==0)begin      
      reg_next.state = '{default:'0};
      reg_next.state_relay = '{default:'0};

      reg_next.__bias_out_ch_slice = 0;
      reg_next.__bias_out_ch_slice_count = 0;
      reg_next.__rescale_out_ch_slice = 0;
      reg_next.__rescale_out_ch_slice_count = 0;
    end


    ///outputs    
    o_command  = reg_current.command_relay;   
    o_state  = reg_current.state_relay;   

    o_output.data = reg_current.result_buf;   
    o_output.command = PE_COMMAND_IDLE;
    if(reg_current.result_valid)
      o_output.command = PE_COMMAND_NORMAL;

    reg_next.buffer_ram_in_b    = reg_current.buffer_ram_in;
    buffer_ram_inputs    = reg_current.buffer_ram_in_b;
  end
        
    
  always @ (posedge clk) begin
    rstn_b <= rstn;
    reg_current <= reg_next;
	end
  
endmodule
