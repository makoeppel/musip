package swb_2env_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  localparam int SWB_N_LANES                = 4;
  localparam int SWB_N_SUBHEADERS           = 256;
  localparam int SWB_MAX_HITS_PER_SUBHEADER = 4;
  localparam bit [5:0] SWB_MUPIX_HEADER_ID  = 6'b111010;
  localparam bit [7:0] SWB_K285             = 8'hBC;
  localparam bit [7:0] SWB_K284             = 8'h9C;
  localparam bit [7:0] SWB_K237             = 8'hF7;

  import "DPI-C" function void swb_opq_2env_init(input string replay_dir);
  import "DPI-C" function void swb_opq_2env_push_ingress(
    input int lane,
    input int valid,
    input int unsigned data,
    input int unsigned datak
  );
  import "DPI-C" function void swb_opq_2env_step_egress(
    output int valid,
    output int unsigned data,
    output int unsigned datak
  );
  import "DPI-C" function int swb_opq_2env_check_complete();

  class swb_opq_beat extends uvm_sequence_item;
    int unsigned lane_id;
    int unsigned beat_idx;
    bit [31:0]   data;
    bit [3:0]    datak;
    string       stream_name;

    `uvm_object_utils(swb_opq_beat)

    function new(string name = "swb_opq_beat");
      super.new(name);
      lane_id = 0;
      beat_idx = 0;
      data = '0;
      datak = '0;
      stream_name = "";
    endfunction

    function string convert2string();
      return $sformatf(
        "%s beat[%0d] lane=%0d datak=0x%0h data=0x%08h",
        stream_name,
        beat_idx,
        lane_id,
        datak,
        data
      );
    endfunction
  endclass

  `include "../../uvm/sv/swb_types.sv"
  `include "../../uvm/sv/swb_sequences.sv"
  `include "../../uvm/sv/swb_scoreboard.sv"
  `include "swb_2env_agents.sv"
  `include "swb_2env_boundary_scoreboard.sv"
  `include "swb_2env_env.sv"
  `include "swb_2env_test.sv"
endpackage
