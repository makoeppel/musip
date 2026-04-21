class swb_env extends uvm_env;
  swb_ingress_agent ingress_agents[SWB_N_LANES];
  swb_dma_monitor   dma_monitor;
  swb_scoreboard    scoreboard;

  `uvm_component_utils(swb_env)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    for (int lane = 0; lane < SWB_N_LANES; lane++) begin
      ingress_agents[lane] = swb_ingress_agent::type_id::create($sformatf("ingress_agent_%0d", lane), this);
      uvm_config_db#(int unsigned)::set(this, ingress_agents[lane].get_name(), "lane_id", lane);
    end
    dma_monitor = swb_dma_monitor::type_id::create("dma_monitor", this);
    scoreboard  = swb_scoreboard::type_id::create("scoreboard", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    dma_monitor.ap.connect(scoreboard.dma_imp);
  endfunction
endclass
