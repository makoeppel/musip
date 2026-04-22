class swb_basic_2env_test extends uvm_test;
  swb_opq_env      opq_env;
  swb_datapath_env datapath_env;
  swb_case_plan    plan;
  virtual swb_ctrl_if ctrl_vif;
  string replay_dir;
  int unsigned frame_count;

  `uvm_component_utils(swb_basic_2env_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(virtual swb_ctrl_if)::get(this, "", "ctrl_vif", ctrl_vif)) begin
      `uvm_fatal("NOVIF", "swb_ctrl_if missing from config_db")
    end

    if (!$value$plusargs("SWB_REPLAY_DIR=%s", replay_dir)) begin
      `uvm_fatal("NOREPLAY", "SWB_REPLAY_DIR must point at the basic/ref replay bundle")
    end

    plan = swb_case_plan::type_id::create("plan");
    swb_case_builder::load_replay_case(plan, replay_dir);
    frame_count = (plan.frames_by_lane[0].size() != 0) ? plan.frames_by_lane[0].size() : 0;
    uvm_config_db#(swb_case_plan)::set(this, "*", "case_plan", plan);
    uvm_config_db#(string)::set(this, "*", "replay_dir", replay_dir);

    opq_env      = swb_opq_env::type_id::create("opq_env", this);
    datapath_env = swb_datapath_env::type_id::create("datapath_env", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    opq_env.ingress_agents[0].monitor.stream_ap.connect(datapath_env.scoreboard.ingress_imp0);
    opq_env.ingress_agents[1].monitor.stream_ap.connect(datapath_env.scoreboard.ingress_imp1);
    opq_env.ingress_agents[2].monitor.stream_ap.connect(datapath_env.scoreboard.ingress_imp2);
    opq_env.ingress_agents[3].monitor.stream_ap.connect(datapath_env.scoreboard.ingress_imp3);
    opq_env.ingress_agents[0].monitor.ap.connect(datapath_env.boundary_scoreboard.ingress_imp0);
    opq_env.ingress_agents[1].monitor.ap.connect(datapath_env.boundary_scoreboard.ingress_imp1);
    opq_env.ingress_agents[2].monitor.ap.connect(datapath_env.boundary_scoreboard.ingress_imp2);
    opq_env.ingress_agents[3].monitor.ap.connect(datapath_env.boundary_scoreboard.ingress_imp3);
  endfunction

  task run_phase(uvm_phase phase);
    swb_frame_sequence lane_seq[SWB_N_LANES];
    int unsigned timeout_cycles;
  begin
    phase.raise_objection(this);

    swb_opq_2env_init(replay_dir);

    wait (ctrl_vif.reset_n === 1'b1);
    @(posedge ctrl_vif.clk);

    ctrl_vif.use_merge          <= 1'b1;
    ctrl_vif.enable_dma         <= 1'b0;
    ctrl_vif.feb_enable_mask    <= 4'hf;
    ctrl_vif.lookup_ctrl        <= '0;
    ctrl_vif.get_n_words        <= plan.expected_word_count;
    ctrl_vif.enable_dma         <= 1'b1;

    `uvm_info(
      "CASE_2ENV",
      $sformatf(
        "Replay case: dir=%s frames=%0d total_hits=%0d expected_words=%0d",
        replay_dir,
        frame_count,
        plan.total_hits,
        plan.expected_word_count
      ),
      UVM_LOW
    )

    fork
      for (int lane = 0; lane < SWB_N_LANES; lane++) begin
        automatic int lane_local = lane;
        begin
          lane_seq[lane_local] = swb_frame_sequence::type_id::create($sformatf("lane_seq_%0d", lane_local));
          for (int idx = 0; idx < plan.frames_by_lane[lane_local].size(); idx++) begin
            lane_seq[lane_local].frames.push_back(plan.frames_by_lane[lane_local][idx]);
          end
          lane_seq[lane_local].start(opq_env.ingress_agents[lane_local].sequencer);
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

    if (swb_opq_2env_check_complete() != 0) begin
      `uvm_error("DPI_INCOMPLETE", "DPI ingress or OPQ egress replay was not fully consumed")
    end

    phase.drop_objection(this);
  end
  endtask
endclass
