// Register path of rp_gpio: the bridge runs on the 50 MHz register clock, the registers on
// the 125 MHz ADC clock. Every write of the event register (0x88) must give one event pulse
// with the written value, in order; back-to-back writes (one per register clock) must all
// arrive. reg_ctrl (axi_bram_ctrl IP) is replaced by a model of its BRAM port.
`timescale 1ns / 1ps

module reg_ctrl (
  input s_axi_aclk, input s_axi_aresetn,
  input [31:0] s_axi_awaddr, input [2:0] s_axi_awprot, input s_axi_awvalid, output s_axi_awready,
  input [31:0] s_axi_wdata, input [3:0] s_axi_wstrb, input s_axi_wvalid, output s_axi_wready,
  output [1:0] s_axi_bresp, output s_axi_bvalid, input s_axi_bready,
  input [31:0] s_axi_araddr, input [2:0] s_axi_arprot, input s_axi_arvalid, output s_axi_arready,
  output [31:0] s_axi_rdata, output [1:0] s_axi_rresp, output s_axi_rvalid, input s_axi_rready,
  output bram_rst_a, output bram_clk_a, output reg bram_en_a = 0, output reg [3:0] bram_we_a = 0,
  output reg [31:0] bram_addr_a = 0, output reg [31:0] bram_wrdata_a = 0, input [31:0] bram_rddata_a);
  assign bram_clk_a = s_axi_aclk;
  assign bram_rst_a = ~s_axi_aresetn;
  task automatic write(input [31:0] a, input [31:0] d);
    @(posedge s_axi_aclk) #1 begin bram_en_a = 1; bram_we_a = 4'hF; bram_addr_a = a; bram_wrdata_a = d; end
    @(posedge s_axi_aclk) #1 begin bram_en_a = 0; bram_we_a = 0; end
  endtask
  task automatic read(input [31:0] a, output [31:0] d);
    @(posedge s_axi_aclk) #1 begin bram_en_a = 1; bram_we_a = 0; bram_addr_a = a; end
    @(posedge s_axi_aclk) #1 bram_en_a = 0;
    @(posedge s_axi_aclk) d = bram_rddata_a;  // read latency 1, sampled a clock later
  endtask
endmodule

module rp_gpio_regs_tb;
logic clk = 0, rclk = 0, rstn = 0;
always #4 clk = ~clk;      // 125 MHz
always #10.3 rclk = ~rclk; // ~48.5 MHz, drifting against the ADC clock
wire [3:0] ev;
int errors = 0;

rp_gpio dut (
  .clk(clk), .rst_n(rstn), .intr(),
  .event_ip_trig(5'd0), .event_ip_stop(5'd0), .event_ip_start(5'd0), .event_ip_reset(5'd0),
  .trig_ip(6'd0), .ext_trig_i(1'b0), .la_event_op(ev), .la_trig_op(), .gpio_trig_o(),
  .s_axi_reg_aclk(rclk), .s_axi_reg_aresetn(rstn),
  .m_axi_gpio_out_aclk(clk), .m_axi_gpio_out_aresetn(rstn), .m_axi_gpio_arready(1'b1), .m_axi_gpio_rvalid(1'b0),
  .m_axi_gpio_rdata(64'd0), .m_axi_gpio_rlast(1'b0), .m_axi_gpio_rid(4'd0), .m_axi_gpio_rresp(2'd0),
  .m_axi_gpio_in_aclk(clk), .m_axi_gpio_in_aresetn(rstn), .m_axi_gpio_awready(1'b1), .m_axi_gpio_wready(1'b1),
  .m_axi_gpio_bvalid(1'b0), .m_axi_gpio_bresp(2'd0));

// event pulses seen on the ADC clock
logic [3:0] seen[$];
always @(posedge clk) if (ev != 0) seen.push_back(ev);

task automatic check(bit ok, string what);
  if (!ok) begin errors++; $display("FAIL  %s", what); end else $display("ok    %s", what);
endtask

initial begin
  logic [3:0] sent[$];
  logic [31:0] d;
  int bad = 0;
  repeat (20) @(posedge rclk);
  rstn = 1;
  repeat (20) @(posedge rclk);

  // events interleaved with DMA control writes, one write per register clock
  for (int i = 0; i < 200; i++) begin
    logic [3:0] e = 4'b1 << (i % 4);
    dut.U_reg_ctrl.write(32'h88, e);
    sent.push_back(e);
    dut.U_reg_ctrl.write(32'h8C, 32'h1 << (i % 5));
  end
  repeat (20) @(posedge clk);
  check(seen.size() == sent.size(), $sformatf("200 event writes: %0d event pulses", seen.size()));
  for (int i = 0; i < sent.size() && i < seen.size(); i++) if (seen[i] != sent[i]) bad++;
  check(bad == 0, $sformatf("every event pulse carries its own value (%0d wrong)", bad));

  // back-to-back configuration writes, read back
  bad = 0;
  for (int i = 0; i < 100; i++) begin
    dut.U_reg_ctrl.write(32'h40, i);
    dut.U_reg_ctrl.write(32'h44, i + 1);
    dut.U_reg_ctrl.write(32'h48, i + 2);
    dut.U_reg_ctrl.read(32'h40, d); if (d != i) bad++;
    dut.U_reg_ctrl.read(32'h44, d); if (d != i + 1) bad++;
    dut.U_reg_ctrl.read(32'h48, d); if (d != i + 2) bad++;
  end
  check(bad == 0, $sformatf("back-to-back writes read back (%0d wrong)", bad));
  dut.U_reg_ctrl.write(32'h0C, 32'h12345);
  dut.U_reg_ctrl.read(32'h0C, d);
  check(d == 32'h2345, $sformatf("0x0C keeps 16 bits (0x%0X)", d));
  dut.U_reg_ctrl.read(32'hDC, d);
  check(d == 32'h1F, $sformatf("0xDC features 0x%0X (1F: block mode, 64 bit lost, wait, output free flags, output wait counter)", d));
  dut.U_reg_ctrl.read(32'h38, d);
  check(d == 0, $sformatf("0x38 output wait 0x%0X after the reset (0)", d));
  dut.U_reg_ctrl.read(32'hF0, d);
  check(d == 0, $sformatf("0xF0 wait before input buffer 1 after reset (0x%0X)", d));

  if (errors == 0) $display("PASS rp_gpio_regs_tb"); else $display("FAIL rp_gpio_regs_tb: %0d", errors);
  $finish;
end
endmodule
