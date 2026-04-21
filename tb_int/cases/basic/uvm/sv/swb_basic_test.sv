class swb_basic_test extends uvm_test;
  swb_env env;
  swb_case_plan plan;
  virtual swb_ctrl_if ctrl_vif;
  int unsigned frame_count;
  real lane_saturation[SWB_N_LANES];
  string replay_dir;
  bit use_replay;

  `uvm_component_utils(swb_basic_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(virtual swb_ctrl_if)::get(this, "", "ctrl_vif", ctrl_vif)) begin
      `uvm_fatal("NOVIF", "swb_ctrl_if missing from config_db")
    end

    frame_count = 2;
    replay_dir = "";
    use_replay = 1'b0;
    lane_saturation[0] = 0.20;
    lane_saturation[1] = 0.40;
    lane_saturation[2] = 0.60;
    lane_saturation[3] = 0.80;

    void'($value$plusargs("SWB_FRAMES=%d", frame_count));
    void'($value$plusargs("SWB_SAT0=%f", lane_saturation[0]));
    void'($value$plusargs("SWB_SAT1=%f", lane_saturation[1]));
    void'($value$plusargs("SWB_SAT2=%f", lane_saturation[2]));
    void'($value$plusargs("SWB_SAT3=%f", lane_saturation[3]));
    use_replay = $value$plusargs("SWB_REPLAY_DIR=%s", replay_dir);

    plan = swb_case_plan::type_id::create("plan");
    if (use_replay) begin
      swb_case_builder::load_replay_case(plan, replay_dir);
      if (plan.frames_by_lane[0].size() != 0) begin
        frame_count = plan.frames_by_lane[0].size();
      end
    end else begin
      swb_case_builder::build_basic_case(plan, frame_count, lane_saturation);
    end
    uvm_config_db#(swb_case_plan)::set(this, "*", "case_plan", plan);

    env = swb_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    swb_frame_sequence lane_seq[SWB_N_LANES];
    int unsigned timeout_cycles;
  begin
    phase.raise_objection(this);

    wait (ctrl_vif.reset_n === 1'b1);
    @(posedge ctrl_vif.clk);

    ctrl_vif.use_merge       <= 1'b1;
    ctrl_vif.enable_dma      <= 1'b0;
    ctrl_vif.feb_enable_mask <= 4'hf;
    ctrl_vif.lookup_ctrl     <= '0;
    ctrl_vif.get_n_words     <= plan.expected_word_count;
    ctrl_vif.enable_dma      <= 1'b1;

    if (use_replay) begin
      `uvm_info(
        "CASE",
        $sformatf(
          "Replay case: dir=%s frames=%0d total_hits=%0d expected_words=%0d",
          replay_dir,
          frame_count,
          plan.total_hits,
          plan.expected_word_count
        ),
        UVM_LOW
      )
    end else begin
      `uvm_info(
        "CASE",
        $sformatf(
          "Basic case: frames=%0d sat=[%0.2f %0.2f %0.2f %0.2f] total_hits=%0d expected_words=%0d",
          frame_count,
          lane_saturation[0],
          lane_saturation[1],
          lane_saturation[2],
          lane_saturation[3],
          plan.total_hits,
          plan.expected_word_count
        ),
        UVM_LOW
      )
    end

    fork
      for (int lane = 0; lane < SWB_N_LANES; lane++) begin
        automatic int lane_local = lane;
        begin
          lane_seq[lane_local] = swb_frame_sequence::type_id::create($sformatf("lane_seq_%0d", lane_local));
          for (int idx = 0; idx < plan.frames_by_lane[lane_local].size(); idx++) begin
            lane_seq[lane_local].frames.push_back(plan.frames_by_lane[lane_local][idx]);
          end
          lane_seq[lane_local].start(env.ingress_agents[lane_local].sequencer);
        end
      end
    join

    timeout_cycles = (plan.expected_word_count * 32) + 50000;
    repeat (timeout_cycles) begin
      @(posedge ctrl_vif.clk);
      if (ctrl_vif.dma_done) begin
        break;
      end
    end

    if (!ctrl_vif.dma_done) begin
      `uvm_fatal("TIMEOUT", $sformatf("DMA done not observed within %0d cycles", timeout_cycles))
    end

    repeat (16) @(posedge ctrl_vif.clk);
    ctrl_vif.enable_dma <= 1'b0;
    phase.drop_objection(this);
  end
  endtask
endclass
