class swb_env extends uvm_env;
  swb_ingress_agent ingress_agents[SWB_N_LANES];
  swb_opq_monitor   opq_monitor;
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
    opq_monitor = swb_opq_monitor::type_id::create("opq_monitor", this);
    dma_monitor = swb_dma_monitor::type_id::create("dma_monitor", this);
    scoreboard  = swb_scoreboard::type_id::create("scoreboard", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    ingress_agents[0].monitor.ap.connect(scoreboard.ingress_imp0);
    ingress_agents[1].monitor.ap.connect(scoreboard.ingress_imp1);
    ingress_agents[2].monitor.ap.connect(scoreboard.ingress_imp2);
    ingress_agents[3].monitor.ap.connect(scoreboard.ingress_imp3);
    opq_monitor.ap.connect(scoreboard.opq_imp);
    dma_monitor.ap.connect(scoreboard.dma_imp);
  endfunction
endclass
