class swb_opq_env extends uvm_env;
  swb_opq_ingress_agent ingress_agents[SWB_N_LANES];

  `uvm_component_utils(swb_opq_env)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    for (int lane = 0; lane < SWB_N_LANES; lane++) begin
      ingress_agents[lane] = swb_opq_ingress_agent::type_id::create($sformatf("ingress_agent_%0d", lane), this);
      uvm_config_db#(int unsigned)::set(this, ingress_agents[lane].get_name(), "lane_id", lane);
    end
  endfunction
endclass

class swb_datapath_env extends uvm_env;
  swb_opq_egress_driver egress_driver;
  swb_dma_monitor       dma_monitor;
  swb_scoreboard        scoreboard;

  `uvm_component_utils(swb_datapath_env)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    egress_driver = swb_opq_egress_driver::type_id::create("egress_driver", this);
    dma_monitor   = swb_dma_monitor::type_id::create("dma_monitor", this);
    scoreboard    = swb_scoreboard::type_id::create("scoreboard", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    dma_monitor.ap.connect(scoreboard.dma_imp);
  endfunction
endclass
