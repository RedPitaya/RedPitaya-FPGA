////////////////////////////////////////////////////////////////////////////////
// Z20_250 external trigger conditioner and CS2 register slave.
////////////////////////////////////////////////////////////////////////////////

module ext_trig_cond_250 (
  input  logic      clk,
  input  logic      rstn,
  input  logic      trig_i,
  output logic      trig_o,
  input  logic [31:0] sys_addr,
  input  logic [31:0] sys_wdata,
  input  logic        sys_wen,
  input  logic        sys_ren,
  output logic [31:0] sys_rdata,
  output logic        sys_err,
  output logic        sys_ack
);

logic       condition_enable;
logic       edge_select;
logic       debounce_enable;
logic [7:0] debounce_len;
logic       trig_level;
logic       trig_rise;
logic       trig_fall;

debounce #(
  .CW (8),
  .DI (1'b0)
) i_debounce (
  .clk  (clk),
  .rstn (rstn),
  .ena  (condition_enable && debounce_enable),
  .len  (debounce_len),
  .d_i  (trig_i),
  .d_o  (trig_level),
  .d_p  (trig_rise),
  .d_n  (trig_fall)
);

always_ff @(posedge clk) begin
  if (!rstn) begin
    condition_enable <= 1'b0;
    edge_select      <= 1'b0;
    debounce_enable  <= 1'b0;
    debounce_len     <= 8'h00;
  end else if (sys_wen && (sys_addr[19:0] == 20'h00068)) begin
    condition_enable <= sys_wdata[0];
    edge_select      <= sys_wdata[1];
    debounce_enable  <= sys_wdata[2];
    debounce_len     <= sys_wdata[15:8];
  end
end

always_comb begin
  sys_rdata = 32'h00000000;
  if (sys_addr[19:0] == 20'h00068)
    sys_rdata = {16'h0000, debounce_len, 5'h00,
                 debounce_enable, edge_select, condition_enable};
  sys_ack = sys_wen | sys_ren;
  sys_err = 1'b0;
end

always_comb begin
  if (condition_enable)
    trig_o = edge_select ? trig_fall : trig_rise;
  else
    trig_o = trig_level;
end

endmodule: ext_trig_cond_250
