class swb_opq_ingress_sequencer extends uvm_sequencer #(swb_frame_item);
  `uvm_component_utils(swb_opq_ingress_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

class swb_opq_ingress_driver extends uvm_driver #(swb_frame_item);
  virtual feb_ingress_if vif;
  int unsigned lane_id;

  `uvm_component_utils(swb_opq_ingress_driver)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    lane_id = 0;
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual feb_ingress_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", $sformatf("No feb_ingress_if for %s", get_full_name()))
    end
    void'(uvm_config_db#(int unsigned)::get(this, "", "lane_id", lane_id));
  endfunction

  task drive_cycle(bit valid, bit [31:0] data, bit [3:0] datak);
    @(posedge vif.clk);
    vif.valid <= valid;
    vif.data  <= data;
    vif.datak <= datak;
    swb_opq_2env_push_ingress(lane_id, valid, data, datak);
  endtask

  task drive_frame(swb_frame_item frame);
    bit [31:0] data_word;
  begin
    drive_cycle(1'b1, {SWB_MUPIX_HEADER_ID, 2'b00, frame.feb_id, SWB_K285}, 4'b0001);
    drive_cycle(1'b1, frame.ts_high_word, 4'b0000);
    drive_cycle(1'b1, {frame.ts_low_word, frame.pkg_cnt}, 4'b0000);
    drive_cycle(1'b1, swb_make_debug_header0(frame), 4'b0000);
    drive_cycle(1'b1, 32'h0, 4'b0000);

    foreach (frame.subheaders[idx]) begin
      data_word = swb_make_subheader_word(frame.subheaders[idx]);
      drive_cycle(1'b1, data_word, 4'b0001);
      foreach (frame.subheaders[idx].hits[hit_idx]) begin
        drive_cycle(1'b1, frame.subheaders[idx].hits[hit_idx].payload_word, 4'b0000);
      end
    end

    drive_cycle(1'b1, {24'h0, SWB_K284}, 4'b0001);
    drive_cycle(1'b0, '0, '0);
  end
  endtask

  task run_phase(uvm_phase phase);
    swb_frame_item req;
  begin
    vif.drive_idle();
    forever begin
      seq_item_port.get_next_item(req);
      `uvm_info(
        "OPQ_DRV",
        $sformatf("Lane %0d driving frame %0d with %0d hits", lane_id, req.frame_id, req.hit_count()),
        UVM_MEDIUM
      )
      drive_frame(req);
      seq_item_port.item_done();
    end
  end
  endtask
endclass

class swb_opq_ingress_agent extends uvm_agent;
  swb_opq_ingress_sequencer sequencer;
  swb_opq_ingress_driver    driver;
  int unsigned              lane_id;

  `uvm_component_utils(swb_opq_ingress_agent)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    lane_id = 0;
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    void'(uvm_config_db#(int unsigned)::get(this, "", "lane_id", lane_id));
    sequencer = swb_opq_ingress_sequencer::type_id::create("sequencer", this);
    driver    = swb_opq_ingress_driver::type_id::create("driver", this);
    uvm_config_db#(int unsigned)::set(this, "driver", "lane_id", lane_id);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass

class swb_opq_egress_driver extends uvm_component;
  virtual opq_egress_if vif;
  virtual swb_ctrl_if   ctrl_vif;

  `uvm_component_utils(swb_opq_egress_driver)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual opq_egress_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", $sformatf("No opq_egress_if for %s", get_full_name()))
    end
    if (!uvm_config_db#(virtual swb_ctrl_if)::get(this, "", "ctrl_vif", ctrl_vif)) begin
      `uvm_fatal("NOCTRL", $sformatf("No swb_ctrl_if for %s", get_full_name()))
    end
  endfunction

  task run_phase(uvm_phase phase);
    int valid_i;
    int unsigned data_i;
    int unsigned datak_i;
  begin
    vif.drive_idle();
    forever begin
      @(posedge vif.clk);
      if (ctrl_vif.reset_n !== 1'b1) begin
        vif.drive_idle();
      end else begin
        swb_opq_2env_step_egress(valid_i, data_i, datak_i);
        vif.valid <= valid_i[0];
        vif.data  <= data_i[31:0];
        vif.datak <= datak_i[3:0];
      end
    end
  end
  endtask
endclass

class swb_dma_monitor extends uvm_component;
  virtual dma_sink_if vif;
  uvm_analysis_port #(swb_dma_word) ap;

  `uvm_component_utils(swb_dma_monitor)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual dma_sink_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", $sformatf("No dma_sink_if for %s", get_full_name()))
    end
  endfunction

  task run_phase(uvm_phase phase);
    swb_dma_word item;
  begin
    forever begin
      @(posedge vif.clk);
      if (vif.wren) begin
        item = swb_dma_word::type_id::create("dma_word");
        item.data         = vif.data;
        item.end_of_event = vif.end_of_event;
        ap.write(item);
      end
    end
  end
  endtask
endclass
