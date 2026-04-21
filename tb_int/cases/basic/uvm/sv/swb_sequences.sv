class swb_frame_sequence extends uvm_sequence #(swb_frame_item);
  swb_frame_item frames[$];

  `uvm_object_utils(swb_frame_sequence)

  function new(string name = "swb_frame_sequence");
    super.new(name);
  endfunction

  virtual task body();
    foreach (frames[idx]) begin
      swb_frame_item req;
      req = frames[idx].copy_item();
      start_item(req);
      finish_item(req);
    end
  endtask
endclass
