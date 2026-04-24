class swb_ingress_sequencer extends uvm_sequencer #(swb_frame_item);
  `uvm_component_utils(swb_ingress_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

class swb_ingress_driver extends uvm_driver #(swb_frame_item);
  virtual feb_ingress_if vif;
  int unsigned lane_id;
  int unsigned frame_slot_cycles;

  `uvm_component_utils(swb_ingress_driver)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    lane_id = 0;
    frame_slot_cycles = 0;
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual feb_ingress_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", $sformatf("No feb_ingress_if for %s", get_full_name()))
    end
    void'(uvm_config_db#(int unsigned)::get(this, "", "lane_id", lane_id));
    void'($value$plusargs("SWB_FRAME_SLOT_CYCLES=%d", frame_slot_cycles));
  endfunction

  task drive_cycle(bit valid, bit [31:0] data, bit [3:0] datak);
    @(posedge vif.clk);
    vif.valid <= valid;
    vif.data  <= data;
    vif.datak <= datak;
  endtask

  task drive_idle_cycles(int unsigned idle_cycles);
  begin
    repeat (idle_cycles) begin
      drive_cycle(1'b0, '0, '0);
    end
  end
  endtask

  function int unsigned frame_transfer_cycles_used(swb_frame_item frame);
    return 7 + frame.subheader_count() + frame.hit_count();
  endfunction

  function int unsigned frame_slot_cycles_used(swb_frame_item frame);
    return frame.pre_sop_cycles + frame_transfer_cycles_used(frame);
  endfunction

  task pad_to_frame_slot(swb_frame_item frame);
    int unsigned used_cycles;
    int unsigned pad_cycles;
  begin
    if (frame_slot_cycles == 0) begin
      return;
    end

    used_cycles = frame_slot_cycles_used(frame);
    if (used_cycles > frame_slot_cycles) begin
      `uvm_fatal(
        "FRAME_SLOT",
        $sformatf(
          "Lane %0d frame %0d consumes %0d cycles but SWB_FRAME_SLOT_CYCLES=%0d",
          lane_id,
          frame.frame_id,
          used_cycles,
          frame_slot_cycles
        )
      )
    end

    pad_cycles = frame_slot_cycles - used_cycles;
    drive_idle_cycles(pad_cycles);
  end
  endtask

  task drive_frame(swb_frame_item frame);
    bit [31:0] data_word;
  begin
    if (frame.pre_sop_cycles != 0) begin
      drive_idle_cycles(frame.pre_sop_cycles);
    end
    drive_cycle(1'b1, {frame.header_id, 2'b00, frame.feb_id, SWB_K285}, 4'b0001);
    drive_cycle(1'b1, frame.ts_high_word, 4'b0000);
    drive_cycle(1'b1, {frame.ts_low_word, frame.pkg_cnt}, 4'b0000);
    drive_cycle(1'b1, swb_make_debug_header0(frame), 4'b0000);
    drive_cycle(1'b1, {1'b0, frame.debug1_word}, 4'b0000);

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
        "DRV",
        $sformatf(
          "Lane %0d driving frame %0d with %0d hits%s%s",
          lane_id,
          req.frame_id,
          req.hit_count(),
          (req.pre_sop_cycles != 0)
            ? $sformatf(" (skew=%0d cyc)", req.pre_sop_cycles)
            : "",
          (frame_slot_cycles != 0)
            ? $sformatf(" (slot=%0d cyc, used=%0d cyc)", frame_slot_cycles, frame_slot_cycles_used(req))
            : ""
        ),
        UVM_MEDIUM
      )
      drive_frame(req);
      pad_to_frame_slot(req);
      seq_item_port.item_done();
    end
  end
  endtask
endclass

class swb_ingress_monitor extends uvm_component;
  virtual feb_ingress_if vif;
  uvm_analysis_port #(swb_stream_beat) ap;
  int unsigned lane_id;
  int unsigned beat_count;

  `uvm_component_utils(swb_ingress_monitor)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
    lane_id = 0;
    beat_count = 0;
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual feb_ingress_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", $sformatf("No feb_ingress_if for %s", get_full_name()))
    end
    void'(uvm_config_db#(int unsigned)::get(this, "", "lane_id", lane_id));
  endfunction

  task run_phase(uvm_phase phase);
    swb_stream_beat item;
  begin
    forever begin
      @(posedge vif.clk);
      if (vif.valid === 1'b1) begin
        item = swb_stream_beat::type_id::create($sformatf("lane%0d_ingress_beat", lane_id));
        item.lane_id = lane_id;
        item.beat_idx = beat_count;
        item.data = vif.data;
        item.datak = vif.datak;
        item.stream_name = $sformatf("lane%0d_ingress", lane_id);
        beat_count++;
        ap.write(item);
      end
    end
  end
  endtask
endclass

class swb_ingress_agent extends uvm_agent;
  swb_ingress_sequencer sequencer;
  swb_ingress_driver    driver;
  swb_ingress_monitor   monitor;
  int unsigned          lane_id;

  `uvm_component_utils(swb_ingress_agent)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    lane_id = 0;
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    void'(uvm_config_db#(int unsigned)::get(this, "", "lane_id", lane_id));
    sequencer = swb_ingress_sequencer::type_id::create("sequencer", this);
    driver    = swb_ingress_driver::type_id::create("driver", this);
    monitor   = swb_ingress_monitor::type_id::create("monitor", this);
    uvm_config_db#(int unsigned)::set(this, "driver", "lane_id", lane_id);
    uvm_config_db#(int unsigned)::set(this, "monitor", "lane_id", lane_id);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass

class swb_opq_monitor extends uvm_component;
  virtual opq_egress_if vif;
  uvm_analysis_port #(swb_stream_beat) ap;
  int unsigned beat_count;

  `uvm_component_utils(swb_opq_monitor)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
    beat_count = 0;
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual opq_egress_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", $sformatf("No opq_egress_if for %s", get_full_name()))
    end
  endfunction

  task run_phase(uvm_phase phase);
    swb_stream_beat item;
  begin
    forever begin
      @(posedge vif.clk);
      if (vif.valid === 1'b1) begin
        item = swb_stream_beat::type_id::create("opq_egress_beat");
        item.lane_id = 0;
        item.beat_idx = beat_count;
        item.data = vif.data;
        item.datak = vif.datak;
        item.stream_name = "opq_egress";
        beat_count++;
        ap.write(item);
      end
    end
  end
  endtask
endclass

class swb_dma_monitor extends uvm_component;
  virtual dma_sink_if vif;
  uvm_analysis_port #(swb_dma_word) ap;
  int unsigned word_count;

  `uvm_component_utils(swb_dma_monitor)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
    word_count = 0;
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
        word_count++;
        ap.write(item);
      end
    end
  end
  endtask
endclass
