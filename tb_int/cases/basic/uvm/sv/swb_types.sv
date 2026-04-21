class swb_hit_desc extends uvm_object;
  rand bit [31:0] payload_word;

  `uvm_object_utils(swb_hit_desc)

  function new(string name = "swb_hit_desc");
    super.new(name);
    payload_word = '0;
  endfunction

  function swb_hit_desc copy_item();
    swb_hit_desc copy;
    copy = swb_hit_desc::type_id::create("copy");
    copy.payload_word = payload_word;
    return copy;
  endfunction
endclass

class swb_subheader_desc extends uvm_object;
  rand bit [7:0] shd_ts;
  swb_hit_desc hits[$];

  `uvm_object_utils(swb_subheader_desc)

  function new(string name = "swb_subheader_desc");
    super.new(name);
    shd_ts = '0;
  endfunction

  function int unsigned hit_count();
    return hits.size();
  endfunction

  function swb_subheader_desc copy_item();
    swb_subheader_desc copy;
    copy = swb_subheader_desc::type_id::create("copy");
    copy.shd_ts = shd_ts;
    foreach (hits[idx]) begin
      copy.hits.push_back(hits[idx].copy_item());
    end
    return copy;
  endfunction
endclass

class swb_frame_item extends uvm_sequence_item;
  int unsigned lane_id;
  int unsigned frame_id;
  bit [31:0]   ts_high_word;
  bit [15:0]   ts_low_word;
  bit [15:0]   pkg_cnt;
  bit [15:0]   feb_id;
  swb_subheader_desc subheaders[$];

  `uvm_object_utils(swb_frame_item)

  function new(string name = "swb_frame_item");
    super.new(name);
    lane_id      = 0;
    frame_id     = 0;
    ts_high_word = '0;
    ts_low_word  = '0;
    pkg_cnt      = '0;
    feb_id       = '0;
  endfunction

  function int unsigned subheader_count();
    return subheaders.size();
  endfunction

  function int unsigned hit_count();
    int unsigned total;
    total = 0;
    foreach (subheaders[idx]) begin
      total += subheaders[idx].hit_count();
    end
    return total;
  endfunction

  function swb_frame_item copy_item();
    swb_frame_item copy;
    copy = swb_frame_item::type_id::create("copy");
    copy.lane_id      = lane_id;
    copy.frame_id     = frame_id;
    copy.ts_high_word = ts_high_word;
    copy.ts_low_word  = ts_low_word;
    copy.pkg_cnt      = pkg_cnt;
    copy.feb_id       = feb_id;
    foreach (subheaders[idx]) begin
      copy.subheaders.push_back(subheaders[idx].copy_item());
    end
    return copy;
  endfunction
endclass

class swb_dma_word extends uvm_sequence_item;
  bit [255:0] data;
  bit         end_of_event;

  `uvm_object_utils(swb_dma_word)

  function new(string name = "swb_dma_word");
    super.new(name);
    data         = '0;
    end_of_event = 1'b0;
  endfunction
endclass

