`timescale 1 ns / 1 ns

`include "defines.vh"


import RISA_PKG::*;


module PE #(
		parameter ID_V        = 0,
		parameter ID_H        = 0
	) (
		input  logic					clk,	
    
    input PEInput     vert_in_input,
    output PEInput    vert_in_output,

    input PEResult    vert_out_input,
    output PEResult   vert_out_output,
    
    input PEInput     horz_in_input,
    output PEInput    horz_in_output,
    
    input PEInput     horz_out_input,
    output PEInput    horz_out_output
	);
  
  typedef struct packed {
    logic signed [QSIZE-1:0] stationary_register;
        
    logic[QSIZE-1:0] loading_register;
    logic loaded;

    PEInput vert_in_buf;        
    PEInput horz_in_buf;
    
    PEInput horz_out_buf;
    PEResult vert_out_buf;

    logic vert_in_to_next;
    logic horz_in_to_next;

    logic multiplier_valid;
    
    logic multiplier_valid_v;

    logic terminal;
    logic terminal_loading;

    logic lt_turning_point;
    logic [$clog2(ARRAY_HEIGHT)-1:0] feed_token;

    logic tt_wait;
    logic [$clog2(ARRAY_HEIGHT)-1:0] tt_wait_token;
    logic [QSIZE-1:0] tt_wait_data;


    logic mul_val;
    logic mul_val_b;
    logic mul_val_b2;
    logic signed [QSIZE*2-1:0]  mul_res;
    logic signed [QSIZE*2-1:0]  mul_res_b;
    logic signed [QSIZE*2-1:0]  mul_res_b2;
  
    logic done;
  } Registers;
  
  Registers reg_current,reg_next;
  

  always_comb begin

    reg_next = reg_current;
    reg_next.vert_in_buf = vert_in_input;    
    reg_next.vert_out_buf = vert_out_input;
    reg_next.horz_in_buf = horz_in_input;
    reg_next.horz_out_buf = horz_out_input;
    reg_next.vert_in_to_next = 0;
    reg_next.horz_in_to_next = 0;
    reg_next.multiplier_valid = 0 ;
    reg_next.multiplier_valid_v = 0 ;
    reg_next.vert_out_buf.valid = 0;

    if(horz_in_input.command == PE_COMMAND_RESET) begin
      reg_next.loaded = 0;
      reg_next.horz_in_to_next = 1;
      reg_next.lt_turning_point = 0;
      reg_next.feed_token = 0;
      
      reg_next.done = 0;
    end

    if( (horz_in_input.command == PE_COMMAND_SWITCH) ||
        (vert_in_input.command == PE_COMMAND_SWITCH)
        ) begin
      reg_next.stationary_register = reg_current.loading_register; 
      reg_next.terminal = reg_current.terminal_loading; 
      reg_next.loaded = 0;

      if(horz_in_input.command)
        reg_next.horz_in_to_next = 1;
      else
        reg_next.vert_in_to_next = 1;
    end

    if((vert_in_input.command == PE_COMMAND_LOAD || vert_in_input.command == PE_COMMAND_LOAD_TERMINAL)) begin      
      if(reg_current.loaded) begin
        reg_next.vert_in_to_next = 1;
      end
      else begin
        reg_next.loaded = 1;
        reg_next.loading_register = vert_in_input.data;

        reg_next.terminal_loading = 0;
        if(vert_in_input.command == PE_COMMAND_LOAD_TERMINAL) 
          reg_next.terminal_loading = 1;
      end
    end

    if((vert_in_input.command == PE_COMMAND_LOAD_BY_TOKEN)) begin      
      if(reg_current.feed_token>0) begin
        reg_next.feed_token = reg_current.feed_token - 1;
        reg_next.vert_in_to_next = 1;
      end
      else begin
        reg_next.loading_register = vert_in_input.data;
      end
    end

    if(vert_in_input.command == PE_COMMAND_LT_TURNING_POINT) begin      
      if(vert_in_input.data!=0 && ( (ID_V - ID_H) >= 0 && (ID_V - ID_H) % vert_in_input.data == 0 )) begin
        reg_next.lt_turning_point = 1;
      end
      else 
        reg_next.lt_turning_point = 0;

      reg_next.vert_in_to_next = 1;
    end
    if(vert_in_input.command == PE_COMMAND_LT_FEED) begin      
      if(reg_current.lt_turning_point) begin
        reg_next.horz_out_buf = vert_in_input;
      end
      else begin
      end
        reg_next.vert_in_to_next = 1;
    end


    if(vert_in_input.command == PE_COMMAND_FEEDTOKEN) begin      
      reg_next.feed_token = ID_V;
      reg_next.terminal_loading = 0;
        
      reg_next.vert_in_to_next = 1;
    end    
    if((vert_in_input.command == PE_COMMAND_FEED) ) begin      
      if(reg_current.feed_token>0) begin
        reg_next.feed_token = reg_current.feed_token - 1;
        reg_next.vert_in_to_next = 1;
      end
      else begin
        if(vert_in_input.command == PE_COMMAND_FEED ) begin
          if(ID_V == 0 ) begin            
            reg_next.horz_out_buf = vert_in_input;  
          end
          else begin
            reg_next.tt_wait_token = ID_V -1 ;
            reg_next.tt_wait = 1;
            reg_next.tt_wait_data = vert_in_input.data;  
          end
        end
      end
    end

    if(reg_current.tt_wait_token > 0) begin
      reg_next.tt_wait_token = reg_current.tt_wait_token -1;
    end
    if(reg_current.tt_wait && reg_current.tt_wait_token == 0) begin
      reg_next.tt_wait = 0;
      reg_next.horz_out_buf.command = PE_COMMAND_FEED;  
      reg_next.horz_out_buf.data = reg_current.tt_wait_data;  
    end

    if(horz_in_input.command == PE_COMMAND_NORMAL) begin      
      reg_next.multiplier_valid = 1;
      reg_next.horz_in_to_next = 1;
    end

    if(vert_in_input.command == PE_COMMAND_NORMAL) begin      
      reg_next.multiplier_valid_v = 1;

      if(!reg_current.terminal)
        reg_next.vert_in_to_next = 1;
    end

    reg_next.mul_val = 0;
    if(horz_in_input.command == PE_COMMAND_NORMAL) begin
      reg_next.mul_val = 1;
      reg_next.mul_res =  horz_in_input.data * reg_current.stationary_register;
    end
    if(vert_in_input.command == PE_COMMAND_NORMAL) begin
      reg_next.mul_val = 1;
      reg_next.mul_res =  vert_in_input.data * reg_current.stationary_register;
    end

    reg_next.mul_val_b = reg_current.mul_val;
    reg_next.mul_res_b = reg_current.mul_res;
    reg_next.mul_val_b2 = reg_current.mul_val_b;
    reg_next.mul_res_b2 = reg_current.mul_res_b;


    if(reg_current.mul_val_b2) begin
      reg_next.vert_out_buf.data =  reg_current.mul_res_b2 + vert_out_input.data;

      if(reg_current.terminal)
        reg_next.vert_out_buf.data =  reg_current.mul_res_b2;
      reg_next.vert_out_buf.valid = 1;
    end
   
    ///outputs    
    vert_in_output = reg_current.vert_in_buf;
    if(!reg_current.vert_in_to_next)
      vert_in_output.command = PE_COMMAND_IDLE;
    
    horz_in_output = reg_current.horz_in_buf;
    if(!reg_current.horz_in_to_next)
      horz_in_output.command = PE_COMMAND_IDLE;

    vert_out_output = reg_current.vert_out_buf;
    horz_out_output = reg_current.horz_out_buf;
  end
        
    
  always @ (posedge clk) begin
    reg_current <= reg_next;
	end

endmodule
