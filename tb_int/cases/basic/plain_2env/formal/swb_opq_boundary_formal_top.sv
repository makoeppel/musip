// -----------------------------------------------------------------------------
// File      : swb_opq_boundary_formal_top.sv
// Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
// Version   : 26.4.22
// Date      : 20260422
// Change    : Add an OSS-formal scaffold for the split OPQ seam packet
//             contract checker.
// -----------------------------------------------------------------------------

module swb_opq_boundary_formal_top;
  localparam logic [5:0] SWB_MUPIX_HEADER_ID_CONST = 6'b111010;
  localparam logic [7:0] SWB_K285_CONST            = 8'hBC;
  localparam logic [7:0] SWB_K284_CONST            = 8'h9C;
  localparam logic [7:0] SWB_K237_CONST            = 8'hF7;

  typedef enum logic [3:0] {
    GEN_RESET,
    GEN_IDLE,
    GEN_SOP,
    GEN_TS_HIGH,
    GEN_TS_LOW_PKG,
    GEN_DEBUG0,
    GEN_DEBUG1,
    GEN_ZERO_SUBHEADER,
    GEN_DATA_SUBHEADER,
    GEN_HITS,
    GEN_EOP,
    GEN_DONE
  } gen_phase_t;

  (* gclk *) reg clk;

  reg         started_q            = 1'b0;
  gen_phase_t phase_q              = GEN_RESET;
  reg [1:0]   zero_subheaders_left_q = '0;
  reg [2:0]   hits_left_q          = '0;

  (* anyconst *) logic [1:0] zero_subheaders_cfg;
  (* anyconst *) logic [1:0] hit_count_cfg;

  logic       reset_n;
  logic       valid;
  logic [3:0] datak;
  logic [31:0] data;

  always @* begin
    reset_n = started_q;
    valid   = 1'b0;
    datak   = 4'b0000;
    data    = 32'h0000_0000;

    unique case (phase_q)
      GEN_SOP: begin
        valid = 1'b1;
        datak = 4'b0001;
        data = {SWB_MUPIX_HEADER_ID_CONST, 2'b00, 16'h0000, SWB_K285_CONST};
      end

      GEN_TS_HIGH: begin
        valid = 1'b1;
        data = 32'h1200_0000;
      end

      GEN_TS_LOW_PKG: begin
        valid = 1'b1;
        data = 32'hA000_0000;
      end

      GEN_DEBUG0: begin
        valid = 1'b1;
        data = 32'h0001_0004;
      end

      GEN_DEBUG1: begin
        valid = 1'b1;
        data = 32'h0000_0000;
      end

      GEN_ZERO_SUBHEADER: begin
        valid = 1'b1;
        datak = 4'b0001;
        data = {8'h10, 8'h00, 8'h00, SWB_K237_CONST};
      end

      GEN_DATA_SUBHEADER: begin
        valid = 1'b1;
        datak = 4'b0001;
        data = {8'h12, 8'h00, {6'b0, (hit_count_cfg + 2'd1)}, SWB_K237_CONST};
      end

      GEN_HITS: begin
        valid = 1'b1;
        data = {4'h4, 6'h00, 8'h12, 8'h34, 5'h01, 1'b0};
      end

      GEN_EOP: begin
        valid = 1'b1;
        datak = 4'b0001;
        data = {24'h000000, SWB_K284_CONST};
      end

      default: begin
        valid = 1'b0;
        datak = 4'b0000;
        data = 32'h0000_0000;
      end
    endcase
  end

  always @* begin
    unique case (phase_q)
      GEN_RESET,
      GEN_IDLE,
      GEN_DONE: begin
        assert (!valid);
        assert (datak == 4'b0000);
      end

      GEN_SOP: begin
        assert (valid);
        assert (datak == 4'b0001);
        assert (data[7:0] == SWB_K285_CONST);
        assert (data[31:26] == SWB_MUPIX_HEADER_ID_CONST);
      end

      GEN_TS_HIGH,
      GEN_TS_LOW_PKG,
      GEN_DEBUG0,
      GEN_DEBUG1,
      GEN_HITS: begin
        assert (valid);
        assert (datak == 4'b0000);
      end

      GEN_ZERO_SUBHEADER,
      GEN_DATA_SUBHEADER: begin
        assert (valid);
        assert (datak == 4'b0001);
        assert (data[7:0] == SWB_K237_CONST);
      end

      GEN_EOP: begin
        assert (valid);
        assert (datak == 4'b0001);
        assert (data[7:0] == SWB_K284_CONST);
      end

      default: begin
        assert (!valid);
      end
    endcase
  end

  always @(posedge clk) begin
    if (!started_q) begin
      started_q <= 1'b1;
      phase_q <= GEN_IDLE;
      zero_subheaders_left_q <= zero_subheaders_cfg;
      hits_left_q <= {1'b0, hit_count_cfg} + 3'd1;
    end else begin
      unique case (phase_q)
        GEN_RESET: phase_q <= GEN_IDLE;
        GEN_IDLE: phase_q <= GEN_SOP;
        GEN_SOP: phase_q <= GEN_TS_HIGH;
        GEN_TS_HIGH: phase_q <= GEN_TS_LOW_PKG;
        GEN_TS_LOW_PKG: phase_q <= GEN_DEBUG0;
        GEN_DEBUG0: phase_q <= GEN_DEBUG1;
        GEN_DEBUG1: phase_q <= (zero_subheaders_left_q == 2'd0) ? GEN_DATA_SUBHEADER : GEN_ZERO_SUBHEADER;

        GEN_ZERO_SUBHEADER: begin
          if (zero_subheaders_left_q == 2'd1) begin
            zero_subheaders_left_q <= '0;
            phase_q <= GEN_DATA_SUBHEADER;
          end else begin
            zero_subheaders_left_q <= zero_subheaders_left_q - 2'd1;
          end
        end

        GEN_DATA_SUBHEADER: phase_q <= GEN_HITS;

        GEN_HITS: begin
          assert (hits_left_q != 3'd0);
          if (hits_left_q == 3'd1) begin
            hits_left_q <= '0;
            phase_q <= GEN_EOP;
          end else begin
            hits_left_q <= hits_left_q - 3'd1;
          end
        end

        GEN_EOP: phase_q <= GEN_DONE;
        GEN_DONE: phase_q <= GEN_DONE;
        default: phase_q <= GEN_DONE;
      endcase
    end
  end

  always @(posedge clk) begin
    cover(started_q && (phase_q == GEN_DONE));
  end
endmodule