class swb_case_plan extends uvm_object;
  swb_frame_item frames_by_lane[SWB_N_LANES][$];
  bit [255:0] expected_dma_words[$];
  int unsigned expected_word_count;
  int unsigned total_hits;
  real lane_saturation[SWB_N_LANES];

  `uvm_object_utils(swb_case_plan)

  function new(string name = "swb_case_plan");
    super.new(name);
    clear();
  endfunction

  function void clear();
    expected_dma_words.delete();
    expected_word_count = 0;
    total_hits          = 0;
    foreach (frames_by_lane[lane]) begin
      frames_by_lane[lane].delete();
      lane_saturation[lane] = 0.0;
    end
  endfunction
endclass

typedef struct {
  longint unsigned abs_ts;
  bit [63:0]       hit_word;
} swb_hit_record_t;

typedef struct packed {
  bit        valid;
  bit [3:0]  datak;
  bit [31:0] data;
} swb_ingress_beat_t;

function automatic int unsigned swb_poisson_trunc(real lambda, int unsigned max_hits);
  real threshold;
  real product;
  real sample_u;
  int unsigned k;
begin
  if (lambda <= 0.0) begin
    return 0;
  end

  threshold = $exp(-lambda);
  product   = 1.0;
  k         = 0;

  do begin
    sample_u = ($urandom_range(1, 1000000) / 1000000.0);
    product *= sample_u;
    k++;
  end while ((product > threshold) && (k <= max_hits));

  if (k == 0) begin
    return 0;
  end
  if ((k - 1) > max_hits) begin
    return max_hits;
  end
  return k - 1;
end
endfunction

function automatic bit [31:0] swb_make_hit_payload(
  int unsigned lane_id,
  int unsigned frame_id,
  int unsigned subheader_idx,
  int unsigned hit_idx
);
  bit [31:0] payload_word;
  bit [3:0]  low_nibble;
begin
  payload_word = '0;
  low_nibble = lane_id[3:0] + (hit_idx[3:0] * 4);
  payload_word[31:28] = low_nibble;
  payload_word[25:22] = lane_id[3:0];
  payload_word[21:14] = (frame_id * 13 + subheader_idx * 3 + hit_idx) & 8'hff;
  payload_word[13:6]  = (lane_id * 17 + subheader_idx + hit_idx * 7) & 8'hff;
  payload_word[5:1]   = (hit_idx + frame_id) & 5'h1f;
  return payload_word;
end
endfunction

function automatic bit [31:0] swb_make_debug_header0(swb_frame_item frame);
  bit [31:0] data_word;
begin
  data_word = '0;
  data_word[30:16] = frame.subheader_count()[14:0];
  data_word[15:0]  = frame.hit_count()[15:0];
  return data_word;
end
endfunction

function automatic bit [31:0] swb_make_subheader_word(swb_subheader_desc shd);
  bit [31:0] data_word;
begin
  data_word = '0;
  data_word[31:24] = shd.shd_ts;
  data_word[15:8]  = shd.hit_count()[7:0];
  data_word[7:0]   = SWB_K237;
  return data_word;
end
endfunction

function automatic bit [63:0] swb_make_expected_mupix_hit(
  bit [31:0] ts_high_word,
  bit [15:0] ts_low_word,
  bit [7:0]  shd_ts,
  bit [31:0] hit_word
);
  bit [63:0] data_word;
begin
  data_word            = '0;
  data_word[63]        = 1'b0;
  data_word[62:58]     = 5'b0;
  data_word[57:50]     = hit_word[21:14];
  data_word[49:42]     = hit_word[13:6];
  data_word[41:37]     = hit_word[5:1];
  data_word[36:0]      = {
    ts_high_word[20:0],
    ts_low_word[15:11],
    shd_ts[6:0],
    hit_word[31:28]
  };
  return data_word;
end
endfunction

function automatic longint unsigned swb_make_abs_ts(
  bit [31:0] ts_high_word,
  bit [15:0] ts_low_word,
  bit [7:0]  shd_ts,
  bit [31:0] hit_word
);
begin
  return {
    27'b0,
    ts_high_word[20:0],
    ts_low_word[15:11],
    shd_ts[6:0],
    hit_word[31:28]
  };
end
endfunction

function automatic bit [255:0] swb_pack_dma_word(bit [63:0] hit_words[4]);
  bit [255:0] packed_word;
begin
  packed_word = '0;
  packed_word[63:0]    = hit_words[0];
  packed_word[127:64]  = hit_words[1];
  packed_word[191:128] = hit_words[2];
  packed_word[255:192] = hit_words[3];
  return packed_word;
end
endfunction

function automatic bit [255:0] swb_normalize_dma_word(bit [255:0] data_word);
  bit [255:0] normalized;
begin
  normalized = data_word;
  normalized[62:58]    = '0;
  normalized[126:122]  = '0;
  normalized[190:186]  = '0;
  normalized[254:250]  = '0;
  return normalized;
end
endfunction

class swb_case_builder extends uvm_object;
  `uvm_object_utils(swb_case_builder)

  function new(string name = "swb_case_builder");
    super.new(name);
  endfunction

  static function void add_hit_to_subheader(
    swb_frame_item frame,
    swb_subheader_desc shd,
    int unsigned lane_id,
    int unsigned frame_id,
    int unsigned subheader_idx
  );
    swb_hit_desc hit;
    int unsigned hit_idx;
  begin
    hit_idx = shd.hits.size();
    hit = swb_hit_desc::type_id::create($sformatf("hit_%0d_%0d_%0d_%0d", lane_id, frame_id, subheader_idx, hit_idx));
    hit.payload_word = swb_make_hit_payload(lane_id, frame_id, subheader_idx, hit_idx);
    shd.hits.push_back(hit);
  end
  endfunction

  static function void pack_expected_words(ref swb_case_plan plan);
    swb_hit_record_t records[$];
    bit [63:0] word_pack[4];
    int unsigned pack_idx;
  begin
    plan.expected_dma_words.delete();
    plan.total_hits = 0;

    foreach (plan.frames_by_lane[lane, frame_idx]) begin
      swb_frame_item frame;
      frame = plan.frames_by_lane[lane][frame_idx];
      foreach (frame.subheaders[shd_idx]) begin
        swb_subheader_desc shd;
        shd = frame.subheaders[shd_idx];
        foreach (shd.hits[hit_idx]) begin
          swb_hit_record_t record;
          bit [31:0] payload_word;
          payload_word = shd.hits[hit_idx].payload_word;
          record.abs_ts = swb_make_abs_ts(frame.ts_high_word, frame.ts_low_word, shd.shd_ts, payload_word);
          record.hit_word = swb_make_expected_mupix_hit(frame.ts_high_word, frame.ts_low_word, shd.shd_ts, payload_word);
          records.push_back(record);
          plan.total_hits++;
        end
      end
    end

    if ((records.size() % 4) != 0) begin
      `uvm_fatal("CASE", $sformatf("Total hit count %0d is not divisible by 4", records.size()))
    end

    records.sort with (item.abs_ts);
    pack_idx = 0;
    foreach (records[idx]) begin
      word_pack[pack_idx] = records[idx].hit_word;
      pack_idx++;
      if (pack_idx == 4) begin
        plan.expected_dma_words.push_back(swb_pack_dma_word(word_pack));
        pack_idx = 0;
      end
    end

    plan.expected_word_count = plan.expected_dma_words.size();
  end
  endfunction

  static function int unsigned count_total_hits(ref swb_case_plan plan);
    int unsigned total_hits;
  begin
    total_hits = 0;
    foreach (plan.frames_by_lane[lane, frame_idx]) begin
      total_hits += plan.frames_by_lane[lane][frame_idx].hit_count();
    end
    return total_hits;
  end
  endfunction

  static function void load_lane_replay(
    ref swb_case_plan plan,
    input int unsigned lane_id,
    input string replay_path
  );
    int fd;
    int rc;
    int idx;
    int unsigned frame_id;
    bit [36:0] packed_beat;
    swb_ingress_beat_t beat;
    swb_ingress_beat_t beats[$];
  begin
    fd = $fopen(replay_path, "r");
    if (fd == 0) begin
      `uvm_fatal("REPLAY", $sformatf("Unable to open replay file %s", replay_path))
    end

    while (!$feof(fd)) begin
      rc = $fscanf(fd, "%h\n", packed_beat);
      if (rc == 1) begin
        beat.valid = packed_beat[36];
        beat.datak = packed_beat[35:32];
        beat.data  = packed_beat[31:0];
        if (beat.valid) begin
          beats.push_back(beat);
        end
      end
    end
    void'($fclose(fd));

    idx = 0;
    frame_id = 0;
    while (idx < beats.size()) begin
      swb_frame_item frame;

      beat = beats[idx];
      if (!(beat.datak == 4'b0001 && beat.data[7:0] == SWB_K285 && beat.data[31:26] == SWB_MUPIX_HEADER_ID)) begin
        `uvm_fatal(
          "REPLAY",
          $sformatf("Lane %0d replay is missing SOP at beat %0d, got data=%08h datak=%1h", lane_id, idx, beat.data, beat.datak)
        )
      end
      if ((idx + 4) >= beats.size()) begin
        `uvm_fatal("REPLAY", $sformatf("Lane %0d replay truncated in fixed frame header", lane_id))
      end

      frame = swb_frame_item::type_id::create($sformatf("replay_frame_l%0d_f%0d", lane_id, frame_id));
      frame.lane_id      = lane_id;
      frame.frame_id     = frame_id;
      frame.feb_id       = beat.data[23:8];
      frame.ts_high_word = beats[idx + 1].data;
      frame.ts_low_word  = beats[idx + 2].data[31:16];
      frame.pkg_cnt      = beats[idx + 2].data[15:0];
      idx += 5;

      while (idx < beats.size()) begin
        swb_subheader_desc shd;
        int unsigned hit_count;

        beat = beats[idx];
        if (beat.datak == 4'b0001 && beat.data[7:0] == SWB_K284) begin
          idx++;
          break;
        end

        if (!(beat.datak == 4'b0001 && beat.data[7:0] == SWB_K237)) begin
          `uvm_fatal(
            "REPLAY",
            $sformatf(
              "Lane %0d replay expected subheader or EOP at beat %0d, got data=%08h datak=%1h",
              lane_id,
              idx,
              beat.data,
              beat.datak
            )
          )
        end

        shd = swb_subheader_desc::type_id::create($sformatf("replay_shd_l%0d_f%0d_s%0d", lane_id, frame_id, frame.subheaders.size()));
        shd.shd_ts = beat.data[31:24];
        hit_count = beat.data[15:8];
        idx++;

        repeat (hit_count) begin
          swb_hit_desc hit;
          if (idx >= beats.size()) begin
            `uvm_fatal("REPLAY", $sformatf("Lane %0d replay truncated inside hit payloads", lane_id))
          end
          beat = beats[idx];
          if (beat.datak != 4'b0000) begin
            `uvm_fatal(
              "REPLAY",
              $sformatf("Lane %0d replay expected hit payload at beat %0d, got data=%08h datak=%1h", lane_id, idx, beat.data, beat.datak)
            )
          end
          hit = swb_hit_desc::type_id::create($sformatf("replay_hit_l%0d_f%0d_s%0d_h%0d", lane_id, frame_id, frame.subheaders.size(), shd.hits.size()));
          hit.payload_word = beat.data;
          shd.hits.push_back(hit);
          idx++;
        end

        frame.subheaders.push_back(shd);
      end

      plan.frames_by_lane[lane_id].push_back(frame);
      frame_id++;
    end
  end
  endfunction

  static function void load_expected_dma_words(
    ref swb_case_plan plan,
    input string replay_path
  );
    int fd;
    int rc;
    bit [255:0] dma_word;
  begin
    fd = $fopen(replay_path, "r");
    if (fd == 0) begin
      `uvm_fatal("REPLAY", $sformatf("Unable to open expected DMA file %s", replay_path))
    end

    plan.expected_dma_words.delete();
    while (!$feof(fd)) begin
      rc = $fscanf(fd, "%h\n", dma_word);
      if (rc == 1) begin
        plan.expected_dma_words.push_back(dma_word);
      end
    end
    void'($fclose(fd));

    plan.expected_word_count = plan.expected_dma_words.size();
  end
  endfunction

  static function void load_replay_case(
    ref swb_case_plan plan,
    input string replay_dir
  );
  begin
    if (plan == null) begin
      plan = swb_case_plan::type_id::create("case_plan");
    end
    plan.clear();

    for (int unsigned lane_id = 0; lane_id < SWB_N_LANES; lane_id++) begin
      swb_case_builder::load_lane_replay(
        plan,
        lane_id,
        $sformatf("%s/lane%0d_ingress.mem", replay_dir, lane_id)
      );
    end

    swb_case_builder::load_expected_dma_words(
      plan,
      $sformatf("%s/expected_dma_words.mem", replay_dir)
    );
    plan.total_hits = swb_case_builder::count_total_hits(plan);
  end
  endfunction

  static function void build_basic_case(
    ref swb_case_plan plan,
    int unsigned frame_count,
    real lane_saturation[SWB_N_LANES]
  );
    int unsigned frame_idx;
    int unsigned lane_id;
    int unsigned shd_idx;
    int unsigned hit_target;
    int unsigned extra_hits;
  begin
    if (plan == null) begin
      plan = swb_case_plan::type_id::create("case_plan");
    end
    plan.clear();

    foreach (lane_saturation[lane_id]) begin
      plan.lane_saturation[lane_id] = lane_saturation[lane_id];
    end

    for (frame_idx = 0; frame_idx < frame_count; frame_idx++) begin
      bit [31:0] ts_high_word;
      bit [15:0] ts_low_word;

      ts_high_word = 32'h1200_0000 + frame_idx;
      ts_low_word  = 16'hA000 + (frame_idx * 16);

      for (lane_id = 0; lane_id < SWB_N_LANES; lane_id++) begin
        swb_frame_item frame;
        frame = swb_frame_item::type_id::create($sformatf("frame_l%0d_f%0d", lane_id, frame_idx));
        frame.lane_id      = lane_id;
        frame.frame_id     = frame_idx;
        frame.ts_high_word = ts_high_word;
        frame.ts_low_word  = ts_low_word;
        frame.pkg_cnt      = frame_idx[15:0];
        frame.feb_id       = lane_id[15:0];

        for (shd_idx = 0; shd_idx < SWB_N_SUBHEADERS; shd_idx++) begin
          swb_subheader_desc shd;
          shd = swb_subheader_desc::type_id::create($sformatf("shd_l%0d_f%0d_s%0d", lane_id, frame_idx, shd_idx));
          shd.shd_ts = shd_idx[7:0];
          hit_target = swb_poisson_trunc(lane_saturation[lane_id] * SWB_MAX_HITS_PER_SUBHEADER, SWB_MAX_HITS_PER_SUBHEADER);
          repeat (hit_target) begin
            swb_case_builder::add_hit_to_subheader(frame, shd, lane_id, frame_idx, shd_idx);
          end
          frame.subheaders.push_back(shd);
        end

        plan.frames_by_lane[lane_id].push_back(frame);
      end
    end

    plan.total_hits = swb_case_builder::count_total_hits(plan);
    extra_hits = (4 - (plan.total_hits % 4)) % 4;
    if (extra_hits != 0) begin
      for (lane_id = SWB_N_LANES - 1; lane_id >= 0; lane_id--) begin
        int frame_scan;
        for (frame_scan = plan.frames_by_lane[lane_id].size() - 1; frame_scan >= 0; frame_scan--) begin
          int shd_scan;
          swb_frame_item frame;
          frame = plan.frames_by_lane[lane_id][frame_scan];
          for (shd_scan = frame.subheaders.size() - 1; shd_scan >= 0; shd_scan--) begin
            swb_subheader_desc shd;
            shd = frame.subheaders[shd_scan];
            while ((extra_hits != 0) && (shd.hit_count() < SWB_MAX_HITS_PER_SUBHEADER)) begin
              swb_case_builder::add_hit_to_subheader(frame, shd, lane_id, frame.frame_id, shd_scan);
              extra_hits--;
            end
          end
        end
      end

      if (extra_hits != 0) begin
        `uvm_fatal("CASE", "Unable to pad final hit count to a multiple of four")
      end
    end

    swb_case_builder::pack_expected_words(plan);
  end
  endfunction
endclass
