////////////////////////////////////////////////////////////////////////////////
// Module: System bus interconnect
// Author: Iztok Jeras <iztok.jeras@redpitaya.com>
// (c) Red Pitaya  (redpitaya.com)
////////////////////////////////////////////////////////////////////////////////
`define BUS_NAME_M bus_m
`define BUS_NAME_S bus_inter

module sys_bus_interconnect #(
  int unsigned SN = 16, // slave number
  int unsigned SW = 20, // slave width (address bus width)
  SYNC_IN_BUS     = -1, // master bus for synchronised writes
  SYNC_OUT_BUS1   = -1, // slave bus 1
  SYNC_OUT_BUS2   = -1, // slave bus 2
  SYNC_OUT_BUS3   = -1, // slave bus 3
  SYNC_OUT_BUS4   = -1, // slave bus 4
  SYNC_OUT_BUS5   = -1, // slave bus 5
  SYNC_OUT_BUS6   = -1, // slave bus 5
  SYNC_REG_OFS1   = -1, // synchronised reg 1
  SYNC_REG_OFS2   = -1, // synchronised reg 2
  SYNC_REG_OFS3   = -1, // synchronised reg 3
  SYNC_REG_OFS4   = -1, // synchronised reg 4
  SYNC_REG_OFS5   = -1, // synchronised reg 5
  SYNC_REG_OFS6   = -1  // synchronised reg 6
)(
  input        pll_locked_i,
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

sys_bus_if             bus_inter[SN-1:0](.clk (bus_m.clk), .rstn (bus_m.rstn)); //@FCLK0

initial begin
  bus_s_a  = {SL{1'b0}};
  bus_s_cs = {SN{1'b0}};
end

assign bus_s_a  = `BUS_NAME_M.addr[SW+:SL];
assign bus_s_cs = SN'(1) << bus_s_a;

assign bus_s_sync_cs = {SN{bus_s_cs[SYNC_IN_BUS]}} & {syncd_cs};
assign bus_s_sync_adr = bus_s_sync_cs & 
                        ({SN{((`BUS_NAME_M.addr[SW-1:0] == SYNC_REG_OFS1) || 
                              (`BUS_NAME_M.addr[SW-1:0] == SYNC_REG_OFS2) || 
                              (`BUS_NAME_M.addr[SW-1:0] == SYNC_REG_OFS3) || 
                              (`BUS_NAME_M.addr[SW-1:0] == SYNC_REG_OFS4) ||
                              (`BUS_NAME_M.addr[SW-1:0] == SYNC_REG_OFS5) ||
                              (`BUS_NAME_M.addr[SW-1:0] == SYNC_REG_OFS6))}});

generate
for (genvar i=0; i<SN; i++) begin: for_bus

assign syncd_cs[i]    =  (i == SYNC_OUT_BUS1) || 
                         (i == SYNC_OUT_BUS2) || 
                         (i == SYNC_OUT_BUS3) || 
                         (i == SYNC_OUT_BUS4) ||
                         (i == SYNC_OUT_BUS5) ||
                         (i == SYNC_OUT_BUS6);

assign `BUS_NAME_S[i].addr  =                `BUS_NAME_M.addr ;
assign `BUS_NAME_S[i].wdata =                `BUS_NAME_M.wdata;
assign `BUS_NAME_S[i].wen   = (bus_s_cs[i] | bus_s_sync_adr[i]) & `BUS_NAME_M.wen;
assign `BUS_NAME_S[i].ren   =  bus_s_cs[i] & `BUS_NAME_M.ren;

assign bus_s_rdata[i] = `BUS_NAME_S[i].rdata;
assign bus_s_err  [i] = `BUS_NAME_S[i].err  ;
assign bus_s_ack  [i] = `BUS_NAME_S[i].ack  ;


//enables different config clock for each module if needed
sys_bus_cdc inst_sys_bus_cdc
(
  .pll_locked_i(pll_locked_i),
  .bus_m(bus_s[i]),
  .bus_s(bus_inter[i])
);

end: for_bus


endgenerate

assign `BUS_NAME_M.rdata = bus_s_rdata[bus_s_a];
assign `BUS_NAME_M.err   = bus_s_err  [bus_s_a];
assign `BUS_NAME_M.ack   = bus_s_ack  [bus_s_a];


endmodule: sys_bus_interconnect
