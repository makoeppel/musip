`timescale 1ns/1ps

import uvm_pkg::*;
import swb_uvm_pkg::*;

module tb_top;
  logic clk;

  feb_ingress_if feb_if0(clk);
  feb_ingress_if feb_if1(clk);
  feb_ingress_if feb_if2(clk);
  feb_ingress_if feb_if3(clk);
  dma_sink_if    dma_if(clk);
  opq_egress_if  opq_if(clk);
  swb_ctrl_if    ctrl_if(clk);

  always #2ns clk = ~clk;

  swb_block_uvm_wrapper dut (
    .clk             (clk),
    .reset_n         (ctrl_if.reset_n),
    .feb_data        ({
      feb_if3.data,
      feb_if2.data,
      feb_if1.data,
      feb_if0.data
    }),
    .feb_datak       ({
      feb_if3.datak,
      feb_if2.datak,
      feb_if1.datak,
      feb_if0.datak
    }),
    .feb_valid       ({
      feb_if3.valid,
      feb_if2.valid,
      feb_if1.valid,
      feb_if0.valid
    }),
    .feb_enable_mask (ctrl_if.feb_enable_mask),
    .use_merge       (ctrl_if.use_merge),
    .enable_dma      (ctrl_if.enable_dma),
    .get_n_words     (ctrl_if.get_n_words),
    .lookup_ctrl     (ctrl_if.lookup_ctrl),
    .dma_half_full   (ctrl_if.dma_half_full),
    .opq_data        (opq_if.data),
    .opq_datak       (opq_if.datak),
    .opq_valid       (opq_if.valid),
    .dma_data        (dma_if.data),
    .dma_wren        (dma_if.wren),
    .end_of_event    (dma_if.end_of_event),
    .dma_done        (ctrl_if.dma_done)
  );

  initial begin
    clk = 1'b0;
    ctrl_if.reset_n         = 1'b0;
    ctrl_if.feb_enable_mask = 4'hf;
    ctrl_if.use_merge       = 1'b1;
    ctrl_if.enable_dma      = 1'b0;
    ctrl_if.get_n_words     = '0;
    ctrl_if.lookup_ctrl     = '0;
    ctrl_if.dma_half_full   = 1'b0;
    feb_if0.valid = 1'b0;
    feb_if0.data  = '0;
    feb_if0.datak = '0;
    feb_if1.valid = 1'b0;
    feb_if1.data  = '0;
    feb_if1.datak = '0;
    feb_if2.valid = 1'b0;
    feb_if2.data  = '0;
    feb_if2.datak = '0;
    feb_if3.valid = 1'b0;
    feb_if3.data  = '0;
    feb_if3.datak = '0;

    repeat (16) @(posedge clk);
    ctrl_if.reset_n = 1'b1;
  end

  initial begin
    uvm_config_db#(virtual swb_ctrl_if)::set(null, "uvm_test_top", "ctrl_vif", ctrl_if);
    uvm_config_db#(virtual feb_ingress_if)::set(null, "uvm_test_top.env.ingress_agent_0*", "vif", feb_if0);
    uvm_config_db#(virtual feb_ingress_if)::set(null, "uvm_test_top.env.ingress_agent_1*", "vif", feb_if1);
    uvm_config_db#(virtual feb_ingress_if)::set(null, "uvm_test_top.env.ingress_agent_2*", "vif", feb_if2);
    uvm_config_db#(virtual feb_ingress_if)::set(null, "uvm_test_top.env.ingress_agent_3*", "vif", feb_if3);
    uvm_config_db#(virtual opq_egress_if)::set(null, "uvm_test_top.env.opq_monitor*", "vif", opq_if);
    uvm_config_db#(virtual dma_sink_if)::set(null, "uvm_test_top.env.dma_monitor*", "vif", dma_if);
    run_test("swb_basic_test");
  end
endmodule
