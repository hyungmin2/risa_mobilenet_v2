`timescale 1 ns / 1 ns

`include "defines.vh"

package RISA_PKG;

localparam ARRAY_HEIGHT = 32;
localparam ARRAY_WIDTH = 32;

    
localparam IN_FMAP_W = 224;
localparam IN_FMAP_H = 224;
localparam IN_FMAP_CH = 3;
localparam IN_FMAP_W_MEM = (`CEILDIV(224,ARRAY_WIDTH)*ARRAY_WIDTH); //224
localparam L1_CONV_FILTER_K = 3;

localparam FMAP_MAX_W = 224;
localparam FMAP_MAX_H = 224;

localparam ACT_NO   = 0;
localparam ACT_RELU = 1;

localparam MAX_CHANNEL = 1280;
localparam SLICE_CONV_CH = (MAX_CHANNEL/ARRAY_WIDTH);

localparam AXI_IN_FMAP_LOAD_ADDR  = 32'h10000000;

localparam COMMAND_WIDTH=8;
localparam USIZE=8;
localparam QSIZE=8;
localparam FSIZE=32;
localparam RSIZE=32;
localparam PE_COMMAND_WIDTH=4;
localparam STATE_WIDTH=4;
localparam CONTROLLER_STATE_WIDTH=8;

localparam BUFFER_READ_LATENCY=4;

typedef struct  packed {
  logic valid;
  logic [COMMAND_WIDTH-1:0] command;
  logic [FSIZE-1:0] data0;
  logic [FSIZE-1:0] data1;
} CommandDataPort;



typedef struct packed {
  logic [PE_COMMAND_WIDTH-1:0] command;
  logic signed [QSIZE-1:0] data;
} PEInput;


typedef struct packed  {
  logic signed [RSIZE-1:0] data;
  logic valid;
} PEResult;


typedef struct packed{
  logic [15:0] pein;
  logic [15:0] peout;       
  logic [STATE_WIDTH-1:0] al_in;       
} BufferColumnState;    

typedef struct packed{
  logic [STATE_WIDTH-1:0] fin;
  logic [STATE_WIDTH-1:0] fout;         
  logic [STATE_WIDTH-1:0] pein;
  logic [STATE_WIDTH-1:0] peout;         
  logic [STATE_WIDTH-1:0] aw_out;         
} BufferRowState;    

typedef struct packed{
  logic [STATE_WIDTH-1:0] al_in;          
} RequantState;    



localparam BUFFER_ACCUM_SIZE = (IN_FMAP_H * IN_FMAP_W/4) ;


localparam BUFFER_QUANT_IDLE = 0;
localparam BUFFER_QUANT_WORKING = 1;
localparam BUFFER_QUANT_SYNC_ICONV = 2;
localparam BUFFER_QUANT_WORKING_ICONV = 3;
localparam BUFFER_QUANT_SYNC_CONV_TRANSFER = 4;
localparam BUFFER_QUANT_WORKING_CONV_TRANSFER = 5;
localparam BUFFER_QUANT_TRANSFER_IN_ONLY = 6;
localparam BUFFER_QUANT_TRTRANSFER = 7;


localparam BUFFER_QUANT_MODESET_PE_RESET = 1;
localparam BUFFER_QUANT_MODESET_CONV0 = 2;
localparam BUFFER_QUANT_MODESET_CONV1 = 3;
localparam BUFFER_QUANT_MODESET_CONV2 = 4;
localparam BUFFER_QUANT_MODESET_CONV3 = 5;
localparam BUFFER_QUANT_MODESET_CONV4 = 6;
localparam BUFFER_QUANT_MODESET_CONV5 = 7;
localparam BUFFER_QUANT_MODESET_CONV6 = 8;
localparam BUFFER_QUANT_MODESET_CONV_IN_TRANSFER_LAYERID = 9;
localparam BUFFER_QUANT_MODESET_ICONV0 = 10;
localparam BUFFER_QUANT_MODESET_ICONV1 = 11;
localparam BUFFER_QUANT_MODESET_ICONV2 = 12;
localparam BUFFER_QUANT_MODESET_ICONV3 = 13;
localparam BUFFER_QUANT_MODESET_ICONV4 = 14;
localparam BUFFER_QUANT_MODESET_ICONV5 = 15;
localparam BUFFER_QUANT_MODESET_ICONV6 = 16;
localparam BUFFER_QUANT_MODESET_ICONV_LAYERID = 17;
localparam BUFFER_QUANT_MODESET_TRTRANSFER0 = 18;
localparam BUFFER_QUANT_MODESET_TRTRANSFER1 = 19;

localparam BUFFER_QUANT_SIZE = 32'h10000;

localparam BUFFER_QUANT_FMAP_ADDR0 = 32'h00000;
localparam BUFFER_QUANT_FMAP_ADDR1 = 32'h08000;


localparam BUFFER_WEIGHT_IDLE =  0;
localparam BUFFER_WEIGHT_WORKING =  1;
localparam BUFFER_WEIGHT_WORKING_DCONV =  5;
localparam BUFFER_WEIGHT_WORKING_ADD =  6;
localparam BUFFER_WEIGHT_WORKING_ICONV =  7;
localparam BUFFER_WEIGHT_TRTRANSFER =  8;
localparam BUFFER_WEIGHT_SYNC =  9;
localparam BUFFER_WEIGHT_WORKING_TRANSFER_CONV0  = 11;
localparam BUFFER_WEIGHT_WORKING_TRANSFER_CONV1  = 12;
localparam BUFFER_WEIGHT_DUMP  = 13;
localparam BUFFER_WEIGHT_WORKING_AVG =  14;

localparam BUFFER_WEIGHT_MODESET_LOAD=  1;
localparam BUFFER_WEIGHT_MODESET_CONV0=  2;
localparam BUFFER_WEIGHT_MODESET_CONV1=  3;
localparam BUFFER_WEIGHT_MODESET_CONV2=  4;
localparam BUFFER_WEIGHT_MODESET_CONV3=  5;
localparam BUFFER_WEIGHT_MODESET_CONV4=  6;
localparam BUFFER_WEIGHT_MODESET_CONV5=  7;
localparam BUFFER_WEIGHT_MODESET_CONV6=  8;
localparam BUFFER_WEIGHT_MODESET_CONV7=  9;
localparam BUFFER_WEIGHT_MODESET_DCONV_LAYERID = 10;
localparam BUFFER_WEIGHT_MODESET_ICONV_LAYERID = 11;
localparam BUFFER_WEIGHT_MODESET_CONV_IN_TRANSFER_LAYERID = 12;
localparam BUFFER_WEIGHT_MODESET_ADD0 = 13;
localparam BUFFER_WEIGHT_MODESET_ADD1 = 14;
localparam BUFFER_WEIGHT_MODESET_ADD2 = 15;
localparam BUFFER_WEIGHT_MODESET_ADD3 = 16;
localparam BUFFER_WEIGHT_MODESET_ADD4 = 17;
localparam BUFFER_WEIGHT_MODESET_ADD5 = 18;
localparam BUFFER_WEIGHT_MODESET_ADD_LAYERID = 19;
localparam BUFFER_WEIGHT_MODESET_TRTRANSFER0 = 20;
localparam BUFFER_WEIGHT_MODESET_TRTRANSFER1 = 21;
localparam BUFFER_WEIGHT_MODESET_TRTRANSFER2 = 22;
localparam BUFFER_WEIGHT_MODESET_DUMP = 23;
localparam BUFFER_WEIGHT_MODESET_AVG0 = 24;
localparam BUFFER_WEIGHT_MODESET_AVG1 = 25;
localparam BUFFER_WEIGHT_MODESET_AVG2 = 26;
localparam BUFFER_WEIGHT_MODESET_AVG3 = 27;
localparam BUFFER_WEIGHT_MODESET_AVG4 = 28;
localparam BUFFER_WEIGHT_MODESET_AVG_LAYERID = 29;

localparam BUFFER_WEIGHT_SIZE = 32'h30000;
localparam BUFFER_WEIGHT_BUFFER_ADDR0 = 32'h20000;
localparam BUFFER_WEIGHT_BUFFER_ADDR1 = 32'h2A000;
localparam BUFFER_WEIGHT_FMAP_ADDR0 = 32'h0;
localparam BUFFER_WEIGHT_FMAP_ADDR1 = 32'h10000;
localparam BUFFER_WEIGHT_FMAP_ADDR2 = 32'h18000;

localparam REQUANT_IDLE = 0;
localparam REQUANT_WORKING = 1;

localparam REQUANT_MODE_CONV = 0;
localparam REQUANT_MODE_DCONV = 1;

localparam REQUANT_MODESET_ACCUM_CONV0 = 1;
localparam REQUANT_MODESET_ACCUM_CONV1 = 2;
localparam REQUANT_MODESET_ACCUM_CONV2 = 3;
localparam REQUANT_MODESET_ACCUM_CONV3 = 4;
localparam REQUANT_MODESET_ACCUM_CONV4 = 5;
localparam REQUANT_MODESET_ACCUM_CONV5 = 6;
localparam REQUANT_MODESET_ACCUM_CONV_LAYERID = 7;
localparam REQUANT_MODESET_ACCUM_DCONV_LAYERID = 8;
localparam REQUANT_MODESET_LOAD_RQ = 9;



localparam PE_COMMAND_IDLE      =  0;
localparam PE_COMMAND_NORMAL    =  1;
localparam PE_COMMAND_LT_FEED   =  2;
localparam PE_COMMAND_FEEDTOKEN =  3;
localparam PE_COMMAND_FEED      =  4;
localparam PE_COMMAND_RESET     =  5;
localparam PE_COMMAND_LOAD      =  6;
localparam PE_COMMAND_SWITCH    =  7;
localparam PE_COMMAND_LOAD_TERMINAL    =  8;
localparam PE_COMMAND_LT_TURNING_POINT =  9;
localparam PE_COMMAND_LOAD_BY_TOKEN     = 10;


typedef struct packed{
  logic [31:0]        raddr;
  logic [31:0]        waddr;
  logic [RSIZE-1:0]   wdata;
  logic               wren;
} BufferRAMTRsizeInputs;

typedef struct packed{
  logic [RSIZE-1:0]   rdata;
} BufferRAMTRsizeOutputs;

typedef struct packed{
  logic [31:0]        raddr;
  logic [31:0]        waddr;
  logic [QSIZE-1:0]   wdata;
  logic               wren;
} BufferRAMTQsizeInputs;

typedef struct packed{
  logic [QSIZE-1:0]   rdata;
} BufferRAMTQsizeOutputs;

typedef struct packed{
  logic [$clog2(ARRAY_HEIGHT)-1:0]        last_pe_id;
  logic [$clog2(ARRAY_HEIGHT)-1:0]        last_pe_id_buffer;
  logic                                   feed_started;
  logic [USIZE-1:0]                       buffer_ram_user_buf;
  logic [$clog2(BUFFER_QUANT_SIZE)-1:0]   raddr;
  logic [$clog2(BUFFER_QUANT_SIZE)-1:0]   waddr;
  logic                                   wren;
} BufferRowRelayAddrs;

typedef struct packed{
  logic [USIZE-1:0]                       buffer_ram_user_buf;
  logic [USIZE-1:0]                       buffer_ram_user_resadd_buf;
  logic [$clog2(BUFFER_WEIGHT_SIZE)-1:0]   raddr;
  logic [$clog2(BUFFER_WEIGHT_SIZE)-1:0]   waddr;
  logic                                   wren;
} BufferColumnRelayAddrs;



endpackage: RISA_PKG

