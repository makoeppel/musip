`uvm_analysis_imp_decl(_dma)

class swb_scoreboard extends uvm_component;
  uvm_analysis_imp_dma #(swb_dma_word, swb_scoreboard) dma_imp;
  swb_case_plan plan;
  int unsigned recv_words;
  int unsigned padding_words;
  bit          saw_end_of_event;

  `uvm_component_utils(swb_scoreboard)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    dma_imp = new("dma_imp", this);
    recv_words       = 0;
    padding_words    = 0;
    saw_end_of_event = 1'b0;
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(swb_case_plan)::get(this, "", "case_plan", plan)) begin
      `uvm_fatal("NOPLAN", "swb_case_plan missing from config_db")
    end
  endfunction

  function void write_dma(swb_dma_word item);
    bit [255:0] expected_word;
    bit [255:0] actual_word;
  begin
    actual_word = swb_normalize_dma_word(item.data);
    if (recv_words < plan.expected_dma_words.size()) begin
      expected_word = swb_normalize_dma_word(plan.expected_dma_words[recv_words]);
      if (actual_word !== expected_word) begin
        `uvm_error(
          "DMA_MISMATCH",
          $sformatf(
            "word[%0d] expected=%064h actual=%064h",
            recv_words,
            expected_word,
            actual_word
          )
        )
      end
      recv_words++;
    end else begin
      padding_words++;
    end

    if (item.end_of_event) begin
      saw_end_of_event = 1'b1;
    end
  end
  endfunction

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (recv_words != plan.expected_dma_words.size()) begin
      `uvm_error(
        "DMA_SHORT",
        $sformatf("Expected %0d payload words but observed %0d", plan.expected_dma_words.size(), recv_words)
      )
    end
    if (!saw_end_of_event) begin
      `uvm_error("DMA_EOE", "No end-of-event marker observed on DMA output")
    end
    `uvm_info(
      "DMA_SUMMARY",
      $sformatf(
        "Compared %0d payload words and ignored %0d trailing padding words",
        recv_words,
        padding_words
      ),
      UVM_LOW
    )
  endfunction
endclass
