class swb_basic_test extends uvm_test;
  swb_env env;
  swb_case_plan plan;
  virtual swb_ctrl_if ctrl_vif;
  int unsigned frame_count;
  int unsigned case_seed;
  bit [3:0]  feb_enable_mask;
  real lane_saturation[SWB_N_LANES];
  int unsigned dma_half_full_pct;
  int unsigned dma_half_full_seed;
  string profile_name_override;
  string hit_mode_name;
  string replay_dir;
  bit use_replay;
  bit use_merge;

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

  function void build_phase(uvm_phase phase);
    process build_proc;
    int unsigned plusarg_mask;
    swb_hit_mode_e hit_mode;
    super.build_phase(phase);

    if (!uvm_config_db#(virtual swb_ctrl_if)::get(this, "", "ctrl_vif", ctrl_vif)) begin
      `uvm_fatal("NOVIF", "swb_ctrl_if missing from config_db")
    end

    frame_count = 2;
    case_seed = 0;
    feb_enable_mask = 4'hf;
    replay_dir = "";
    use_replay = 1'b0;
    use_merge = 1'b0;
    dma_half_full_pct = 0;
    dma_half_full_seed = 32'h5a17_c0de;
    profile_name_override = "";
    hit_mode_name = "poisson";
    lane_saturation[0] = 0.20;
    lane_saturation[1] = 0.40;
    lane_saturation[2] = 0.60;
    lane_saturation[3] = 0.80;

    void'($value$plusargs("SWB_FRAMES=%d", frame_count));
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
    void'($value$plusargs("SWB_PROFILE_NAME=%s", profile_name_override));
    void'($value$plusargs("SWB_HIT_MODE=%s", hit_mode_name));
    use_replay = $value$plusargs("SWB_REPLAY_DIR=%s", replay_dir);
    if (!$value$plusargs("SWB_CASE_SEED=%d", case_seed)) begin
      case_seed = $urandom();
    end
    hit_mode = parse_hit_mode(hit_mode_name);

    plan = swb_case_plan::type_id::create("plan");
    if (use_replay) begin
      swb_case_builder::load_replay_case(plan, replay_dir);
      if (plan.frames_by_lane[0].size() != 0) begin
        frame_count = plan.frames_by_lane[0].size();
      end
    end else begin
      build_proc = process::self();
      build_proc.srandom(case_seed);
      swb_case_builder::build_basic_case(plan, frame_count, lane_saturation, feb_enable_mask, hit_mode);
    end
    plan.feb_enable_mask = feb_enable_mask;
    plan.case_seed = case_seed;
    if (profile_name_override != "") begin
      plan.profile_name = profile_name_override;
    end
    uvm_config_db#(swb_case_plan)::set(this, "*", "case_plan", plan);
    uvm_config_db#(bit)::set(this, "env.scoreboard", "expect_opq_merged", use_merge);

    env = swb_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    swb_frame_sequence lane_seq0;
    swb_frame_sequence lane_seq1;
    swb_frame_sequence lane_seq2;
    swb_frame_sequence lane_seq3;
    int unsigned timeout_cycles;
    bit zero_payload_case;
  begin
    phase.raise_objection(this);

    wait (ctrl_vif.reset_n === 1'b1);
    @(posedge ctrl_vif.clk);

    ctrl_vif.use_merge          <= use_merge;
    ctrl_vif.enable_dma         <= 1'b0;
    ctrl_vif.feb_enable_mask    <= feb_enable_mask;
    ctrl_vif.lookup_ctrl        <= '0;
    ctrl_vif.dma_half_full      <= 1'b0;
    ctrl_vif.get_n_words        <= plan.expected_word_count;
    ctrl_vif.enable_dma         <= 1'b1;

    if (use_replay) begin
      `uvm_info(
        "CASE",
        $sformatf(
          "Replay case: dir=%s frames=%0d total_hits=%0d expected_words=%0d mask=0x%0h use_merge=%0d case_seed=%0d",
          replay_dir,
          frame_count,
          plan.total_hits,
          plan.expected_word_count,
          feb_enable_mask,
          use_merge,
          plan.case_seed
        ),
        UVM_LOW
      )
    end else begin
      `uvm_info(
        "CASE",
        $sformatf(
          "Basic case: frames=%0d sat=[%0.2f %0.2f %0.2f %0.2f] mask=0x%0h hit_mode=%s total_hits=%0d expected_words=%0d use_merge=%0d dma_half_full_pct=%0d case_seed=%0d",
          frame_count,
          lane_saturation[0],
          lane_saturation[1],
          lane_saturation[2],
          lane_saturation[3],
          feb_enable_mask,
          plan.hit_mode_name,
          plan.total_hits,
          plan.expected_word_count,
          use_merge,
          dma_half_full_pct,
          plan.case_seed
        ),
        UVM_LOW
      )
    end

    if (dma_half_full_pct != 0) begin
      fork : dma_half_full_bg
        drive_dma_half_full();
      join_none
    end

    zero_payload_case = (plan.expected_word_count == 0);
    fork
      begin
        lane_seq0 = swb_frame_sequence::type_id::create("lane_seq_0");
        for (int idx = 0; idx < plan.frames_by_lane[0].size(); idx++) begin
          lane_seq0.frames.push_back(plan.frames_by_lane[0][idx]);
        end
        lane_seq0.start(env.ingress_agents[0].sequencer);
      end
      begin
        lane_seq1 = swb_frame_sequence::type_id::create("lane_seq_1");
        for (int idx = 0; idx < plan.frames_by_lane[1].size(); idx++) begin
          lane_seq1.frames.push_back(plan.frames_by_lane[1][idx]);
        end
        lane_seq1.start(env.ingress_agents[1].sequencer);
      end
      begin
        lane_seq2 = swb_frame_sequence::type_id::create("lane_seq_2");
        for (int idx = 0; idx < plan.frames_by_lane[2].size(); idx++) begin
          lane_seq2.frames.push_back(plan.frames_by_lane[2][idx]);
        end
        lane_seq2.start(env.ingress_agents[2].sequencer);
      end
      begin
        lane_seq3 = swb_frame_sequence::type_id::create("lane_seq_3");
        for (int idx = 0; idx < plan.frames_by_lane[3].size(); idx++) begin
          lane_seq3.frames.push_back(plan.frames_by_lane[3][idx]);
        end
        lane_seq3.start(env.ingress_agents[3].sequencer);
      end
    join

    timeout_cycles = (plan.expected_word_count * 32) + 50000;
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

    repeat (16) @(posedge ctrl_vif.clk);
    ctrl_vif.enable_dma <= 1'b0;
    ctrl_vif.dma_half_full <= 1'b0;
    if (dma_half_full_pct != 0) begin
      disable dma_half_full_bg;
    end
    phase.drop_objection(this);
  end
  endtask
endclass
