////////////////////////////////////////////////////////////////////////////////
// Module: System bus interconnect
// Author: Iztok Jeras <iztok.jeras@redpitaya.com>
// (c) Red Pitaya  (redpitaya.com)
////////////////////////////////////////////////////////////////////////////////

module sys_bus_interconnect #(
  int unsigned SN = 16, // slave number
  int unsigned SW = 20, // slave width (address bus width)
  SYNC_IN_BUS     = -1, // master bus for synchronised writes
  SYNC_OUT_BUS1   = -1, // slave bus 1
  SYNC_OUT_BUS2   = -1, // slave bus 2
  SYNC_OUT_BUS3   = -1, // slave bus 3
  SYNC_OUT_BUS4   = -1, // slave bus 4
  SYNC_REG_OFS1   = -1, // synchronised reg 1
  SYNC_REG_OFS2   = -1, // synchronised reg 2
  SYNC_REG_OFS3   = -1, // synchronised reg 3
  SYNC_REG_OFS4   = -1  // synchronised reg 4
)(
  sys_bus_if.s bus_m,          // from master
  sys_bus_if.m bus_s [SN-1:0]  // to   slaves
);

// slave number logarithm
localparam int unsigned SL = $clog2(SN);

logic [SN-1:0]         syncd_cs;
logic [SL-1:0]         bus_s_a    ;
logic [SN-1:0]         bus_s_cs   ;
logic [SN-1:0][32-1:0] bus_s_rdata;
logic [SN-1:0]         bus_s_err  ;
logic [SN-1:0]         bus_s_ack  ;
logic [SN-1:0]         bus_s_sync_cs;
logic [SN-1:0]         bus_s_sync_adr;


assign bus_s_a  = bus_m.addr[SW+:SL];
assign bus_s_cs = SN'(1) << bus_s_a;

assign bus_s_sync_cs = {SN{bus_s_cs[SYNC_IN_BUS]}} & {syncd_cs};
assign bus_s_sync_adr = bus_s_sync_cs & {SN{((bus_m.addr[SW-1:0] == SYNC_REG_OFS1) || (bus_m.addr[SW-1:0] == SYNC_REG_OFS2) || (bus_m.addr[SW-1:0] == SYNC_REG_OFS3) || (bus_m.addr[SW-1:0] == SYNC_REG_OFS4))}};

generate
for (genvar i=0; i<SN; i++) begin: for_bus
assign syncd_cs[i]    =  (i == SYNC_OUT_BUS1) || (i == SYNC_OUT_BUS2) || (i == SYNC_OUT_BUS3) || (i == SYNC_OUT_BUS4);

assign bus_s[i].addr  =                bus_m.addr ;
assign bus_s[i].wdata =                bus_m.wdata;
assign bus_s[i].wen   = (bus_s_cs[i] | bus_s_sync_adr[i]) & bus_m.wen;
assign bus_s[i].ren   =  bus_s_cs[i] & bus_m.ren;

assign bus_s_rdata[i] = bus_s[i].rdata;
assign bus_s_err  [i] = bus_s[i].err  ;
assign bus_s_ack  [i] = bus_s[i].ack  ;

end: for_bus
endgenerate

assign bus_m.rdata = bus_s_rdata[bus_s_a];
assign bus_m.err   = bus_s_err  [bus_s_a];
assign bus_m.ack   = bus_s_ack  [bus_s_a];

endmodule: sys_bus_interconnect
