////////////////////////////////////////////////////////////////////////////////
// Module: System bus interconnect
// Author: Iztok Jeras <iztok.jeras@redpitaya.com>
// (c) Red Pitaya  (redpitaya.com)
////////////////////////////////////////////////////////////////////////////////
//`define BUS_NAME_M bus_m
//`define BUS_NAME_S bus_inter

`define BUS_NAME_M bus_m
`define BUS_NAME_I1 bus_int_i
`define BUS_NAME_I2 bus_int_o
`define BUS_NAME_S  bus_s

module sys_bus_interconnect #(
  int unsigned SN = 16, // slave number
  int unsigned SW = 20, // slave width (address bus width)
  SYNC_IN_BUS     =  0, // master bus for synchronised writes
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

sys_bus_if             bus_int_i[SN-1:0](.clk (bus_m.clk), .rstn (bus_m.rstn)); //@FCLK0
sys_bus_if             bus_int_o[SN-1:0]();

genvar i;
generate
    for (i = 0; i < SN; i = i + 1) begin : gen_bus_connect
        assign bus_int_o[i].clk  = bus_s[i].clk;
        assign bus_int_o[i].rstn = bus_s[i].rstn;
    end
endgenerate

assign bus_s_a  = `BUS_NAME_M.addr[SW+:SL];
assign bus_s_cs = SN'(1) << bus_s_a;

assign bus_s_sync_cs = {SN{bus_s_cs[SYNC_IN_BUS]}} & {syncd_cs};

generate
for (genvar i=0; i<SN; i++) begin: for_bus

assign bus_s_sync_adr[i] = bus_s_sync_cs[i] &&
                             ((`BUS_NAME_I2[SYNC_IN_BUS].addr[SW-1:0] == SYNC_REG_OFS1) || 
                              (`BUS_NAME_I2[SYNC_IN_BUS].addr[SW-1:0] == SYNC_REG_OFS2) || 
                              (`BUS_NAME_I2[SYNC_IN_BUS].addr[SW-1:0] == SYNC_REG_OFS3) || 
                              (`BUS_NAME_I2[SYNC_IN_BUS].addr[SW-1:0] == SYNC_REG_OFS4) ||
                              (`BUS_NAME_I2[SYNC_IN_BUS].addr[SW-1:0] == SYNC_REG_OFS5) ||
                              (`BUS_NAME_I2[SYNC_IN_BUS].addr[SW-1:0] == SYNC_REG_OFS6));      

assign syncd_cs[i]    =  (i == SYNC_OUT_BUS1) || 
                         (i == SYNC_OUT_BUS2) || 
                         (i == SYNC_OUT_BUS3) || 
                         (i == SYNC_OUT_BUS4) ||
                         (i == SYNC_OUT_BUS5) ||
                         (i == SYNC_OUT_BUS6);

  

assign `BUS_NAME_I1[i].addr  = `BUS_NAME_M.addr ;
assign `BUS_NAME_I1[i].wdata = `BUS_NAME_M.wdata;
assign `BUS_NAME_I1[i].wen   =  bus_s_cs[i] & `BUS_NAME_M.wen;
assign `BUS_NAME_I1[i].ren   =  bus_s_cs[i] & `BUS_NAME_M.ren;

//enables different config clock for each module if needed
sys_bus_cdc inst_sys_bus_cdc
(
  .pll_locked_i(pll_locked_i),
  .bus_m(`BUS_NAME_I2[i]),
  .bus_s(`BUS_NAME_I1[i])
);

assign `BUS_NAME_S[i].addr   = bus_s_sync_adr[i] ? `BUS_NAME_I2[SYNC_IN_BUS].addr  : `BUS_NAME_I2[i].addr;
assign `BUS_NAME_S[i].wdata  = bus_s_sync_adr[i] ? `BUS_NAME_I2[SYNC_IN_BUS].wdata : `BUS_NAME_I2[i].wdata;
assign `BUS_NAME_S[i].wen    = bus_s_sync_adr[i] ? `BUS_NAME_I2[SYNC_IN_BUS].wen   : `BUS_NAME_I2[i].wen;
assign `BUS_NAME_S[i].ren    = `BUS_NAME_I2[i].ren;

assign `BUS_NAME_I2[i].rdata = `BUS_NAME_S[i].rdata;
assign `BUS_NAME_I2[i].err   = `BUS_NAME_S[i].err  ;
assign `BUS_NAME_I2[i].ack   = `BUS_NAME_S[i].ack  ;


assign bus_s_rdata[i] = `BUS_NAME_I1[i].rdata;
assign bus_s_err  [i] = `BUS_NAME_I1[i].err  ;
assign bus_s_ack  [i] = `BUS_NAME_I1[i].ack  ;
end: for_bus
endgenerate

assign `BUS_NAME_M.rdata = bus_s_rdata[bus_s_a];
assign `BUS_NAME_M.err   = bus_s_err[bus_s_a];
assign `BUS_NAME_M.ack   = bus_s_ack[bus_s_a];


endmodule: sys_bus_interconnect
