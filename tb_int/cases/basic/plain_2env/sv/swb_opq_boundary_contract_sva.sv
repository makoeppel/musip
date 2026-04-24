// -----------------------------------------------------------------------------
// File      : swb_opq_boundary_contract_sva.sv
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Version   : 26.4.22
// Date      : 20260422
// Change    : Add a packet-contract checker for the split OPQ seam so the
//             same contract can be used in simulation and formal scaffolding.
// -----------------------------------------------------------------------------

module swb_opq_boundary_contract_sva #(
  parameter int STREAM_ID = 0
) (
  input logic        clk,
  input logic        reset_n,
  input logic        valid,
  input logic [3:0]  datak,
  input logic [31:0] data
);
  localparam logic [5:0] SWB_MUPIX_HEADER_ID_CONST = 6'b111010;
  localparam logic [7:0] SWB_K285_CONST = 8'hBC;
  localparam logic [7:0] SWB_K284_CONST = 8'h9C;
  localparam logic [7:0] SWB_K237_CONST = 8'hF7;
  localparam int HEADER_TS_MASK_BITS = 11;

  typedef enum logic [2:0] {
    IDLING,
    TS_HIGH,
    TS_LOW_PKG,
    DEBUG0,
    DEBUG1,
    SUBHEADER_OR_EOP,
    HITS
  } beat_phase_t;

  beat_phase_t phase_q;
  logic [7:0]  payloads_left_q;

  always_ff @(posedge clk or negedge reset_n) begin : pkt_contract
    if (!reset_n) begin
      phase_q <= IDLING;
      payloads_left_q <= '0;
    end else if (!valid) begin
      assert (phase_q == IDLING);
    end else begin
      unique case (phase_q)
        IDLING: begin
          assert (
            (datak == 4'b0001) &&
            (data[7:0] == SWB_K285_CONST) &&
            (data[31:26] == SWB_MUPIX_HEADER_ID_CONST)
          );
          phase_q <= TS_HIGH;
        end

        TS_HIGH: begin
          assert (datak == 4'b0000);
          phase_q <= TS_LOW_PKG;
        end

        TS_LOW_PKG: begin
          assert ((datak == 4'b0000) && (data[16 + HEADER_TS_MASK_BITS - 1:16] == '0));
          phase_q <= DEBUG0;
        end

        DEBUG0: begin
          assert (datak == 4'b0000);
          phase_q <= DEBUG1;
        end

        DEBUG1: begin
          assert ((datak == 4'b0000) && (data[31] == 1'b0));
          phase_q <= SUBHEADER_OR_EOP;
        end

        SUBHEADER_OR_EOP: begin
          if ((datak == 4'b0001) && (data[7:0] == SWB_K284_CONST)) begin
            phase_q <= IDLING;
          end else begin
            assert ((datak == 4'b0001) && (data[7:0] == SWB_K237_CONST));
            payloads_left_q <= data[15:8];
            phase_q <= (data[15:8] == 8'd0) ? SUBHEADER_OR_EOP : HITS;
          end
        end

        HITS: begin
          assert (datak == 4'b0000);
          assert (payloads_left_q != 8'd0);

          if (payloads_left_q == 8'd1) begin
            payloads_left_q <= '0;
            phase_q <= SUBHEADER_OR_EOP;
          end else begin
            payloads_left_q <= payloads_left_q - 8'd1;
          end
        end

        default: begin
          phase_q <= IDLING;
          payloads_left_q <= '0;
        end
      endcase
    end
  end
endmodule
