`timescale 1 ns / 1 ns

`include "defines.vh"

import RISA_PKG::*;


module BufferRAMTRsize #(
  parameter ID      = 0,
  parameter DEPTH   = 512,
  parameter READ_LATENCY = BUFFER_READ_LATENCY,
  parameter DEPTHAD = $clog2(DEPTH)
) (
  input clk,
  input BufferRAMTRsizeInputs inputs,
  output BufferRAMTRsizeOutputs outputs
);
  localparam WIDTH = RSIZE;

  logic[WIDTH-1:0] memory[0:DEPTH-1];

  logic[WIDTH-1:0] rbuffer[0:READ_LATENCY-1];

  assign outputs.rdata = rbuffer[READ_LATENCY-1];
  
  always @ (posedge clk) begin
    rbuffer[0] <= memory[inputs.raddr];
    for(int i = 0; i < READ_LATENCY-1; i ++)  
      rbuffer[i+1] <= rbuffer[i];
    
    if(inputs.wren) begin
      memory[inputs.waddr] = inputs.wdata;
    end
	end  
endmodule