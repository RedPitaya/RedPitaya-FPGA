////////////////////////////////////////////////////////////////////////////////
// Focused test for the system-bus clock-domain crossing.
////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module sys_bus_cdc_tb;

logic clk_s = 1'b0;
logic clk_m = 1'b0;
logic rstn_s = 1'b0;
logic rstn_m = 1'b0;
logic pll_locked = 1'b0;

always #3.5 clk_s = ~clk_s;  // unrelated 142.857 MHz controller clock
always #5.5 clk_m = ~clk_m;  // unrelated 90.909 MHz register clock

sys_bus_if bus_s (.clk(clk_s), .rstn(rstn_s));
sys_bus_if bus_m (.clk(clk_m), .rstn(rstn_m));

sys_bus_cdc dut (
  .pll_locked_i(pll_locked),
  .bus_s(bus_s),
  .bus_m(bus_m)
);

logic [31:0] memory [0:255];
logic        slave_pending;
logic        slave_wait_release;
logic        slave_write;
logic [7:0]  slave_addr;
logic [31:0] slave_wdata;
integer      slave_delay;
integer      errors = 0;
integer      transactions = 0;
integer      i;

// Slave with randomized response latency.  rdata is deliberately disturbed
// whenever no response is active, proving that the CDC returns the value
// captured with ACK rather than a later asynchronous bus value.
always @(posedge clk_m) begin
  if (!rstn_m) begin
    bus_m.ack         <= 1'b0;
    bus_m.err         <= 1'b0;
    bus_m.rdata       <= 32'h0;
    slave_pending     <= 1'b0;
    slave_wait_release <= 1'b0;
    slave_write       <= 1'b0;
    slave_addr        <= 8'h0;
    slave_wdata       <= 32'h0;
    slave_delay       <= 0;
  end else begin
    bus_m.ack <= 1'b0;
    bus_m.err <= 1'b0;

    if (!slave_pending)
      bus_m.rdata <= $urandom;

    if (slave_wait_release && !(bus_m.wen || bus_m.ren))
      slave_wait_release <= 1'b0;

    if (!slave_pending && !slave_wait_release && (bus_m.wen || bus_m.ren)) begin
      slave_pending <= 1'b1;
      slave_write   <= bus_m.wen;
      slave_addr    <= bus_m.addr[9:2];
      slave_wdata   <= bus_m.wdata;
      slave_delay   <= $urandom_range(0, 9);
    end else if (slave_pending) begin
      if (slave_delay == 0) begin
        if (slave_write)
          memory[slave_addr] <= slave_wdata;
        else
          bus_m.rdata <= memory[slave_addr];
        bus_m.ack          <= 1'b1;
        slave_pending      <= 1'b0;
        slave_wait_release <= 1'b1;
      end else begin
        slave_delay <= slave_delay - 1;
      end
    end
  end
end

task automatic reset_both;
begin
  rstn_s <= 1'b0;
  rstn_m <= 1'b0;
  pll_locked <= 1'b0;
  bus_s.wen <= 1'b0;
  bus_s.ren <= 1'b0;
  repeat (4) @(posedge clk_s);
  rstn_s <= 1'b1;
  repeat (2) @(posedge clk_m);
  rstn_m <= 1'b1;
  repeat (3) @(posedge clk_s);
  pll_locked <= 1'b1;
end
endtask

task automatic transact(
  input bit write,
  input logic [7:0] word_addr,
  input logic [31:0] wdata,
  output logic [31:0] rdata
);
  integer timeout;
