`timescale 1 ns / 1 ns

`include "defines.vh"
import RISA_PKG::*;

module risa_top #(
        parameter SIM_MODE        = 0
	) (
		input logic	clk,		    		
		input logic rstn,			

    input logic [QSIZE-1:0] al_bw_data[0:ARRAY_WIDTH-1],
    input logic             al_bw_valid[0:ARRAY_WIDTH-1],
    output logic            al_bw_ready0[0:ARRAY_WIDTH-1],
    output logic            al_bw_ready1[0:ARRAY_WIDTH-1],
    output logic            aw_bw_valid[0:ARRAY_WIDTH-1],
    output logic [QSIZE-1:0] aw_bw_data[0:ARRAY_WIDTH-1],

    input logic [STATE_WIDTH-1:0] stateport_al,
    output CommandDataPort       commanddataport_al  ,

    input CommandDataPort i_commanddataport_h_cb,
    input CommandDataPort i_commanddataport_h_rq,
    input CommandDataPort i_commanddataport_h_rb,
    input CommandDataPort  i_commanddataport_al,

    output BufferRowState o_stateport_h_rb,
    output BufferColumnState o_stateport_h_cb,
    output RequantState o_stateport_h_rq,
    output logic [STATE_WIDTH-1:0] o_stateport_al
	);
             
  BufferRAMTQsizeInputs bw_buffer_ram_inputs[0:ARRAY_WIDTH-1];
  BufferRAMTQsizeOutputs bw_buffer_ram_outputs[0:ARRAY_WIDTH-1];
  BufferRAMTRsizeInputs rq_buffer_ram_inputs[0:ARRAY_WIDTH-1];
  BufferRAMTRsizeOutputs rq_buffer_ram_outputs[0:ARRAY_WIDTH-1];
  BufferRAMTQsizeInputs bq_buffer_ram_inputs[0:ARRAY_HEIGHT-1];
  BufferRAMTQsizeOutputs bq_buffer_ram_outputs[0:ARRAY_HEIGHT-1];
    
  PE_Array #(.SIM_MODE(SIM_MODE)) pe_array( 
    .clk(clk),
    .rstn(rstn),
        
    .al_cb_data   (al_bw_data),
    .al_cb_valid  (al_bw_valid),
    .al_cb_ready0  (al_bw_ready0),
    .al_cb_ready1  (al_bw_ready1),
    .aw_cb_valid  (aw_bw_valid),
    .aw_cb_data  (aw_bw_data),
    
    .cb_buffer_ram_inputs(bw_buffer_ram_inputs),
    .cb_buffer_ram_outputs(bw_buffer_ram_outputs),
    .rq_buffer_ram_inputs(rq_buffer_ram_inputs),
    .rq_buffer_ram_outputs(rq_buffer_ram_outputs),
    .rb_buffer_ram_inputs(bq_buffer_ram_inputs),
    .rb_buffer_ram_outputs(bq_buffer_ram_outputs),

    .i_commanddataport_h_cb(i_commanddataport_h_cb),
    .i_commanddataport_h_rq(i_commanddataport_h_rq),
    .i_commanddataport_h_rb(i_commanddataport_h_rb),

    .o_stateport_h_rb(o_stateport_h_rb),
    .o_stateport_h_cb(o_stateport_h_cb),
    .o_stateport_h_rq(o_stateport_h_rq)
  );  	

  assign o_stateport_al = stateport_al;
  assign commanddataport_al = i_commanddataport_al;
           	   	
  genvar gi;

  generate
  for(gi = 0; gi < ARRAY_WIDTH; gi++) begin : bw_gen
    BufferRAMTQsize # (
        .ID(gi),
        .DEPTH(BUFFER_WEIGHT_SIZE),
        .READ_LATENCY(BUFFER_READ_LATENCY))
      bw (
        .clk(clk),
        .inputs(bw_buffer_ram_inputs[gi]),
        .outputs(bw_buffer_ram_outputs[gi])
      );      
    BufferRAMTRsize # (
        .ID(gi),
        .DEPTH(BUFFER_ACCUM_SIZE),
        .READ_LATENCY(BUFFER_READ_LATENCY))
      accum_buffer (
        .clk(clk),
        .inputs(rq_buffer_ram_inputs[gi]),
        .outputs(rq_buffer_ram_outputs[gi])
      );      
  end
  for(gi = 0; gi < ARRAY_HEIGHT; gi++) begin : bq_gen
    BufferRAMTQsize # (
        .ID(gi),
        .DEPTH(BUFFER_QUANT_SIZE),
        .READ_LATENCY(BUFFER_READ_LATENCY))
      bq (
        .clk(clk),
        .inputs(bq_buffer_ram_inputs[gi]),
        .outputs(bq_buffer_ram_outputs[gi])
      );      
  end
  endgenerate
endmodule
