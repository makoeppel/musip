`uvm_analysis_imp_decl(_ingress0)
`uvm_analysis_imp_decl(_ingress1)
`uvm_analysis_imp_decl(_ingress2)
`uvm_analysis_imp_decl(_ingress3)
`uvm_analysis_imp_decl(_opq)
`uvm_analysis_imp_decl(_dma)

class swb_stage_hit extends uvm_object;
  string           stage_name;
  int unsigned     lane_id;
  int unsigned     observed_idx;
  int unsigned     frame_idx;
  int unsigned     subheader_idx;
  int unsigned     hit_idx;
  bit [63:0]       raw_hit_word;
  bit [63:0]       normalized_hit_word;
  longint unsigned debug_ts_8ns;
  int              hidden_id;
  string           ingress_sort_key;

  `uvm_object_utils(swb_stage_hit)

  function new(string name = "swb_stage_hit");
    super.new(name);
    stage_name = "";
    lane_id = 0;
    observed_idx = 0;
    frame_idx = 0;
    subheader_idx = 0;
    hit_idx = 0;
    raw_hit_word = '0;
    normalized_hit_word = '0;
    debug_ts_8ns = 0;
    hidden_id = -1;
    ingress_sort_key = "";
  endfunction

  function string convert2string();
    return $sformatf(
      "%s hit[%0d] id=%0d lane=%0d frame=%0d shd=%0d hit=%0d ts8ns=%0d norm=%016h",
      stage_name,
      observed_idx,
      hidden_id,
      lane_id,
      frame_idx,
      subheader_idx,
      hit_idx,
      debug_ts_8ns,
      normalized_hit_word
    );
  endfunction
endclass

typedef enum int {
  SWB_PARSE_EXPECT_SOP,
  SWB_PARSE_EXPECT_TS_HIGH,
  SWB_PARSE_EXPECT_TS_LOW,
  SWB_PARSE_EXPECT_DEBUG0,
  SWB_PARSE_EXPECT_DEBUG1,
  SWB_PARSE_EXPECT_BODY
} swb_stream_parse_state_e;

class swb_stream_parser_state;
  string                   stage_name;
  int unsigned             lane_id;
  swb_stream_parse_state_e state;
  int unsigned             frame_idx;
  int unsigned             subheader_idx;
  int unsigned             observed_hits;
  bit [31:0]               ts_high_word;
  bit [15:0]               ts_low_word;
  bit [7:0]                current_shd_ts;
  int unsigned             hits_remaining;
  int unsigned             hit_idx_in_subheader;

  function new(string stage_name_i, int unsigned lane_id_i);
  begin
    stage_name = stage_name_i;
    lane_id = lane_id_i;
    reset();
  end
  endfunction

  function void reset();
  begin
    state = SWB_PARSE_EXPECT_SOP;
    frame_idx = 0;
    subheader_idx = 0;
    observed_hits = 0;
    ts_high_word = '0;
    ts_low_word = '0;
    current_shd_ts = '0;
    hits_remaining = 0;
    hit_idx_in_subheader = 0;
  end
  endfunction

  function string state_name();
  begin
    case (state)
      SWB_PARSE_EXPECT_SOP:      return "EXPECT_SOP";
      SWB_PARSE_EXPECT_TS_HIGH:  return "EXPECT_TS_HIGH";
      SWB_PARSE_EXPECT_TS_LOW:   return "EXPECT_TS_LOW";
      SWB_PARSE_EXPECT_DEBUG0:   return "EXPECT_DEBUG0";
      SWB_PARSE_EXPECT_DEBUG1:   return "EXPECT_DEBUG1";
      SWB_PARSE_EXPECT_BODY:     return "EXPECT_BODY";
      default:                   return "UNKNOWN";
    endcase
  end
  endfunction
endclass

class swb_scoreboard extends uvm_component;
  uvm_analysis_imp_ingress0 #(swb_stream_beat, swb_scoreboard) ingress_imp0;
  uvm_analysis_imp_ingress1 #(swb_stream_beat, swb_scoreboard) ingress_imp1;
  uvm_analysis_imp_ingress2 #(swb_stream_beat, swb_scoreboard) ingress_imp2;
  uvm_analysis_imp_ingress3 #(swb_stream_beat, swb_scoreboard) ingress_imp3;
  uvm_analysis_imp_opq #(swb_stream_beat, swb_scoreboard) opq_imp;
  uvm_analysis_imp_dma #(swb_dma_word, swb_scoreboard) dma_imp;

  swb_case_plan           plan;
  bit                     expect_opq_merged;
  swb_stream_parser_state ingress_parsers[SWB_N_LANES];
  swb_stream_parser_state opq_parser;
  swb_stage_hit           ingress_hits[$];
  swb_stage_hit           opq_hits[$];
  swb_stage_hit           dma_hits[$];
  int unsigned            recv_words;
  int unsigned            padding_words;
  bit                     saw_end_of_event;
  int unsigned            parse_errors;
  int unsigned            opq_recv_beats;
  int unsigned            opq_ghost_count;
  int unsigned            opq_missing_count;
  int unsigned            dma_ghost_count;
  int unsigned            dma_missing_count;
  bit                     emit_hit_trace;
  string                  hit_trace_prefix;

  covergroup case_contract_cg with function sample(
    int unsigned expected_word_count_i,
    int unsigned total_hits_i,
    int unsigned active_lanes_i,
    int unsigned frame_count_i,
    int unsigned dma_half_full_pct_i,
    bit          use_merge_i,
    int unsigned hit_mode_id_i,
    bit          saw_end_of_event_i,
    int unsigned padding_words_i
  );
    option.per_instance = 1;

    cp_payload_words: coverpoint expected_word_count_i {
      bins payload_zero = {0};
      bins payload_one = {1};
      bins payload_small_words = {[2:4]};
      bins payload_medium_words = {[5:128]};
      bins payload_large_words = {[129:$]};
    }

    cp_total_hits: coverpoint total_hits_i {
      bins hits_zero = {0};
      bins hits_one_word = {[1:4]};
      bins hits_light = {[5:64]};
      bins hits_medium = {[65:512]};
      bins hits_heavy = {[513:$]};
    }

    cp_active_lanes: coverpoint active_lanes_i {
      bins lane_count_1 = {1};
      bins lane_count_2 = {2};
      bins lane_count_3 = {3};
      bins lane_count_4 = {4};
    }

    cp_frame_count: coverpoint frame_count_i {
      bins frame_count_1 = {1};
      bins frame_count_2 = {2};
      bins frame_count_short = {[3:8]};
      bins frame_count_long = {[9:$]};
    }

    cp_dma_half_full: coverpoint dma_half_full_pct_i {
      bins dma_backpressure_none = {0};
      bins dma_backpressure_light = {[1:25]};
      bins dma_backpressure_medium = {[26:50]};
      bins dma_backpressure_heavy = {[51:100]};
    }

    cp_use_merge: coverpoint use_merge_i {
      bins merge_bypass = {0};
      bins merge_enabled = {1};
    }

    cp_hit_mode: coverpoint hit_mode_id_i {
      bins hit_mode_poisson = {0};
      bins hit_mode_zero = {1};
      bins hit_mode_single = {2};
      bins hit_mode_max = {3};
    }

    cp_end_of_event: coverpoint saw_end_of_event_i {
      bins eoe_elided = {0};
      bins eoe_asserted = {1};
    }

    cp_padding_words: coverpoint padding_words_i {
      bins padding_none = {0};
      bins padding_fixed_128 = {128};
      bins padding_other = default;
    }

    cx_payload_merge: cross cp_payload_words, cp_use_merge;
    cx_lane_mode: cross cp_active_lanes, cp_hit_mode;
    cx_backpressure_payload: cross cp_dma_half_full, cp_payload_words;
  endgroup

  `uvm_component_utils(swb_scoreboard)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ingress_imp0 = new("ingress_imp0", this);
    ingress_imp1 = new("ingress_imp1", this);
    ingress_imp2 = new("ingress_imp2", this);
    ingress_imp3 = new("ingress_imp3", this);
    opq_imp = new("opq_imp", this);
    dma_imp = new("dma_imp", this);
    recv_words = 0;
    padding_words = 0;
    saw_end_of_event = 1'b0;
    parse_errors = 0;
    opq_recv_beats = 0;
    opq_ghost_count = 0;
    opq_missing_count = 0;
    dma_ghost_count = 0;
    dma_missing_count = 0;
    emit_hit_trace = 1'b0;
    hit_trace_prefix = "";
    case_contract_cg = new();
  endfunction

  function automatic int unsigned count_active_lanes(bit [3:0] mask);
    int unsigned lanes;
  begin
    lanes = 0;
    for (int idx = 0; idx < 4; idx++) begin
      if (mask[idx]) begin
        lanes++;
      end
    end
    return lanes;
  end
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(swb_case_plan)::get(this, "", "case_plan", plan)) begin
      `uvm_fatal("NOPLAN", "swb_case_plan missing from config_db")
    end
    if (!uvm_config_db#(bit)::get(this, "", "expect_opq_merged", expect_opq_merged)) begin
      expect_opq_merged = 1'b0;
    end
    emit_hit_trace = $value$plusargs("SWB_HIT_TRACE_PREFIX=%s", hit_trace_prefix);
    `uvm_info("SB_CFG", $sformatf("expect_opq_merged=%0d", expect_opq_merged), UVM_LOW)

    for (int lane = 0; lane < SWB_N_LANES; lane++) begin
      ingress_parsers[lane] = new($sformatf("lane%0d_ingress", lane), lane);
    end
    opq_parser = new("opq_egress", 0);
  endfunction

  function void note_parse_error(string id, string msg);
  begin
    parse_errors++;
    if (parse_errors <= 16) begin
      `uvm_error(id, msg)
    end
  end
  endfunction

  function void push_parsed_hit(
    ref swb_stage_hit stage_hits[$],
    input string      stage_name,
    input int unsigned lane_id,
    input int unsigned frame_idx,
    input int unsigned subheader_idx,
    input int unsigned hit_idx,
    input bit [63:0]  hit_word
  );
    swb_stage_hit item;
  begin
    item = swb_stage_hit::type_id::create($sformatf("%s_hit_%0d", stage_name, stage_hits.size()));
    item.stage_name = stage_name;
    item.lane_id = lane_id;
    item.observed_idx = stage_hits.size();
    item.frame_idx = frame_idx;
    item.subheader_idx = subheader_idx;
    item.hit_idx = hit_idx;
    item.raw_hit_word = hit_word;
    item.normalized_hit_word = swb_normalize_dma_hit_word(hit_word);
    item.debug_ts_8ns = swb_debug_ts_from_hit_word(item.normalized_hit_word);
    item.hidden_id = -1;
    item.ingress_sort_key = $sformatf(
      "%010h_%01d_%06d_%06d_%06d",
      item.debug_ts_8ns,
      lane_id,
      frame_idx,
      subheader_idx,
      hit_idx
    );
    stage_hits.push_back(item);
  end
  endfunction

  function void consume_stream_beat(
    swb_stream_parser_state parser,
    ref swb_stage_hit       stage_hits[$],
    swb_stream_beat         beat
  );
  begin
    case (parser.state)
      SWB_PARSE_EXPECT_SOP: begin
        if (!(beat.datak === 4'b0001 && beat.data[7:0] === SWB_K285 && beat.data[31:26] === SWB_MUPIX_HEADER_ID)) begin
          note_parse_error(
            "STREAM_PARSE",
            $sformatf(
              "%s expected SOP at beat %0d, got %s",
              parser.stage_name,
              beat.beat_idx,
              beat.convert2string()
            )
          );
          return;
        end
        parser.subheader_idx = 0;
        parser.state = SWB_PARSE_EXPECT_TS_HIGH;
      end

      SWB_PARSE_EXPECT_TS_HIGH: begin
        if (beat.datak !== 4'b0000) begin
          note_parse_error(
            "STREAM_PARSE",
            $sformatf("%s expected ts_high payload at beat %0d, got %s", parser.stage_name, beat.beat_idx, beat.convert2string())
          );
          return;
        end
        parser.ts_high_word = beat.data;
        parser.state = SWB_PARSE_EXPECT_TS_LOW;
      end

      SWB_PARSE_EXPECT_TS_LOW: begin
        if (beat.datak !== 4'b0000) begin
          note_parse_error(
            "STREAM_PARSE",
            $sformatf("%s expected ts_low/pkg payload at beat %0d, got %s", parser.stage_name, beat.beat_idx, beat.convert2string())
          );
          return;
        end
        parser.ts_low_word = beat.data[31:16];
        parser.state = SWB_PARSE_EXPECT_DEBUG0;
      end

      SWB_PARSE_EXPECT_DEBUG0: begin
        if (beat.datak !== 4'b0000) begin
          note_parse_error(
            "STREAM_PARSE",
            $sformatf("%s expected debug0 payload at beat %0d, got %s", parser.stage_name, beat.beat_idx, beat.convert2string())
          );
          return;
        end
        parser.state = SWB_PARSE_EXPECT_DEBUG1;
      end

      SWB_PARSE_EXPECT_DEBUG1: begin
        if (beat.datak !== 4'b0000) begin
          note_parse_error(
            "STREAM_PARSE",
            $sformatf("%s expected debug1 payload at beat %0d, got %s", parser.stage_name, beat.beat_idx, beat.convert2string())
          );
          return;
        end
        parser.state = SWB_PARSE_EXPECT_BODY;
      end

      SWB_PARSE_EXPECT_BODY: begin
        if (parser.hits_remaining != 0) begin
          if (beat.datak !== 4'b0000) begin
            note_parse_error(
              "STREAM_PARSE",
              $sformatf("%s expected hit payload at beat %0d, got %s", parser.stage_name, beat.beat_idx, beat.convert2string())
            );
            return;
          end
          push_parsed_hit(
            stage_hits,
            parser.stage_name,
            parser.lane_id,
            parser.frame_idx,
            parser.subheader_idx,
            parser.hit_idx_in_subheader,
            swb_make_expected_mupix_hit(parser.ts_high_word, parser.ts_low_word, parser.current_shd_ts, beat.data)
          );
          parser.hits_remaining--;
          parser.hit_idx_in_subheader++;
        end else if (beat.datak === 4'b0001 && beat.data[7:0] === SWB_K284) begin
          parser.frame_idx++;
          parser.state = SWB_PARSE_EXPECT_SOP;
        end else if (beat.datak === 4'b0001 && beat.data[7:0] === SWB_K237) begin
          parser.current_shd_ts = beat.data[31:24];
          parser.hits_remaining = beat.data[15:8];
          parser.hit_idx_in_subheader = 0;
          parser.subheader_idx++;
        end else begin
          note_parse_error(
            "STREAM_PARSE",
            $sformatf(
              "%s expected subheader or EOP at beat %0d, got %s",
              parser.stage_name,
              beat.beat_idx,
              beat.convert2string()
            )
          );
        end
      end
    endcase
  end
  endfunction

  function void parse_dma_hits(swb_dma_word item);
  begin
    if (item.data === {4{64'hFFFF_FFFF_FFFF_FFFF}}) begin
      padding_words++;
    end else begin
      for (int idx = 0; idx < 4; idx++) begin
        bit [63:0] raw_hit_word;
        raw_hit_word = item.data[(idx * 64) +: 64];
        push_parsed_hit(dma_hits, "dma", idx, recv_words, 0, idx, raw_hit_word);
      end
      recv_words++;
    end

    if (item.end_of_event) begin
      saw_end_of_event = 1'b1;
    end
  end
  endfunction

  function string hit_key(bit [63:0] normalized_hit_word);
  begin
    return $sformatf("%016h", normalized_hit_word);
  end
  endfunction

  function void dump_stage_hits(
    input string      path,
    ref swb_stage_hit stage_hits[$]
  );
    int fd;
  begin
    fd = $fopen(path, "w");
    if (fd == 0) begin
      `uvm_error("HIT_TRACE", $sformatf("Unable to open hit trace file %s", path))
      return;
    end

    $fdisplay(fd, "stage_name\tobserved_idx\thidden_id\tlane_id\tframe_idx\tsubheader_idx\thit_idx\tdebug_ts_8ns\tnormalized_hit_word\traw_hit_word\tingress_sort_key");
    foreach (stage_hits[idx]) begin
      $fdisplay(
        fd,
        "%s\t%0d\t%0d\t%0d\t%0d\t%0d\t%0d\t%0d\t%016h\t%016h\t%s",
        stage_hits[idx].stage_name,
        stage_hits[idx].observed_idx,
        stage_hits[idx].hidden_id,
        stage_hits[idx].lane_id,
        stage_hits[idx].frame_idx,
        stage_hits[idx].subheader_idx,
        stage_hits[idx].hit_idx,
        stage_hits[idx].debug_ts_8ns,
        stage_hits[idx].normalized_hit_word,
        stage_hits[idx].raw_hit_word,
        stage_hits[idx].ingress_sort_key
      );
    end
    void'($fclose(fd));
  end
  endfunction

  function void dump_hit_trace_summary(
    input string      path,
    ref swb_stage_hit expected_hits[$],
    input bit         scoreboard_pass
  );
    int fd;
  begin
    fd = $fopen(path, "w");
    if (fd == 0) begin
      `uvm_error("HIT_TRACE", $sformatf("Unable to open hit trace summary file %s", path))
      return;
    end

    $fdisplay(fd, "scoreboard_pass=%0d", scoreboard_pass);
    $fdisplay(fd, "profile_name=%s", plan.profile_name);
    $fdisplay(fd, "case_seed=%0d", plan.case_seed);
    $fdisplay(fd, "raw_total_hits_before_padding=%0d", plan.raw_total_hits_before_padding);
    $fdisplay(fd, "padding_hits_added=%0d", plan.padding_hits_added);
    $fdisplay(fd, "expect_opq_merged=%0d", expect_opq_merged);
    $fdisplay(fd, "expected_payload_words=%0d", plan.expected_dma_words.size());
    $fdisplay(fd, "observed_payload_words=%0d", recv_words);
    $fdisplay(fd, "padding_words=%0d", padding_words);
    $fdisplay(fd, "parse_errors=%0d", parse_errors);
    $fdisplay(fd, "saw_end_of_event=%0d", saw_end_of_event);
    $fdisplay(fd, "ingress_hits=%0d", ingress_hits.size());
    $fdisplay(fd, "expected_hits=%0d", expected_hits.size());
    $fdisplay(fd, "opq_hits=%0d", opq_hits.size());
    $fdisplay(fd, "dma_hits=%0d", dma_hits.size());
    $fdisplay(fd, "opq_ghost_count=%0d", opq_ghost_count);
    $fdisplay(fd, "opq_missing_count=%0d", opq_missing_count);
    $fdisplay(fd, "dma_ghost_count=%0d", dma_ghost_count);
    $fdisplay(fd, "dma_missing_count=%0d", dma_missing_count);
    void'($fclose(fd));
  end
  endfunction

  function void map_stage_hits(
    input string   stage_name,
    ref swb_stage_hit expected_hits[$],
    ref swb_stage_hit actual_hits[$],
    input bit      enforce_order
  );
    int expected_ids_by_key[string][$];
    int missing_count;
    int ghost_count;
    int compare_count;
  begin
    foreach (expected_hits[idx]) begin
      expected_ids_by_key[hit_key(expected_hits[idx].normalized_hit_word)].push_back(expected_hits[idx].hidden_id);
    end

    ghost_count = 0;
    foreach (actual_hits[idx]) begin
      string key;
      key = hit_key(actual_hits[idx].normalized_hit_word);
      if (!expected_ids_by_key.exists(key) || expected_ids_by_key[key].size() == 0) begin
        ghost_count++;
        if (ghost_count <= 16) begin
          `uvm_error(
            "HIT_GHOST",
            $sformatf("%s observed unexpected hit %s", stage_name, actual_hits[idx].convert2string())
          )
        end
      end else begin
        actual_hits[idx].hidden_id = expected_ids_by_key[key].pop_front();
      end
    end

    missing_count = 0;
    foreach (expected_ids_by_key[key]) begin
      missing_count += expected_ids_by_key[key].size();
      if (expected_ids_by_key[key].size() != 0 && missing_count <= 16) begin
        `uvm_error(
          "HIT_MISSING",
          $sformatf("%s missed %0d hit(s) with key=%s", stage_name, expected_ids_by_key[key].size(), key)
        )
      end
    end

    if (enforce_order) begin
      compare_count = (actual_hits.size() < expected_hits.size()) ? actual_hits.size() : expected_hits.size();
      for (int idx = 0; idx < compare_count; idx++) begin
        if (actual_hits[idx].hidden_id != expected_hits[idx].hidden_id) begin
          `uvm_error(
            "HIT_ORDER",
            $sformatf(
              "%s order mismatch at idx=%0d expected=id%0d ts=%0d norm=%016h actual=id%0d ts=%0d norm=%016h",
              stage_name,
              idx,
              expected_hits[idx].hidden_id,
              expected_hits[idx].debug_ts_8ns,
              expected_hits[idx].normalized_hit_word,
              actual_hits[idx].hidden_id,
              actual_hits[idx].debug_ts_8ns,
              actual_hits[idx].normalized_hit_word
            )
          )
          break;
        end
      end
    end

    `uvm_info(
      "HIT_STAGE_SUMMARY",
      $sformatf(
        "%s expected=%0d actual=%0d ghosts=%0d missing=%0d",
        stage_name,
        expected_hits.size(),
        actual_hits.size(),
        ghost_count,
        missing_count
      ),
      UVM_LOW
    )

    if (stage_name == "opq") begin
      opq_ghost_count = ghost_count;
      opq_missing_count = missing_count;
    end else if (stage_name == "dma") begin
      dma_ghost_count = ghost_count;
      dma_missing_count = missing_count;
    end
  end
  endfunction

  function void write_ingress0(swb_stream_beat item);
    consume_stream_beat(ingress_parsers[0], ingress_hits, item);
  endfunction

  function void write_ingress1(swb_stream_beat item);
    consume_stream_beat(ingress_parsers[1], ingress_hits, item);
  endfunction

  function void write_ingress2(swb_stream_beat item);
    consume_stream_beat(ingress_parsers[2], ingress_hits, item);
  endfunction

  function void write_ingress3(swb_stream_beat item);
    consume_stream_beat(ingress_parsers[3], ingress_hits, item);
  endfunction

  function void write_opq(swb_stream_beat item);
    if (expect_opq_merged) begin
      opq_recv_beats++;
      if (opq_recv_beats <= 32) begin
        `uvm_info(
          "OPQ_RAW",
          $sformatf(
            "recv=%0d state=%s beat=%s",
            opq_recv_beats - 1,
            opq_parser.state_name(),
            item.convert2string()
          ),
          UVM_LOW
        )
      end
      consume_stream_beat(opq_parser, opq_hits, item);
    end
  endfunction

  function void write_dma(swb_dma_word item);
    parse_dma_hits(item);
  endfunction

  function void check_phase(uvm_phase phase);
    swb_stage_hit expected_merged_hits[$];
    bit           ingress_complete;
    bit           opq_complete;
    bit           scoreboard_pass;
    bit           require_dma_completion;
    bit           padding_contract_ok;
  begin
    super.check_phase(phase);
    ingress_complete = 1'b1;
    opq_complete = 1'b1;
    require_dma_completion = (plan.expected_dma_words.size() != 0);
    padding_contract_ok = 1'b1;

    if (recv_words != plan.expected_dma_words.size()) begin
      `uvm_error(
        "DMA_SHORT",
        $sformatf("Expected %0d payload words but observed %0d", plan.expected_dma_words.size(), recv_words)
      )
    end
    if (require_dma_completion && !saw_end_of_event) begin
      `uvm_error("DMA_EOE", "No end-of-event marker observed on DMA output")
    end
    if (require_dma_completion && padding_words != 128) begin
      padding_contract_ok = 1'b0;
      `uvm_error(
        "DMA_PADDING",
        $sformatf("Expected the fixed 128-word padding tail but observed %0d padding words", padding_words)
      )
    end
    if (!require_dma_completion && padding_words != 0) begin
      padding_contract_ok = 1'b0;
      `uvm_error(
        "DMA_PADDING_ZERO",
        $sformatf("Zero-payload case unexpectedly emitted %0d padding words", padding_words)
      )
    end

    for (int lane = 0; lane < SWB_N_LANES; lane++) begin
      if (ingress_parsers[lane].state != SWB_PARSE_EXPECT_SOP || ingress_parsers[lane].hits_remaining != 0) begin
        ingress_complete = 1'b0;
        `uvm_error(
          "STREAM_PARSE_INCOMPLETE",
          $sformatf(
            "lane%0d ingress parser ended in state=%s hits_remaining=%0d",
            lane,
            ingress_parsers[lane].state_name(),
            ingress_parsers[lane].hits_remaining
          )
        )
      end
    end

    if (expect_opq_merged && (opq_parser.state != SWB_PARSE_EXPECT_SOP || opq_parser.hits_remaining != 0)) begin
      opq_complete = 1'b0;
      `uvm_error(
        "STREAM_PARSE_INCOMPLETE",
        $sformatf(
          "opq parser ended in state=%s hits_remaining=%0d",
          opq_parser.state_name(),
          opq_parser.hits_remaining
        )
      )
    end

    foreach (ingress_hits[idx]) begin
      if (plan.feb_enable_mask[ingress_hits[idx].lane_id]) begin
        expected_merged_hits.push_back(ingress_hits[idx]);
      end
    end
    expected_merged_hits.sort with (item.ingress_sort_key);
    foreach (expected_merged_hits[idx]) begin
      expected_merged_hits[idx].hidden_id = idx;
    end

    if (expect_opq_merged) begin
      // The merged OPQ path is allowed to reorder hits across ingress lanes within a
      // subheader slot. Validate lineage by hit identity/timestamp, not ingress append order.
      map_stage_hits("opq", expected_merged_hits, opq_hits, 1'b0);
    end
    map_stage_hits("dma", expected_merged_hits, dma_hits, 1'b0);

    `uvm_info(
      "DMA_SUMMARY",
      $sformatf(
        "Compared %0d payload words, ignored %0d trailing padding words, ingress_hits=%0d opq_hits=%0d dma_hits=%0d parse_errors=%0d",
        recv_words,
        padding_words,
        ingress_hits.size(),
        opq_hits.size(),
        dma_hits.size(),
        parse_errors
      ),
      UVM_LOW
    )

    scoreboard_pass =
      (parse_errors == 0) &&
      ingress_complete &&
      (!expect_opq_merged || opq_complete) &&
      padding_contract_ok &&
      (!require_dma_completion || saw_end_of_event) &&
      (recv_words == plan.expected_dma_words.size()) &&
      (dma_ghost_count == 0) &&
      (dma_missing_count == 0) &&
      (!expect_opq_merged || ((opq_ghost_count == 0) && (opq_missing_count == 0)));

    case_contract_cg.sample(
      plan.expected_word_count,
      plan.total_hits,
      count_active_lanes(plan.feb_enable_mask),
      plan.frame_count,
      plan.dma_half_full_pct,
      plan.use_merge,
      plan.hit_mode_id,
      saw_end_of_event,
      padding_words
    );

    if (emit_hit_trace) begin
      dump_stage_hits({hit_trace_prefix, "_expected_hits.tsv"}, expected_merged_hits);
      dump_stage_hits({hit_trace_prefix, "_ingress_hits.tsv"}, ingress_hits);
      if (expect_opq_merged) begin
        dump_stage_hits({hit_trace_prefix, "_opq_hits.tsv"}, opq_hits);
      end
      dump_stage_hits({hit_trace_prefix, "_dma_hits.tsv"}, dma_hits);
      dump_hit_trace_summary({hit_trace_prefix, "_summary.txt"}, expected_merged_hits, scoreboard_pass);
      `uvm_info("HIT_TRACE", $sformatf("Wrote hit-trace artifacts with prefix %s", hit_trace_prefix), UVM_LOW)
    end

    if (scoreboard_pass) begin
      `uvm_info(
        "SWB_CHECK_PASS",
        $sformatf(
          "profile=%s case_seed=%0d payload_words=%0d padding_words=%0d ingress_hits=%0d opq_hits=%0d dma_hits=%0d",
          plan.profile_name,
          plan.case_seed,
          recv_words,
          padding_words,
          ingress_hits.size(),
          opq_hits.size(),
          dma_hits.size()
        ),
        UVM_NONE
      )
    end
  end
  endfunction
endclass
