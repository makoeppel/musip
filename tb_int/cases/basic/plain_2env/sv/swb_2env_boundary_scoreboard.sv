// -----------------------------------------------------------------------------
// File      : swb_2env_boundary_scoreboard.sv
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Version   : 26.4.22
// Date      : 20260422
// Change    : Add explicit OPQ-boundary replay scoreboarding for the split
//             2-env workaround harness.
// -----------------------------------------------------------------------------

`uvm_analysis_imp_decl(_opq_in0)
`uvm_analysis_imp_decl(_opq_in1)
`uvm_analysis_imp_decl(_opq_in2)
`uvm_analysis_imp_decl(_opq_in3)
`uvm_analysis_imp_decl(_opq_out)

class swb_opq_boundary_scoreboard extends uvm_component;
  uvm_analysis_imp_opq_in0 #(swb_opq_beat, swb_opq_boundary_scoreboard) ingress_imp0;
  uvm_analysis_imp_opq_in1 #(swb_opq_beat, swb_opq_boundary_scoreboard) ingress_imp1;
  uvm_analysis_imp_opq_in2 #(swb_opq_beat, swb_opq_boundary_scoreboard) ingress_imp2;
  uvm_analysis_imp_opq_in3 #(swb_opq_beat, swb_opq_boundary_scoreboard) ingress_imp3;
  uvm_analysis_imp_opq_out #(swb_opq_beat, swb_opq_boundary_scoreboard) egress_imp;

  string replay_dir;

  swb_ingress_beat_t expected_ingress[SWB_N_LANES][$];
  swb_ingress_beat_t expected_egress[$];
  int unsigned       seen_ingress[SWB_N_LANES];
  int unsigned       seen_egress;

  `uvm_component_utils(swb_opq_boundary_scoreboard)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ingress_imp0 = new("ingress_imp0", this);
    ingress_imp1 = new("ingress_imp1", this);
    ingress_imp2 = new("ingress_imp2", this);
    ingress_imp3 = new("ingress_imp3", this);
    egress_imp = new("egress_imp", this);
    seen_egress = 0;
    foreach (seen_ingress[lane]) begin
      seen_ingress[lane] = 0;
    end
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(string)::get(this, "", "replay_dir", replay_dir)) begin
      `uvm_fatal("NOREPLAY", "replay_dir missing from config_db")
    end

    for (int lane = 0; lane < SWB_N_LANES; lane++) begin
      load_valid_beats($sformatf("%s/lane%0d_ingress.mem", replay_dir, lane), expected_ingress[lane]);
    end
    load_valid_beats($sformatf("%s/opq_egress.mem", replay_dir), expected_egress);
  endfunction

  function void load_valid_beats(string path, ref swb_ingress_beat_t beats[$]);
    int          handle;
    string       line;
    bit [39:0]   packed_beat;
    swb_ingress_beat_t unpacked_beat;
  begin
    beats.delete();
    handle = $fopen(path, "r");
    if (handle == 0) begin
      `uvm_fatal("NOFILE", $sformatf("Unable to open replay file %s", path))
    end

    while ($fgets(line, handle) != 0) begin
      if ($sscanf(line, "%h", packed_beat) != 1) begin
        continue;
      end

      if (packed_beat[36] != 1'b1) begin
        continue;
      end

      unpacked_beat.valid = packed_beat[36];
      unpacked_beat.datak = packed_beat[35:32];
      unpacked_beat.data = packed_beat[31:0];
      beats.push_back(unpacked_beat);
    end

    $fclose(handle);
  end
  endfunction

  function void compare_beat(
    string               stream_name,
    int unsigned         expected_idx,
    swb_ingress_beat_t   expected_beat,
    swb_opq_beat         actual_beat
  );
  begin
    if ((actual_beat.datak !== expected_beat.datak) || (actual_beat.data !== expected_beat.data)) begin
      `uvm_error(
        "OPQ_BOUNDARY_MISMATCH",
        $sformatf(
          "%s beat[%0d] expected={datak=0x%0h data=0x%08h} actual={datak=0x%0h data=0x%08h}",
          stream_name,
          expected_idx,
          expected_beat.datak,
          expected_beat.data,
          actual_beat.datak,
          actual_beat.data
        )
      )
    end
  end
  endfunction

  function void compare_ingress(int unsigned lane, swb_opq_beat item);
  begin
    if (seen_ingress[lane] >= expected_ingress[lane].size()) begin
      `uvm_error(
        "OPQ_BOUNDARY_EXTRA",
        $sformatf("Lane %0d observed unexpected extra ingress beat %s", lane, item.convert2string())
      )
      return;
    end

    compare_beat(
      $sformatf("lane%0d_ingress", lane),
      seen_ingress[lane],
      expected_ingress[lane][seen_ingress[lane]],
      item
    );
    seen_ingress[lane]++;
  end
  endfunction

  function void compare_egress(swb_opq_beat item);
  begin
    if (seen_egress >= expected_egress.size()) begin
      `uvm_error("OPQ_BOUNDARY_EXTRA", $sformatf("Observed unexpected extra OPQ egress beat %s", item.convert2string()))
      return;
    end

    compare_beat("opq_egress", seen_egress, expected_egress[seen_egress], item);
    seen_egress++;
  end
  endfunction

  function void write_opq_in0(swb_opq_beat item);
    compare_ingress(0, item);
  endfunction

  function void write_opq_in1(swb_opq_beat item);
    compare_ingress(1, item);
  endfunction

  function void write_opq_in2(swb_opq_beat item);
    compare_ingress(2, item);
  endfunction

  function void write_opq_in3(swb_opq_beat item);
    compare_ingress(3, item);
  endfunction

  function void write_opq_out(swb_opq_beat item);
    compare_egress(item);
  endfunction

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);

    for (int lane = 0; lane < SWB_N_LANES; lane++) begin
      if (seen_ingress[lane] != expected_ingress[lane].size()) begin
        `uvm_error(
          "OPQ_BOUNDARY_SHORT",
          $sformatf(
            "Lane %0d ingress consumed=%0d expected=%0d valid beats",
            lane,
            seen_ingress[lane],
            expected_ingress[lane].size()
          )
        )
      end
    end

    if (seen_egress != expected_egress.size()) begin
      `uvm_error(
        "OPQ_BOUNDARY_SHORT",
        $sformatf("OPQ egress consumed=%0d expected=%0d valid beats", seen_egress, expected_egress.size())
      )
    end

    `uvm_info(
      "OPQ_BOUNDARY_SUMMARY",
      $sformatf(
        "Lane valid beats=[%0d %0d %0d %0d] opq_egress=%0d",
        seen_ingress[0],
        seen_ingress[1],
        seen_ingress[2],
        seen_ingress[3],
        seen_egress
      ),
      UVM_LOW
    )
  endfunction
endclass
