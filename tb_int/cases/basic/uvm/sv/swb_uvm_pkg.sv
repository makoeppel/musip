package swb_uvm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  localparam int SWB_N_LANES                = 4;
  localparam int SWB_N_SUBHEADERS           = 128;
  localparam int SWB_MAX_HITS_PER_SUBHEADER = 4;
  localparam bit [5:0] SWB_MUPIX_HEADER_ID  = 6'b111010;
  localparam bit [5:0] SWB_TILE_HEADER_ID   = 6'b110100;
  localparam bit [5:0] SWB_SCIFI_HEADER_ID  = 6'b111000;
  localparam bit [7:0] SWB_K285             = 8'hBC;
  localparam bit [7:0] SWB_K284             = 8'h9C;
  localparam bit [7:0] SWB_K237             = 8'hF7;

  `include "swb_types.sv"
  `include "swb_sequences.sv"
  `include "swb_agents.sv"
  `include "swb_scoreboard.sv"
  `include "swb_env.sv"
  `include "swb_basic_test.sv"
endpackage
