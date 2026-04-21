`timescale 1ns/1ps

interface feb_ingress_if(input logic clk);
  logic        valid;
  logic [31:0] data;
  logic [3:0]  datak;

  task automatic drive_idle();
    valid <= 1'b0;
    data  <= '0;
    datak <= '0;
  endtask
endinterface

interface dma_sink_if(input logic clk);
  logic [255:0] data;
  logic         wren;
  logic         end_of_event;
endinterface

interface swb_ctrl_if(input logic clk);
  logic        reset_n;
  logic [3:0]  feb_enable_mask;
  logic        use_merge;
  logic        enable_dma;
  logic [31:0] get_n_words;
  logic [31:0] lookup_ctrl;
  logic        dma_half_full;
  logic        dma_done;
endinterface