begin
  @(negedge clk_s);
  bus_s.addr  <= {22'h0, word_addr, 2'b0};
  bus_s.wdata <= wdata;
  bus_s.wen   <= write;
  bus_s.ren   <= !write;
  @(negedge clk_s);
  bus_s.wen <= 1'b0;
  bus_s.ren <= 1'b0;

  timeout = 0;
  while (!bus_s.ack && !bus_s.err && timeout < 200) begin
    @(posedge clk_s);
    #1ps;
    timeout++;
  end

  if (timeout == 200) begin
    $display("ERROR: transaction timeout write=%0d addr=%0h", write, word_addr);
    errors++;
  end else if (bus_s.err) begin
    $display("ERROR: unexpected bus error");
    errors++;
  end

  rdata = bus_s.rdata;
  transactions++;
  @(posedge clk_s);
end
endtask

task automatic run_random(input integer count);
  logic [7:0] addr;
  logic [31:0] data;
  logic [31:0] got;
  bit write;
  integer n;
begin
  for (n = 0; n < count; n++) begin
    addr = $urandom_range(0, 255);
    write = ($urandom_range(0, 99) < 45);
    data = $urandom;
    transact(write, addr, data, got);
    if (write) begin
      // The slave updates memory on its ACK edge.
      if (memory[addr] !== data) begin
        $display("ERROR: write mismatch addr=%0h exp=%0h got=%0h",
                 addr, data, memory[addr]);
        errors++;
      end
    end else if (got !== memory[addr]) begin
      $display("ERROR: read mismatch addr=%0h exp=%0h got=%0h",
               addr, memory[addr], got);
      errors++;
    end
  end
end
endtask

task automatic reset_inflight;
  integer timeout;
begin
  // Start a read, wait until it has crossed into the slave domain, then reset
  // both sides before the randomized slave latency can complete it.
  @(negedge clk_s);
  bus_s.addr <= 32'h00000140;
  bus_s.ren  <= 1'b1;
  @(negedge clk_s);
  bus_s.ren <= 1'b0;

  timeout = 0;
  while (!slave_pending && timeout < 100) begin
    @(posedge clk_m);
    timeout++;
  end
  if (timeout == 100) begin
    $display("ERROR: in-flight reset did not reach slave");
    errors++;
  end

  reset_both();
  repeat (3) begin
    @(posedge clk_s);
    #1ps;
    if (bus_s.ack || bus_s.err) begin
      $display("ERROR: stale completion after reset ack=%0b err=%0b",
               bus_s.ack, bus_s.err);
      errors++;
    end
  end
end
endtask

initial begin
  bus_s.addr  = 32'h0;
  bus_s.wdata = 32'h0;
  bus_s.wen   = 1'b0;
  bus_s.ren   = 1'b0;
  bus_m.ack   = 1'b0;
  bus_m.err   = 1'b0;
  bus_m.rdata = 32'h0;
  for (i = 0; i < 256; i++)
    memory[i] = 32'h5a000000 ^ i;

  reset_both();
  run_random(250);

  reset_inflight();
  run_random(50);

  // Reset while idle, then repeat with the clocks at an arbitrary phase.
  repeat ($urandom_range(1, 7)) @(posedge clk_m);
  reset_both();
  run_random(100);

  // Existing unlocked behavior must remain immediate and deterministic.
  pll_locked <= 1'b0;
  @(negedge clk_s);
  bus_s.ren <= 1'b1;
  @(posedge clk_s);
  #1ps;
  if (!bus_s.ack || !bus_s.err || bus_s.rdata !== 32'hDEADBEEF) begin
    $display("ERROR: unlocked response ack=%0b err=%0b rdata=%0h",
             bus_s.ack, bus_s.err, bus_s.rdata);
    errors++;
  end
  @(negedge clk_s);
  bus_s.ren <= 1'b0;

  if (errors == 0)
    $display("SUCCESS: sys_bus_cdc_tb transactions=%0d", transactions);
  else
    $display("FAILURE: sys_bus_cdc_tb errors=%0d transactions=%0d",
             errors, transactions);
  $finish;
end

initial begin
  #2ms;
  $display("FAILURE: sys_bus_cdc_tb global timeout");
  $finish;
end

endmodule: sys_bus_cdc_tb
