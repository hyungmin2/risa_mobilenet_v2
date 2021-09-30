`timescale 1 ns / 1 ns

`include "defines.vh"
import RISA_PKG::*;

module PE_Array #(
        parameter SIM_MODE        = 0
	) (
		input  logic					clk,		    		
		input  logic					rstn,			    	

    input logic [QSIZE-1:0] al_cb_data[0:ARRAY_WIDTH-1],
    input logic             al_cb_valid[0:ARRAY_WIDTH-1],
    output logic            al_cb_ready0[0:ARRAY_WIDTH-1],
    output logic            al_cb_ready1[0:ARRAY_WIDTH-1],

    output logic [QSIZE-1:0] aw_cb_data[0:ARRAY_WIDTH-1],
    output logic             aw_cb_valid[0:ARRAY_WIDTH-1],


    output BufferRAMTQsizeInputs cb_buffer_ram_inputs[0:ARRAY_WIDTH-1],
    input BufferRAMTQsizeOutputs cb_buffer_ram_outputs[0:ARRAY_WIDTH-1],
    output BufferRAMTRsizeInputs rq_buffer_ram_inputs[0:ARRAY_WIDTH-1],
    input BufferRAMTRsizeOutputs rq_buffer_ram_outputs[0:ARRAY_WIDTH-1],
    output BufferRAMTQsizeInputs rb_buffer_ram_inputs[0:ARRAY_HEIGHT-1],
    input BufferRAMTQsizeOutputs rb_buffer_ram_outputs[0:ARRAY_HEIGHT-1],
    
    input CommandDataPort i_commanddataport_h_cb,
    input CommandDataPort i_commanddataport_h_rq,
    input CommandDataPort i_commanddataport_h_rb,

    output BufferRowState o_stateport_h_rb,
    output BufferColumnState o_stateport_h_cb,
    output RequantState o_stateport_h_rq
	);
           
	genvar hi,vi;
    
  
  CommandDataPort       commanddataport_h_cb[0:ARRAY_WIDTH];
  CommandDataPort       commanddataport_h_rq[0:ARRAY_WIDTH];
  CommandDataPort       commanddataport_h_rb[0:ARRAY_HEIGHT];

  BufferRowState stateport_h_rb[0:ARRAY_HEIGHT];
  BufferColumnState stateport_h_cb[0:ARRAY_WIDTH];
  RequantState stateport_h_rq[0:ARRAY_WIDTH];

  logic weight_load_done_rb[0:ARRAY_HEIGHT];
  logic weight_load_done_cb[0:ARRAY_WIDTH-1];
  logic feed_started_cb[0:ARRAY_HEIGHT];
  logic feed_started_rb[0:ARRAY_HEIGHT];

  BufferRowRelayAddrs rb_addr_relay [0:ARRAY_HEIGHT];
  BufferColumnRelayAddrs cb_addr_relay [0:ARRAY_WIDTH];


  PEInput vert_in[0:ARRAY_HEIGHT][0:ARRAY_WIDTH-1];
  PEInput horz_in[0:ARRAY_HEIGHT-1][0:ARRAY_WIDTH];
  PEResult vert_out[0:ARRAY_HEIGHT][0:ARRAY_WIDTH-1];
  PEInput horz_out[0:ARRAY_HEIGHT-1][0:ARRAY_WIDTH];
  
  PEInput p_requant_cb[0:ARRAY_WIDTH-1];

          

  generate
    for(hi = 0; hi < ARRAY_WIDTH; hi ++) begin : internal_pipe_cap_v
      assign vert_out[0][hi].valid = 0; //tie end
      assign vert_out[0][hi].data = 0; //tie end
    end
    
    for(vi = 0; vi < ARRAY_HEIGHT; vi ++) begin : internal_pipe_cap_h
      assign horz_out[vi][ARRAY_WIDTH].command = PE_COMMAND_IDLE; //tie end
      assign horz_out[vi][ARRAY_WIDTH].data = 0; //tie end
    end
  endgenerate

  assign commanddataport_h_cb[0] = i_commanddataport_h_cb;
  assign commanddataport_h_rq[0] = i_commanddataport_h_rq;
  assign commanddataport_h_rb[0] = i_commanddataport_h_rb;

  assign o_stateport_h_cb = stateport_h_cb[0];
  assign o_stateport_h_rq = stateport_h_rq[0];
  assign o_stateport_h_rb = stateport_h_rb[0];

  assign feed_started_cb[0] = feed_started_rb[1];
  generate 
    for(hi = 0; hi < ARRAY_WIDTH; hi = hi+1) begin : buffer_column_gen
      (* keep = "true" *)BufferColumn #(.BUFFER_ID(hi)) cb(
        .rstn(rstn),
        .clk(clk),
        .i_command(commanddataport_h_cb[hi]),
        .o_command(commanddataport_h_cb[hi+1]),
        .o_state(stateport_h_cb[hi]),
        .i_state(stateport_h_cb[hi+1]),
        .o_PE(vert_in[ARRAY_HEIGHT][hi]),
        .i_requant(p_requant_cb[hi]),
        .o_weight_load_done(weight_load_done_cb[hi]),
        .i_feed_started(feed_started_cb[hi]),
        .o_feed_started(feed_started_cb[hi+1]),
        .i_AL(al_cb_data[hi]),
        .i_AL_valid(al_cb_valid[hi]),
        .o_AL_ready(al_cb_ready0[hi]),
        .o_AW(aw_cb_data[hi]),
        .o_AW_valid(aw_cb_valid[hi]),
        .buffer_ram_inputs(cb_buffer_ram_inputs[hi]),
        .buffer_ram_outputs(cb_buffer_ram_outputs[hi]),
        .i_addr_relay(cb_addr_relay[hi]),
        .o_addr_relay(cb_addr_relay[hi+1])
      );     
    end
    

    
    assign weight_load_done_rb[0] = weight_load_done_cb[0];
    assign feed_started_rb[0] = 1;

    for(vi = 0; vi < ARRAY_HEIGHT; vi = vi+1) begin : buffer_row_gen
      
     (* keep = "true" *)  BufferRow #(.BUFFER_ID(vi)) rb(
        .clk(clk),
        .rstn(rstn),
        .i_command(commanddataport_h_rb[vi]),
        .o_command(commanddataport_h_rb[vi+1]),
        .o_state(stateport_h_rb[vi]),
        .i_state(stateport_h_rb[vi+1]),        
        .o_PE(horz_in[vi][0]),
        .i_PE_relay(horz_out[vi][0]),
        .i_weight_load_done(weight_load_done_rb[vi]),
        .o_weight_load_done(weight_load_done_rb[vi+1]),
        .i_feed_started(feed_started_rb[vi]),
        .o_feed_started(feed_started_rb[vi+1]),
        .buffer_ram_inputs(rb_buffer_ram_inputs[vi]),
        .buffer_ram_outputs(rb_buffer_ram_outputs[vi]),
        .i_addr_relay(rb_addr_relay[vi]),
        .o_addr_relay(rb_addr_relay[vi+1])
      );  
    end
    
    for(vi = 0; vi < ARRAY_HEIGHT; vi = vi+1) begin : pe_v_gen
      for(hi = 0; hi < ARRAY_WIDTH; hi = hi+1) begin : pe_h_gen
        PE #(.ID_V(vi),.ID_H(hi)) pe(
          .clk(clk),          
          .vert_in_input      ( vert_in[vi+1][hi]        ),
          .vert_in_output     ( vert_in[vi][hi]      ),
          .vert_out_input  ( vert_out[vi][hi]  ),
          .vert_out_output ( vert_out[vi+1][hi]    ), 
          .horz_in_input      ( horz_in[vi][hi]        ),
          .horz_in_output     ( horz_in[vi][hi+1]      ),
          .horz_out_input   ( horz_out[vi][hi+1]   ),
          .horz_out_output  ( horz_out[vi][hi]     )
        );     
      end
    end    


    for(hi = 0; hi < ARRAY_WIDTH; hi = hi+1) begin : Requant_gen
     (* keep = "true" *)  Requant #(.ID(hi)) qt(
        .clk(clk),
        .rstn(rstn),
        .i_command(commanddataport_h_rq[hi]),
        .o_command(commanddataport_h_rq[hi+1]),
        .o_state(stateport_h_rq[hi]),
        .i_state(stateport_h_rq[hi+1]),
        .i_input(vert_out[ARRAY_HEIGHT][hi]),
        .o_output(p_requant_cb[hi]),
        .i_AL(al_cb_data[hi]),
        .i_AL_valid(al_cb_valid[hi]),
        .o_AL_ready(al_cb_ready1[hi]),
        .buffer_ram_inputs(rq_buffer_ram_inputs[hi]),
        .buffer_ram_outputs(rq_buffer_ram_outputs[hi])
      );  
    end
   
  endgenerate

endmodule
