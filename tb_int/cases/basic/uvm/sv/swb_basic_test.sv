class swb_basic_test extends uvm_test;
  swb_env env;
  swb_case_plan plan;
  virtual swb_ctrl_if ctrl_vif;
  int unsigned frame_count;
  int unsigned case_seed;
  int unsigned subheader_count;
  bit [3:0]  feb_enable_mask;
  real lane_saturation[SWB_N_LANES];
  int unsigned dma_half_full_pct;
  int unsigned dma_half_full_seed;
  bit [31:0] lookup_ctrl_word;
  string profile_name_override;
  string hit_mode_name;
  string replay_dir;
  string segment_manifest_path;
  bit use_replay;
  bit use_segment_manifest;
  bit use_merge;
  swb_case_segment segments[$];

  `uvm_component_utils(swb_basic_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function automatic swb_hit_mode_e parse_hit_mode(string mode_name);
  begin
    if (mode_name == "zero") begin
      return SWB_HIT_MODE_ZERO;
    end
    if (mode_name == "single") begin
      return SWB_HIT_MODE_SINGLE;
    end
    if (mode_name == "max") begin
      return SWB_HIT_MODE_MAX;
    end
    return SWB_HIT_MODE_POISSON;
  end
  endfunction

  function automatic bit has_nonzero_lane_skew(input int unsigned lane_skew_cycles[SWB_N_LANES]);
  begin
    foreach (lane_skew_cycles[lane]) begin
      if (lane_skew_cycles[lane] != 0) begin
        return 1'b1;
      end
    end
    return 1'b0;
  end
  endfunction

  task automatic drive_dma_half_full();
    process backpressure_proc;
  begin
    backpressure_proc = process::self();
    backpressure_proc.srandom(dma_half_full_seed);
    forever begin
      @(posedge ctrl_vif.clk);
      if (ctrl_vif.reset_n !== 1'b1) begin
        ctrl_vif.dma_half_full <= 1'b0;
      end else begin
        ctrl_vif.dma_half_full <= ($urandom_range(0, 99) < dma_half_full_pct);
      end
    end
  end
  endtask

  task automatic apply_case_reset(int unsigned settle_cycles = 16);
  begin
    ctrl_vif.enable_dma      <= 1'b0;
    ctrl_vif.dma_half_full   <= 1'b0;
    ctrl_vif.use_merge       <= 1'b0;
    ctrl_vif.feb_enable_mask <= 4'hf;
    ctrl_vif.lookup_ctrl     <= '0;
    ctrl_vif.get_n_words     <= '0;
    ctrl_vif.reset_n         <= 1'b0;
    repeat (settle_cycles) @(posedge ctrl_vif.clk);
    ctrl_vif.reset_n <= 1'b1;
    @(posedge ctrl_vif.clk);
  end
  endtask

  task automatic drive_case_frames(swb_case_plan active_plan);
    swb_frame_sequence lane_seq0;
    swb_frame_sequence lane_seq1;
    swb_frame_sequence lane_seq2;
    swb_frame_sequence lane_seq3;
  begin
    fork
      begin
        lane_seq0 = swb_frame_sequence::type_id::create("lane_seq_0");
        for (int idx = 0; idx < active_plan.frames_by_lane[0].size(); idx++) begin
          lane_seq0.frames.push_back(active_plan.frames_by_lane[0][idx]);
        end
        lane_seq0.start(env.ingress_agents[0].sequencer);
      end
      begin
        lane_seq1 = swb_frame_sequence::type_id::create("lane_seq_1");
        for (int idx = 0; idx < active_plan.frames_by_lane[1].size(); idx++) begin
          lane_seq1.frames.push_back(active_plan.frames_by_lane[1][idx]);
        end
        lane_seq1.start(env.ingress_agents[1].sequencer);
      end
      begin
        lane_seq2 = swb_frame_sequence::type_id::create("lane_seq_2");
        for (int idx = 0; idx < active_plan.frames_by_lane[2].size(); idx++) begin
          lane_seq2.frames.push_back(active_plan.frames_by_lane[2][idx]);
        end
        lane_seq2.start(env.ingress_agents[2].sequencer);
      end
      begin
        lane_seq3 = swb_frame_sequence::type_id::create("lane_seq_3");
        for (int idx = 0; idx < active_plan.frames_by_lane[3].size(); idx++) begin
          lane_seq3.frames.push_back(active_plan.frames_by_lane[3][idx]);
        end
        lane_seq3.start(env.ingress_agents[3].sequencer);
      end
    join
  end
  endtask

  task automatic execute_case_plan(
    swb_case_plan active_plan,
    bit           active_use_replay,
    string        active_replay_dir,
    output bit    case_pass
  );
    int unsigned timeout_cycles;
    bit          zero_payload_case;
  begin
    env.scoreboard.begin_case(active_plan, active_plan.use_merge);

    ctrl_vif.use_merge       <= active_plan.use_merge;
    ctrl_vif.enable_dma      <= 1'b0;
    ctrl_vif.feb_enable_mask <= active_plan.feb_enable_mask;
    ctrl_vif.lookup_ctrl     <= '0;
    ctrl_vif.dma_half_full   <= 1'b0;
    ctrl_vif.get_n_words     <= active_plan.expected_word_count;
    @(posedge ctrl_vif.clk);
    if (active_plan.lookup_ctrl_word != '0) begin
      ctrl_vif.lookup_ctrl <= active_plan.lookup_ctrl_word;
      @(posedge ctrl_vif.clk);
      ctrl_vif.lookup_ctrl <= '0;
      @(posedge ctrl_vif.clk);
    end
    ctrl_vif.enable_dma      <= 1'b1;

    if (active_use_replay) begin
      `uvm_info(
        "CASE",
        $sformatf(
          "Replay case: dir=%s frames=%0d raw_total_hits=%0d padding_hits_added=%0d total_hits=%0d expected_words=%0d mask=0x%0h use_merge=%0d case_seed=%0d lane_skew0=%s lane_skew_max=%0d lane_skew_mode=%s",
          active_replay_dir,
          active_plan.frame_count,
          active_plan.raw_total_hits_before_padding,
          active_plan.padding_hits_added,
          active_plan.total_hits,
          active_plan.expected_word_count,
          active_plan.feb_enable_mask,
          active_plan.use_merge,
          active_plan.case_seed,
          active_plan.first_frame_lane_skew_summary(),
          active_plan.max_lane_skew_cycles(),
          active_plan.lane_skew_varies_by_frame() ? "varying" : "fixed"
        ),
        UVM_LOW
      )
    end else begin
      `uvm_info(
        "CASE",
        $sformatf(
          "Basic case: frames=%0d sat=[%0.2f %0.2f %0.2f %0.2f] mask=0x%0h hit_mode=%s raw_total_hits=%0d padding_hits_added=%0d total_hits=%0d expected_words=%0d use_merge=%0d dma_half_full_pct=%0d case_seed=%0d lane_skew0=%s lane_skew_max=%0d lane_skew_mode=%s",
          active_plan.frame_count,
          active_plan.lane_saturation[0],
          active_plan.lane_saturation[1],
          active_plan.lane_saturation[2],
          active_plan.lane_saturation[3],
          active_plan.feb_enable_mask,
          active_plan.hit_mode_name,
          active_plan.raw_total_hits_before_padding,
          active_plan.padding_hits_added,
          active_plan.total_hits,
          active_plan.expected_word_count,
          active_plan.use_merge,
          active_plan.dma_half_full_pct,
          active_plan.case_seed,
          active_plan.first_frame_lane_skew_summary(),
          active_plan.max_lane_skew_cycles(),
          active_plan.lane_skew_varies_by_frame() ? "varying" : "fixed"
        ),
        UVM_LOW
      )
    end

    dma_half_full_pct = active_plan.dma_half_full_pct;
    if (dma_half_full_pct != 0) begin
      fork : dma_half_full_bg
        drive_dma_half_full();
      join_none
    end

    zero_payload_case = (active_plan.expected_word_count == 0);
    drive_case_frames(active_plan);

    timeout_cycles = (active_plan.expected_word_count * 32) + 300000;
    if (zero_payload_case) begin
      `uvm_info(
        "ZERO_PAYLOAD",
        "expected_word_count=0, so the harness skips the dma_done timeout and only checks that no unexpected payload escapes",
        UVM_LOW
      )
      repeat (256) @(posedge ctrl_vif.clk);
    end else begin
      repeat (timeout_cycles) begin
        @(posedge ctrl_vif.clk);
        if (ctrl_vif.dma_done) begin
          break;
        end
      end

      if (!ctrl_vif.dma_done) begin
        `uvm_error("TIMEOUT", $sformatf("DMA done not observed within %0d cycles", timeout_cycles))
        `uvm_info(
          "TIMEOUT_STATE",
          $sformatf(
            "ingress_beats=[%0d %0d %0d %0d] opq_beats=%0d opq_recv_beats=%0d dma_words=%0d ingress_hits=%0d opq_hits=%0d dma_hits=%0d recv_words=%0d padding=%0d parse_errors=%0d opq_state=%s opq_hits_remaining=%0d",
            env.ingress_agents[0].monitor.beat_count,
            env.ingress_agents[1].monitor.beat_count,
            env.ingress_agents[2].monitor.beat_count,
            env.ingress_agents[3].monitor.beat_count,
            env.opq_monitor.beat_count,
            env.scoreboard.opq_recv_beats,
            env.dma_monitor.word_count,
            env.scoreboard.ingress_hits.size(),
            env.scoreboard.opq_hits.size(),
            env.scoreboard.dma_hits.size(),
            env.scoreboard.recv_words,
            env.scoreboard.padding_words,
            env.scoreboard.parse_errors,
            env.scoreboard.opq_parser.state_name(),
            env.scoreboard.opq_parser.hits_remaining
          ),
          UVM_LOW
        )
      end
    end

    case_pass = env.scoreboard.check_current_case();
    if (!case_pass) begin
      `uvm_error(
        "CASE_FAIL",
        $sformatf(
          "Case %s failed inside the active simulation frame",
          active_plan.profile_name
        )
      )
    end else begin
      `uvm_info(
        "SWB_SEGMENT_PASS",
        $sformatf(
          "profile=%s case_seed=%0d expected_words=%0d use_merge=%0d mask=0x%0h",
          active_plan.profile_name,
          active_plan.case_seed,
          active_plan.expected_word_count,
          active_plan.use_merge,
          active_plan.feb_enable_mask
        ),
        UVM_NONE
      )
    end

    ctrl_vif.enable_dma    <= 1'b0;
    ctrl_vif.dma_half_full <= 1'b0;
    if (dma_half_full_pct != 0) begin
      disable dma_half_full_bg;
    end
    repeat (16) @(posedge ctrl_vif.clk);
  end
  endtask

  function void build_phase(uvm_phase phase);
    process build_proc;
    int unsigned plusarg_mask;
    int unsigned lane_skew_cycles[SWB_N_LANES];
    int unsigned lane_skew_max_cyc;
    int unsigned subheader_plusarg;
    swb_hit_mode_e hit_mode;
    bit lane_skew_varying;
    super.build_phase(phase);

    if (!uvm_config_db#(virtual swb_ctrl_if)::get(this, "", "ctrl_vif", ctrl_vif)) begin
      `uvm_fatal("NOVIF", "swb_ctrl_if missing from config_db")
    end

    frame_count = 2;
    case_seed = 0;
    subheader_count = SWB_N_SUBHEADERS;
    feb_enable_mask = 4'hf;
    replay_dir = "";
    segment_manifest_path = "";
    use_replay = 1'b0;
    use_segment_manifest = 1'b0;
    use_merge = 1'b0;
    dma_half_full_pct = 0;
    dma_half_full_seed = 32'h5a17_c0de;
    lookup_ctrl_word = '0;
    profile_name_override = "";
    hit_mode_name = "poisson";
    lane_skew_varying = 1'b0;
    lane_skew_max_cyc = 0;
    lane_saturation[0] = 0.20;
    lane_saturation[1] = 0.40;
    lane_saturation[2] = 0.60;
    lane_saturation[3] = 0.80;
    foreach (lane_skew_cycles[lane]) begin
      lane_skew_cycles[lane] = 0;
    end

    void'($value$plusargs("SWB_FRAMES=%d", frame_count));
    if ($value$plusargs("SWB_SUBHEADERS=%d", subheader_plusarg)) begin
      subheader_count = subheader_plusarg;
    end
    void'($value$plusargs("SWB_SAT0=%f", lane_saturation[0]));
    void'($value$plusargs("SWB_SAT1=%f", lane_saturation[1]));
    void'($value$plusargs("SWB_SAT2=%f", lane_saturation[2]));
    void'($value$plusargs("SWB_SAT3=%f", lane_saturation[3]));
    if ($value$plusargs("SWB_FEB_ENABLE_MASK=%h", plusarg_mask)) begin
      feb_enable_mask = plusarg_mask[3:0];
    end
    void'($value$plusargs("SWB_USE_MERGE=%d", use_merge));
    void'($value$plusargs("SWB_DMA_HALF_FULL_PCT=%d", dma_half_full_pct));
    void'($value$plusargs("SWB_DMA_HALF_FULL_SEED=%d", dma_half_full_seed));
    void'($value$plusargs("SWB_LOOKUP_CTRL_WORD=%h", lookup_ctrl_word));
    void'($value$plusargs("SWB_PROFILE_NAME=%s", profile_name_override));
    void'($value$plusargs("SWB_HIT_MODE=%s", hit_mode_name));
    void'($value$plusargs("SWB_LANE0_SKEW_CYC=%d", lane_skew_cycles[0]));
    void'($value$plusargs("SWB_LANE1_SKEW_CYC=%d", lane_skew_cycles[1]));
    void'($value$plusargs("SWB_LANE2_SKEW_CYC=%d", lane_skew_cycles[2]));
    void'($value$plusargs("SWB_LANE3_SKEW_CYC=%d", lane_skew_cycles[3]));
    void'($value$plusargs("SWB_LANE_SKEW_VARYING=%d", lane_skew_varying));
    void'($value$plusargs("SWB_LANE_SKEW_MAX_CYC=%d", lane_skew_max_cyc));
    use_replay = $value$plusargs("SWB_REPLAY_DIR=%s", replay_dir);
    use_segment_manifest = $value$plusargs("SWB_SEGMENT_MANIFEST=%s", segment_manifest_path);
    if (!$value$plusargs("SWB_CASE_SEED=%d", case_seed)) begin
      case_seed = $urandom();
    end
    hit_mode = parse_hit_mode(hit_mode_name);

    if (use_segment_manifest && use_replay) begin
      `uvm_fatal("CASE_CFG", "SWB_SEGMENT_MANIFEST and SWB_REPLAY_DIR are mutually exclusive")
    end
    if ((subheader_count == 0) || (subheader_count > SWB_N_SUBHEADERS)) begin
      `uvm_fatal(
        "CASE_CFG",
        $sformatf("SWB_SUBHEADERS=%0d is outside the supported range 1..%0d", subheader_count, SWB_N_SUBHEADERS)
      )
    end
    if (use_replay && (subheader_count != SWB_N_SUBHEADERS)) begin
      `uvm_fatal("CASE_CFG", "SWB_SUBHEADERS applies only to generated basic cases, not replay cases")
    end
    if (lane_skew_varying && has_nonzero_lane_skew(lane_skew_cycles)) begin
      `uvm_fatal("CASE_CFG", "Explicit SWB_LANE<n>_SKEW_CYC and SWB_LANE_SKEW_VARYING are mutually exclusive")
    end
    if (lane_skew_varying && (lane_skew_max_cyc == 0)) begin
      `uvm_fatal("CASE_CFG", "SWB_LANE_SKEW_VARYING=1 requires SWB_LANE_SKEW_MAX_CYC>0")
    end

    if (use_segment_manifest) begin
      swb_case_builder::load_segment_manifest(segments, segment_manifest_path);
      uvm_config_db#(bit)::set(this, "env.scoreboard", "allow_deferred_plan", 1'b1);
      `uvm_info(
        "CASE_CFG",
        $sformatf(
          "Loaded %0d manifest segments from %s",
          segments.size(),
          segment_manifest_path
        ),
        UVM_LOW
      )
    end else begin
      plan = swb_case_plan::type_id::create("plan");
      if (use_replay) begin
        swb_case_builder::load_replay_case(plan, replay_dir);
        if (plan.frames_by_lane[0].size() != 0) begin
          frame_count = plan.frames_by_lane[0].size();
        end
      end else begin
        build_proc = process::self();
        build_proc.srandom(case_seed);
        swb_case_builder::build_basic_case(plan, frame_count, lane_saturation, subheader_count, feb_enable_mask, hit_mode);
      end
      plan.feb_enable_mask = feb_enable_mask;
      plan.frame_count = frame_count;
      plan.case_seed = case_seed;
      plan.lookup_ctrl_word = lookup_ctrl_word;
      plan.dma_half_full_pct = dma_half_full_pct;
      plan.use_merge = use_merge;
      plan.hit_mode_id = hit_mode;
      if (lane_skew_varying) begin
        swb_case_builder::apply_varying_lane_skew(plan, lane_skew_max_cyc);
      end else begin
        swb_case_builder::apply_fixed_lane_skew(plan, lane_skew_cycles);
      end
      if (profile_name_override != "") begin
        plan.profile_name = profile_name_override;
      end
      uvm_config_db#(swb_case_plan)::set(this, "*", "case_plan", plan);
      uvm_config_db#(bit)::set(this, "env.scoreboard", "expect_opq_merged", use_merge);
    end

    env = swb_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    bit case_pass;
  begin
    phase.raise_objection(this);

    wait (ctrl_vif.reset_n === 1'b1);
    @(posedge ctrl_vif.clk);
    env.scoreboard.auto_check_enabled = 1'b0;

    if (use_segment_manifest) begin
      int unsigned failing_segments;
      int unsigned frame_id_offset;
      failing_segments = 0;
      frame_id_offset = 0;
      foreach (segments[idx]) begin
        swb_case_plan segment_plan;
        if (segments[idx].reset_before) begin
          apply_case_reset();
          frame_id_offset = 0;
        end
        segment_plan = swb_case_plan::type_id::create($sformatf("segment_plan_%0d", idx));
        swb_case_builder::load_replay_case(segment_plan, segments[idx].replay_dir);
        segment_plan.feb_enable_mask = segments[idx].feb_enable_mask;
        segment_plan.use_merge = segments[idx].use_merge;
        segment_plan.dma_half_full_pct = segments[idx].dma_half_full_pct;
        segment_plan.case_seed = segments[idx].case_seed;
        segment_plan.profile_name = segments[idx].case_id;
        swb_case_builder::retime_replay_case(segment_plan, frame_id_offset);
        dma_half_full_seed = segments[idx].dma_half_full_seed;
        execute_case_plan(segment_plan, 1'b1, segments[idx].replay_dir, case_pass);
        frame_id_offset += segment_plan.frame_count;
        if (!case_pass) begin
          failing_segments++;
        end
      end
      if (failing_segments != 0) begin
        `uvm_fatal("SEGMENT_FAIL", $sformatf("%0d manifest segment(s) failed", failing_segments))
      end
    end else begin
      execute_case_plan(plan, use_replay, replay_dir, case_pass);
      if (!case_pass) begin
        `uvm_fatal("CASE_FAIL", $sformatf("Primary case %s failed", plan.profile_name))
      end
    end
    phase.drop_objection(this);
  end
  endtask
endclass
