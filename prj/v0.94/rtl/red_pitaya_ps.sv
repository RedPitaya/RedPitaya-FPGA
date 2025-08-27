////////////////////////////////////////////////////////////////////////////////
// @brief Red Pitaya Processing System (PS) wrapper. Including simple AXI slave.
// @Author Matej Oblak
// (c) Red Pitaya  http://www.redpitaya.com
////////////////////////////////////////////////////////////////////////////////

/**
 * GENERAL DESCRIPTION:
 *
 * Wrapper of block design.  
 *
 *                   /-------\
 *   PS CLK -------> |       | <---------------------> SPI master & slave
 *   PS RST -------> |  PS   |
 *                   |       | ------------+---------> FCLK & reset 
 *                   |       |             |
 *   PS DDR <------> |  ARM  |   AXI   /-------\
 *   PS MIO <------> |       | <-----> |  AXI  | <---> system bus
 *                   \-------/         | SLAVE |
 *                                     \-------/
 *
 * Module wrappes PS module (BD design from Vivado or EDK from PlanAhead).
 * There is also included simple AXI slave which serves as master for custom
 * system bus. With this simpler bus it is more easy for newbies to develop 
 * their own module communication with ARM.
 */

module red_pitaya_ps (
  // PS peripherals
  inout  logic [ 54-1:0] FIXED_IO_mio       ,
  inout  logic           FIXED_IO_ps_clk    ,
  inout  logic           FIXED_IO_ps_porb   ,
  inout  logic           FIXED_IO_ps_srstb  ,
  inout  logic           FIXED_IO_ddr_vrn   ,
  inout  logic           FIXED_IO_ddr_vrp   ,
  // DDR
  inout  logic [ 15-1:0] DDR_addr           ,
  inout  logic [  3-1:0] DDR_ba             ,
  inout  logic           DDR_cas_n          ,
  inout  logic           DDR_ck_n           ,
  inout  logic           DDR_ck_p           ,
  inout  logic           DDR_cke            ,
  inout  logic           DDR_cs_n           ,
  inout  logic [  4-1:0] DDR_dm             ,
  inout  logic [ 32-1:0] DDR_dq             ,
  inout  logic [  4-1:0] DDR_dqs_n          ,
  inout  logic [  4-1:0] DDR_dqs_p          ,
  inout  logic           DDR_odt            ,
  inout  logic           DDR_ras_n          ,
  inout  logic           DDR_reset_n        ,
  inout  logic           DDR_we_n           ,
  // system signals
  output logic [  4-1:0] fclk_clk_o         ,
  output logic [  4-1:0] fclk_rstn_o        ,
  //CAN0
  input                  CAN0_rx,
  output                 CAN0_tx,
  //CAN1
  input                  CAN1_rx,
  output                 CAN1_tx,
  // XADC
  input  logic  [ 5-1:0] vinp_i             ,  // voltages p
  input  logic  [ 5-1:0] vinn_i             ,  // voltages n
  // GPIO
  gpio_if.m              gpio,
  // system read/write channel
  sys_bus_if.m           bus,

  // AXI masters
  axi_sys_if.m           axi0_sys,
  axi_sys_if.m           axi1_sys,
  axi_sys_if.m           axi2_sys,
  axi_sys_if.m           axi3_sys
);

//------------------------------------------------------------------------------
// AXI master

axi4_if #(.DW (64), .AW (32), .IW (4), .LW (4)) hp0_saxi (.ACLK (axi0_sys.clk), .ARESETn (axi0_sys.rstn));
axi4_if #(.DW (64), .AW (32), .IW (4), .LW (4)) hp1_saxi (.ACLK (axi1_sys.clk), .ARESETn (axi1_sys.rstn));
axi4_if #(.DW (64), .AW (32), .IW (4), .LW (4)) hp2_saxi (.ACLK (axi2_sys.clk), .ARESETn (axi2_sys.rstn));
axi4_if #(.DW (64), .AW (32), .IW (4), .LW (4)) hp3_saxi (.ACLK (axi3_sys.clk), .ARESETn (axi3_sys.rstn));

axi_master #(
  .DW    (  64    ), // data width (8,16,...,1024)
  .AW    (  32    ), // address width
  .ID    (   1    ), // master ID
  .IW    (   4    ), // master ID width
  .LW    (   4    )  // length width
) axi_master_0 (
   // global signals
  .axi_clk_i      ( hp0_saxi.ACLK   ), // global clock
  .axi_rstn_i     ( hp0_saxi.ARESETn), // global reset
   // axi write address channel
  .axi_awid_o     ( hp0_saxi.AWID   ), // write address ID
  .axi_awaddr_o   ( hp0_saxi.AWADDR ), // write address
  .axi_awlen_o    ( hp0_saxi.AWLEN  ), // write burst length
  .axi_awsize_o   ( hp0_saxi.AWSIZE ), // write burst size
  .axi_awburst_o  ( hp0_saxi.AWBURST), // write burst type
  .axi_awlock_o   ( hp0_saxi.AWLOCK ), // write lock type
  .axi_awcache_o  ( hp0_saxi.AWCACHE), // write cache type
  .axi_awprot_o   ( hp0_saxi.AWPROT ), // write protection type
  .axi_awvalid_o  ( hp0_saxi.AWVALID), // write address valid
  .axi_awready_i  ( hp0_saxi.AWREADY), // write ready
   // axi write data channel
  .axi_wid_o      ( hp0_saxi.WID    ), // write data ID
  .axi_wdata_o    ( hp0_saxi.WDATA  ), // write data
  .axi_wstrb_o    ( hp0_saxi.WSTRB  ), // write strobes
  .axi_wlast_o    ( hp0_saxi.WLAST  ), // write last
  .axi_wvalid_o   ( hp0_saxi.WVALID ), // write valid
  .axi_wready_i   ( hp0_saxi.WREADY ), // write ready
   // axi write response channel
  .axi_bid_i      ( hp0_saxi.BID    ), // write response ID
  .axi_bresp_i    ( hp0_saxi.BRESP  ), // write response
  .axi_bvalid_i   ( hp0_saxi.BVALID ), // write response valid
  .axi_bready_o   ( hp0_saxi.BREADY ), // write response ready
   // axi read address channel
  .axi_arid_o     ( hp0_saxi.ARID   ), // read address ID
  .axi_araddr_o   ( hp0_saxi.ARADDR ), // read address
  .axi_arlen_o    ( hp0_saxi.ARLEN  ), // read burst length
  .axi_arsize_o   ( hp0_saxi.ARSIZE ), // read burst size
  .axi_arburst_o  ( hp0_saxi.ARBURST), // read burst type
  .axi_arlock_o   ( hp0_saxi.ARLOCK ), // read lock type
  .axi_arcache_o  ( hp0_saxi.ARCACHE), // read cache type
  .axi_arprot_o   ( hp0_saxi.ARPROT ), // read protection type
  .axi_arvalid_o  ( hp0_saxi.ARVALID), // read address valid
  .axi_arready_i  ( hp0_saxi.ARREADY), // read address ready
   // axi read data channel
  .axi_rid_i      ( hp0_saxi.RID    ), // read response ID
  .axi_rdata_i    ( hp0_saxi.RDATA  ), // read data
  .axi_rresp_i    ( hp0_saxi.RRESP  ), // read response
  .axi_rlast_i    ( hp0_saxi.RLAST  ), // read last
  .axi_rvalid_i   ( hp0_saxi.RVALID ), // read response valid
  .axi_rready_o   ( hp0_saxi.RREADY ), // read response ready
   // system write channel
  .sys_waddr_i    ( axi0_sys.waddr  ), // system write address
  .sys_wdata_i    ( axi0_sys.wdata  ), // system write data
  .sys_wsel_i     ( axi0_sys.wsel   ), // system write byte select
  .sys_wsize_i    ( axi0_sys.wsize  ), // system write size
  .sys_wvalid_i   ( axi0_sys.wvalid ), // system write data valid
  .sys_wlen_i     ( axi0_sys.wlen   ), // system write burst lengthW
  .sys_wfixed_i   ( axi0_sys.wfixed ), // system write burst type (fixed / incremental)
  .sys_werr_o     ( axi0_sys.werr   ), // system write error
  .sys_wrdy_o     ( axi0_sys.wrdy   ), // system write ready
   // system read channel
  .sys_raddr_i    ( axi0_sys.raddr  ), // system read address
  .sys_rvalid_i   ( axi0_sys.rvalid ), // system read address valid
  .sys_rsel_i     ( axi0_sys.rsel   ), // system read byte select
  .sys_rsize_i    ( axi0_sys.rsize  ), // system read size
  .sys_rlen_i     ( axi0_sys.rlen   ), // system read burst length
  .sys_rfixed_i   ( axi0_sys.rfixed ), // system read burst type (fixed / incremental)
  .sys_rdata_o    ( axi0_sys.rdata  ), // system read data
  .sys_rrdy_o     ( axi0_sys.rrdym  ), // system read data is ready - master
  .sys_rrdy_i     ( axi0_sys.rrdys  ), // system read data is ready -slave
  .sys_rardy_o    ( axi0_sys.rardy  ), // system read address is ready
  .sys_rerr_o     ( axi0_sys.rerr   )  // system read error
);

axi_master #(
  .DW    (  64    ), // data width (8,16,...,1024)
  .AW    (  32    ), // address width
  .ID    (   2    ), // master ID
  .IW    (   4    ), // master ID width
  .LW    (   4    )  // length width
) axi_master_1 (
   // global signals
  .axi_clk_i      ( hp1_saxi.ACLK   ), // global clock
  .axi_rstn_i     ( hp1_saxi.ARESETn), // global reset
   // axi write address channel
  .axi_awid_o     ( hp1_saxi.AWID   ), // write address ID
  .axi_awaddr_o   ( hp1_saxi.AWADDR ), // write address
  .axi_awlen_o    ( hp1_saxi.AWLEN  ), // write burst length
  .axi_awsize_o   ( hp1_saxi.AWSIZE ), // write burst size
  .axi_awburst_o  ( hp1_saxi.AWBURST), // write burst type
  .axi_awlock_o   ( hp1_saxi.AWLOCK ), // write lock type
  .axi_awcache_o  ( hp1_saxi.AWCACHE), // write cache type
  .axi_awprot_o   ( hp1_saxi.AWPROT ), // write protection type
  .axi_awvalid_o  ( hp1_saxi.AWVALID), // write address valid
  .axi_awready_i  ( hp1_saxi.AWREADY), // write ready
   // axi write data channel
  .axi_wid_o      ( hp1_saxi.WID    ), // write data ID
  .axi_wdata_o    ( hp1_saxi.WDATA  ), // write data
  .axi_wstrb_o    ( hp1_saxi.WSTRB  ), // write strobes
  .axi_wlast_o    ( hp1_saxi.WLAST  ), // write last
  .axi_wvalid_o   ( hp1_saxi.WVALID ), // write valid
  .axi_wready_i   ( hp1_saxi.WREADY ), // write ready
   // axi write response channel
  .axi_bid_i      ( hp1_saxi.BID    ), // write response ID
  .axi_bresp_i    ( hp1_saxi.BRESP  ), // write response
  .axi_bvalid_i   ( hp1_saxi.BVALID ), // write response valid
  .axi_bready_o   ( hp1_saxi.BREADY ), // write response ready
   // axi read address channel
  .axi_arid_o     ( hp1_saxi.ARID   ), // read address ID
  .axi_araddr_o   ( hp1_saxi.ARADDR ), // read address
  .axi_arlen_o    ( hp1_saxi.ARLEN  ), // read burst length
  .axi_arsize_o   ( hp1_saxi.ARSIZE ), // read burst size
  .axi_arburst_o  ( hp1_saxi.ARBURST), // read burst type
  .axi_arlock_o   ( hp1_saxi.ARLOCK ), // read lock type
  .axi_arcache_o  ( hp1_saxi.ARCACHE), // read cache type
  .axi_arprot_o   ( hp1_saxi.ARPROT ), // read protection type
  .axi_arvalid_o  ( hp1_saxi.ARVALID), // read address valid
  .axi_arready_i  ( hp1_saxi.ARREADY), // read address ready
   // axi read data channel
  .axi_rid_i      ( hp1_saxi.RID    ), // read response ID
  .axi_rdata_i    ( hp1_saxi.RDATA  ), // read data
  .axi_rresp_i    ( hp1_saxi.RRESP  ), // read response
  .axi_rlast_i    ( hp1_saxi.RLAST  ), // read last
  .axi_rvalid_i   ( hp1_saxi.RVALID ), // read response valid
  .axi_rready_o   ( hp1_saxi.RREADY ), // read response ready
   // system write channel
  .sys_waddr_i    ( axi1_sys.waddr  ), // system write address
  .sys_wdata_i    ( axi1_sys.wdata  ), // system write data
  .sys_wsel_i     ( axi1_sys.wsel   ), // system write byte select
  .sys_wsize_i    ( axi1_sys.wsize  ), // system write size
  .sys_wvalid_i   ( axi1_sys.wvalid ), // system write data valid
  .sys_wlen_i     ( axi1_sys.wlen   ), // system write burst lengthW
  .sys_wfixed_i   ( axi1_sys.wfixed ), // system write burst type (fixed / incremental)
  .sys_werr_o     ( axi1_sys.werr   ), // system write error
  .sys_wrdy_o     ( axi1_sys.wrdy   ), // system write ready
   // system read channel
  .sys_raddr_i    ( axi1_sys.raddr  ), // system read address
  .sys_rvalid_i   ( axi1_sys.rvalid ), // system read address valid
  .sys_rsel_i     ( axi1_sys.rsel   ), // system read byte select
  .sys_rsize_i    ( axi1_sys.rsize  ), // system read size
  .sys_rlen_i     ( axi1_sys.rlen   ), // system read burst length
  .sys_rfixed_i   ( axi1_sys.rfixed ), // system read burst type (fixed / incremental)
  .sys_rdata_o    ( axi1_sys.rdata  ), // system read data
  .sys_rrdy_o     ( axi1_sys.rrdym  ), // system read data is ready - master
  .sys_rrdy_i     ( axi1_sys.rrdys  ), // system read data is ready -slave
  .sys_rardy_o    ( axi1_sys.rardy  ), // system read address is ready
  .sys_rerr_o     ( axi1_sys.rerr   )  // system read error
);

axi_master #(
  .DW    (  64    ), // data width (8,16,...,1024)
  .AW    (  32    ), // address width
  .ID    (   3    ), // master ID // TODO, it is not OK to have two masters with same ID
  .IW    (   4    ), // master ID width
  .LW    (   4    )  // length width
) axi_master_2 (
   // global signals
  .axi_clk_i      ( hp2_saxi.ACLK   ), // global clock
  .axi_rstn_i     ( hp2_saxi.ARESETn), // global reset
   // axi write address channel
  .axi_awid_o     ( hp2_saxi.AWID   ), // write address ID
  .axi_awaddr_o   ( hp2_saxi.AWADDR ), // write address
  .axi_awlen_o    ( hp2_saxi.AWLEN  ), // write burst length
  .axi_awsize_o   ( hp2_saxi.AWSIZE ), // write burst size
  .axi_awburst_o  ( hp2_saxi.AWBURST), // write burst type
  .axi_awlock_o   ( hp2_saxi.AWLOCK ), // write lock type
  .axi_awcache_o  ( hp2_saxi.AWCACHE), // write cache type
  .axi_awprot_o   ( hp2_saxi.AWPROT ), // write protection type
  .axi_awvalid_o  ( hp2_saxi.AWVALID), // write address valid
  .axi_awready_i  ( hp2_saxi.AWREADY), // write ready
   // axi write data channel
  .axi_wid_o      ( hp2_saxi.WID    ), // write data ID
  .axi_wdata_o    ( hp2_saxi.WDATA  ), // write data
  .axi_wstrb_o    ( hp2_saxi.WSTRB  ), // write strobes
  .axi_wlast_o    ( hp2_saxi.WLAST  ), // write last
  .axi_wvalid_o   ( hp2_saxi.WVALID ), // write valid
  .axi_wready_i   ( hp2_saxi.WREADY ), // write ready
   // axi write response channel
  .axi_bid_i      ( hp2_saxi.BID    ), // write response ID
  .axi_bresp_i    ( hp2_saxi.BRESP  ), // write response
  .axi_bvalid_i   ( hp2_saxi.BVALID ), // write response valid
  .axi_bready_o   ( hp2_saxi.BREADY ), // write response ready
   // axi read address channel
  .axi_arid_o     ( hp2_saxi.ARID   ), // read address ID
  .axi_araddr_o   ( hp2_saxi.ARADDR ), // read address
  .axi_arlen_o    ( hp2_saxi.ARLEN  ), // read burst length
  .axi_arsize_o   ( hp2_saxi.ARSIZE ), // read burst size
  .axi_arburst_o  ( hp2_saxi.ARBURST), // read burst type
  .axi_arlock_o   ( hp2_saxi.ARLOCK ), // read lock type
  .axi_arcache_o  ( hp2_saxi.ARCACHE), // read cache type
  .axi_arprot_o   ( hp2_saxi.ARPROT ), // read protection type
  .axi_arvalid_o  ( hp2_saxi.ARVALID), // read address valid
  .axi_arready_i  ( hp2_saxi.ARREADY), // read address ready
   // axi read data channel
  .axi_rid_i      ( hp2_saxi.RID    ), // read response ID
  .axi_rdata_i    ( hp2_saxi.RDATA  ), // read data
  .axi_rresp_i    ( hp2_saxi.RRESP  ), // read response
  .axi_rlast_i    ( hp2_saxi.RLAST  ), // read last
  .axi_rvalid_i   ( hp2_saxi.RVALID ), // read response valid
  .axi_rready_o   ( hp2_saxi.RREADY ), // read response ready
   // system write channel
  .sys_waddr_i    ( axi2_sys.waddr  ), // system write address
  .sys_wdata_i    ( axi2_sys.wdata  ), // system write data
  .sys_wsel_i     ( axi2_sys.wsel   ), // system write byte select
  .sys_wsize_i    ( axi2_sys.wsize  ), // system write size
  .sys_wvalid_i   ( axi2_sys.wvalid ), // system write data valid
  .sys_wlen_i     ( axi2_sys.wlen   ), // system write burst lengthW
  .sys_wfixed_i   ( axi2_sys.wfixed ), // system write burst type (fixed / incremental)
  .sys_werr_o     ( axi2_sys.werr   ), // system write error
  .sys_wrdy_o     ( axi2_sys.wrdy   ), // system write ready
   // system read channel
  .sys_raddr_i    ( axi2_sys.raddr  ), // system read address
  .sys_rvalid_i   ( axi2_sys.rvalid ), // system read address valid
  .sys_rsel_i     ( axi2_sys.rsel   ), // system read byte select
  .sys_rsize_i    ( axi2_sys.rsize  ), // system read size
  .sys_rlen_i     ( axi2_sys.rlen   ), // system read burst length
  .sys_rfixed_i   ( axi2_sys.rfixed ), // system read burst type (fixed / incremental)
  .sys_rdata_o    ( axi2_sys.rdata  ), // system read data
  .sys_rrdy_o     ( axi2_sys.rrdym  ), // system read data is ready - master
  .sys_rrdy_i     ( axi2_sys.rrdys  ), // system read data is ready -slave  
  .sys_rardy_o    ( axi2_sys.rardy  ), // system read address is ready
  .sys_rerr_o     ( axi2_sys.rerr   )  // system read error
);

axi_master #(
  .DW    (  64    ), // data width (8,16,...,1024)
  .AW    (  32    ), // address width
  .ID    (   4    ), // master ID // TODO, it is not OK to have two masters with same ID
  .IW    (   4    ), // master ID width
  .LW    (   4    )  // length width
) axi_master_3 (
   // global signals
  .axi_clk_i      ( hp3_saxi.ACLK   ), // global clock
  .axi_rstn_i     ( hp3_saxi.ARESETn), // global reset
   // axi write address channel
  .axi_awid_o     ( hp3_saxi.AWID   ), // write address ID
  .axi_awaddr_o   ( hp3_saxi.AWADDR ), // write address
  .axi_awlen_o    ( hp3_saxi.AWLEN  ), // write burst length
  .axi_awsize_o   ( hp3_saxi.AWSIZE ), // write burst size
  .axi_awburst_o  ( hp3_saxi.AWBURST), // write burst type
  .axi_awlock_o   ( hp3_saxi.AWLOCK ), // write lock type
  .axi_awcache_o  ( hp3_saxi.AWCACHE), // write cache type
  .axi_awprot_o   ( hp3_saxi.AWPROT ), // write protection type
  .axi_awvalid_o  ( hp3_saxi.AWVALID), // write address valid
  .axi_awready_i  ( hp3_saxi.AWREADY), // write ready
   // axi write data channel
  .axi_wid_o      ( hp3_saxi.WID    ), // write data ID
  .axi_wdata_o    ( hp3_saxi.WDATA  ), // write data
  .axi_wstrb_o    ( hp3_saxi.WSTRB  ), // write strobes
  .axi_wlast_o    ( hp3_saxi.WLAST  ), // write last
  .axi_wvalid_o   ( hp3_saxi.WVALID ), // write valid
  .axi_wready_i   ( hp3_saxi.WREADY ), // write ready
   // axi write response channel
  .axi_bid_i      ( hp3_saxi.BID    ), // write response ID
  .axi_bresp_i    ( hp3_saxi.BRESP  ), // write response
  .axi_bvalid_i   ( hp3_saxi.BVALID ), // write response valid
  .axi_bready_o   ( hp3_saxi.BREADY ), // write response ready
   // axi read address channel
  .axi_arid_o     ( hp3_saxi.ARID   ), // read address ID
  .axi_araddr_o   ( hp3_saxi.ARADDR ), // read address
  .axi_arlen_o    ( hp3_saxi.ARLEN  ), // read burst length
  .axi_arsize_o   ( hp3_saxi.ARSIZE ), // read burst size
  .axi_arburst_o  ( hp3_saxi.ARBURST), // read burst type
  .axi_arlock_o   ( hp3_saxi.ARLOCK ), // read lock type
  .axi_arcache_o  ( hp3_saxi.ARCACHE), // read cache type
  .axi_arprot_o   ( hp3_saxi.ARPROT ), // read protection type
  .axi_arvalid_o  ( hp3_saxi.ARVALID), // read address valid
  .axi_arready_i  ( hp3_saxi.ARREADY), // read address ready
   // axi read data channel
  .axi_rid_i      ( hp3_saxi.RID    ), // read response ID
  .axi_rdata_i    ( hp3_saxi.RDATA  ), // read data
  .axi_rresp_i    ( hp3_saxi.RRESP  ), // read response
  .axi_rlast_i    ( hp3_saxi.RLAST  ), // read last
  .axi_rvalid_i   ( hp3_saxi.RVALID ), // read response valid
  .axi_rready_o   ( hp3_saxi.RREADY ), // read response ready
   // system write channel
  .sys_waddr_i    ( axi3_sys.waddr  ), // system write address
  .sys_wdata_i    ( axi3_sys.wdata  ), // system write data
  .sys_wsel_i     ( axi3_sys.wsel   ), // system write byte select
  .sys_wsize_i    ( axi3_sys.wsize  ), // system write size
  .sys_wvalid_i   ( axi3_sys.wvalid ), // system write data valid
  .sys_wlen_i     ( axi3_sys.wlen   ), // system write burst lengthW
  .sys_wfixed_i   ( axi3_sys.wfixed ), // system write burst type (fixed / incremental)
  .sys_werr_o     ( axi3_sys.werr   ), // system write error
  .sys_wrdy_o     ( axi3_sys.wrdy   ), // system write ready
   // system read channel
  .sys_raddr_i    ( axi3_sys.raddr  ), // system read address
  .sys_rvalid_i   ( axi3_sys.rvalid ), // system read address valid
  .sys_rsel_i     ( axi3_sys.rsel   ), // system read byte select
  .sys_rsize_i    ( axi3_sys.rsize  ), // system read size
  .sys_rlen_i     ( axi3_sys.rlen   ), // system read burst length
  .sys_rfixed_i   ( axi3_sys.rfixed ), // system read burst type (fixed / incremental)
  .sys_rdata_o    ( axi3_sys.rdata  ), // system read data
  .sys_rrdy_o     ( axi3_sys.rrdym  ), // system read data is ready - master
  .sys_rrdy_i     ( axi3_sys.rrdys  ), // system read data is ready -slave
  .sys_rardy_o    ( axi3_sys.rardy  ), // system read address is ready
  .sys_rerr_o     ( axi3_sys.rerr   )  // system read error
);


assign hp0_saxi.ARQOS  = 4'h0 ;
assign hp0_saxi.AWQOS  = 4'h0 ;

assign hp1_saxi.ARQOS  = 4'h0 ;
assign hp1_saxi.AWQOS  = 4'h0 ;

assign hp2_saxi.ARQOS  = 4'hF ;
assign hp2_saxi.AWQOS  = 4'h0 ;

assign hp3_saxi.ARQOS  = 4'hF ;
assign hp3_saxi.AWQOS  = 4'h0 ;

////////////////////////////////////////////////////////////////////////////////
// AXI SLAVE
////////////////////////////////////////////////////////////////////////////////

logic [4-1:0] fclk_clk ;
logic [4-1:0] fclk_rstn;

axi4_if #(.DW (32), .AW (32), .IW (12), .LW (4)) axi_gp (.ACLK (bus.clk), .ARESETn (bus.rstn));

axi4_slave #(
  .DW (32),
  .AW (32),
  .IW (12)
) axi_slave_gp0 (
  // AXI bus
  .axi       (axi_gp),
  // system read/write channel
  .bus       (bus)
);

////////////////////////////////////////////////////////////////////////////////
// PS STUB
////////////////////////////////////////////////////////////////////////////////

assign fclk_rstn_o = fclk_rstn;

BUFG fclk_buf [4-1:0] (.O(fclk_clk_o), .I(fclk_clk));

`ifdef SIMULATION
system_model system_i
`else
system system_i 
`endif //SIMULATION
(
  // MIO
  .FIXED_IO_mio      (FIXED_IO_mio     ),
  .FIXED_IO_ps_clk   (FIXED_IO_ps_clk  ),
  .FIXED_IO_ps_porb  (FIXED_IO_ps_porb ),
  .FIXED_IO_ps_srstb (FIXED_IO_ps_srstb),
  .FIXED_IO_ddr_vrn  (FIXED_IO_ddr_vrn ),
  .FIXED_IO_ddr_vrp  (FIXED_IO_ddr_vrp ),
  // DDR
  .DDR_addr          (DDR_addr         ),
  .DDR_ba            (DDR_ba           ),
  .DDR_cas_n         (DDR_cas_n        ),
  .DDR_ck_n          (DDR_ck_n         ),
  .DDR_ck_p          (DDR_ck_p         ),
  .DDR_cke           (DDR_cke          ),
  .DDR_cs_n          (DDR_cs_n         ),
  .DDR_dm            (DDR_dm           ),
  .DDR_dq            (DDR_dq           ),
  .DDR_dqs_n         (DDR_dqs_n        ),
  .DDR_dqs_p         (DDR_dqs_p        ),
  .DDR_odt           (DDR_odt          ),
  .DDR_ras_n         (DDR_ras_n        ),
  .DDR_reset_n       (DDR_reset_n      ),
  .DDR_we_n          (DDR_we_n         ),
  // FCLKs
  .FCLK_CLK0         (fclk_clk[0]      ),
  .FCLK_CLK1         (fclk_clk[1]      ),
  .FCLK_CLK2         (fclk_clk[2]      ),
  .FCLK_CLK3         (fclk_clk[3]      ),
  .FCLK_RESET0_N     (fclk_rstn[0]     ),
  .FCLK_RESET1_N     (fclk_rstn[1]     ),
  .FCLK_RESET2_N     (fclk_rstn[2]     ),
  .FCLK_RESET3_N     (fclk_rstn[3]     ),
  // XADC
  .Vaux0_v_n (vinn_i[1]),  .Vaux0_v_p (vinp_i[1]),
  .Vaux1_v_n (vinn_i[2]),  .Vaux1_v_p (vinp_i[2]),
  .Vaux8_v_n (vinn_i[0]),  .Vaux8_v_p (vinp_i[0]),
  .Vaux9_v_n (vinn_i[3]),  .Vaux9_v_p (vinp_i[3]),
  .Vp_Vn_v_n (vinn_i[4]),  .Vp_Vn_v_p (vinp_i[4]),
  // GP0
  .M_AXI_GP0_ACLK    (axi_gp.ACLK   ),
//  .M_AXI_GP0_ARESETn (axi_gp.ARESETn),
  .M_AXI_GP0_arvalid (axi_gp.ARVALID),
  .M_AXI_GP0_awvalid (axi_gp.AWVALID),
  .M_AXI_GP0_bready  (axi_gp.BREADY ),
  .M_AXI_GP0_rready  (axi_gp.RREADY ),
  .M_AXI_GP0_wlast   (axi_gp.WLAST  ),
  .M_AXI_GP0_wvalid  (axi_gp.WVALID ),
  .M_AXI_GP0_arid    (axi_gp.ARID   ),
  .M_AXI_GP0_awid    (axi_gp.AWID   ),
  .M_AXI_GP0_wid     (axi_gp.WID    ),
  .M_AXI_GP0_arburst (axi_gp.ARBURST),
  .M_AXI_GP0_arlock  (axi_gp.ARLOCK ),
  .M_AXI_GP0_arsize  (axi_gp.ARSIZE ),
  .M_AXI_GP0_awburst (axi_gp.AWBURST),
  .M_AXI_GP0_awlock  (axi_gp.AWLOCK ),
  .M_AXI_GP0_awsize  (axi_gp.AWSIZE ),
  .M_AXI_GP0_arprot  (axi_gp.ARPROT ),
  .M_AXI_GP0_awprot  (axi_gp.AWPROT ),
  .M_AXI_GP0_araddr  (axi_gp.ARADDR ),
  .M_AXI_GP0_awaddr  (axi_gp.AWADDR ),
  .M_AXI_GP0_wdata   (axi_gp.WDATA  ),
  .M_AXI_GP0_arcache (axi_gp.ARCACHE),
  .M_AXI_GP0_arlen   (axi_gp.ARLEN  ),
  .M_AXI_GP0_arqos   (axi_gp.ARQOS  ),
  .M_AXI_GP0_awcache (axi_gp.AWCACHE),
  .M_AXI_GP0_awlen   (axi_gp.AWLEN  ),
  .M_AXI_GP0_awqos   (axi_gp.AWQOS  ),
  .M_AXI_GP0_wstrb   (axi_gp.WSTRB  ),
  .M_AXI_GP0_arready (axi_gp.ARREADY),
  .M_AXI_GP0_awready (axi_gp.AWREADY),
  .M_AXI_GP0_bvalid  (axi_gp.BVALID ),
  .M_AXI_GP0_rlast   (axi_gp.RLAST  ),
  .M_AXI_GP0_rvalid  (axi_gp.RVALID ),
  .M_AXI_GP0_wready  (axi_gp.WREADY ),
  .M_AXI_GP0_bid     (axi_gp.BID    ),
  .M_AXI_GP0_rid     (axi_gp.RID    ),
  .M_AXI_GP0_bresp   (axi_gp.BRESP  ),
  .M_AXI_GP0_rresp   (axi_gp.RRESP  ),
  .M_AXI_GP0_rdata   (axi_gp.RDATA  ),
  // GPIO
  .GPIO_tri_i (gpio.i),
  .GPIO_tri_o (gpio.o),
  .GPIO_tri_t (gpio.t),
  // SPI
  .SPI0_io0_i (1'b0),
  .SPI0_io0_o (),
  .SPI0_io0_t (),
  .SPI0_io1_i (1'b0),
  .SPI0_io1_o (),
  .SPI0_io1_t (),
  .SPI0_sck_i (1'b0),
  .SPI0_sck_o (),
  .SPI0_sck_t (),
  .SPI0_ss1_o (),
  .SPI0_ss2_o (),
  .SPI0_ss_i  (1'b0),
  .SPI0_ss_o  (),
  .SPI0_ss_t  (),
  // CAN0
  .CAN0_rx (CAN0_rx),
  .CAN0_tx (CAN0_tx),
  // CAN1
  .CAN1_rx (CAN1_rx),
  .CAN1_tx (CAN1_tx),
  // HP0                                  // HP1
  .S_AXI_HP0_arready (hp0_saxi.ARREADY),  .S_AXI_HP1_arready (hp1_saxi.ARREADY), // out
  .S_AXI_HP0_awready (hp0_saxi.AWREADY),  .S_AXI_HP1_awready (hp1_saxi.AWREADY), // out
  .S_AXI_HP0_bvalid  (hp0_saxi.BVALID ),  .S_AXI_HP1_bvalid  (hp1_saxi.BVALID ), // out
  .S_AXI_HP0_rlast   (hp0_saxi.RLAST  ),  .S_AXI_HP1_rlast   (hp1_saxi.RLAST  ), // out
  .S_AXI_HP0_rvalid  (hp0_saxi.RVALID ),  .S_AXI_HP1_rvalid  (hp1_saxi.RVALID ), // out
  .S_AXI_HP0_wready  (hp0_saxi.WREADY ),  .S_AXI_HP1_wready  (hp1_saxi.WREADY ), // out
  .S_AXI_HP0_bresp   (hp0_saxi.BRESP  ),  .S_AXI_HP1_bresp   (hp1_saxi.BRESP  ), // out 2
  .S_AXI_HP0_rresp   (hp0_saxi.RRESP  ),  .S_AXI_HP1_rresp   (hp1_saxi.RRESP  ), // out 2
  .S_AXI_HP0_bid     (hp0_saxi.BID    ),  .S_AXI_HP1_bid     (hp1_saxi.BID    ), // out 6
  .S_AXI_HP0_rid     (hp0_saxi.RID    ),  .S_AXI_HP1_rid     (hp1_saxi.RID    ), // out 6
  .S_AXI_HP0_rdata   (hp0_saxi.RDATA  ),  .S_AXI_HP1_rdata   (hp1_saxi.RDATA  ), // out 64
  .S_AXI_HP0_aclk    (hp0_saxi.ACLK   ),  .S_AXI_HP1_aclk    (hp1_saxi.ACLK   ), // in
  .S_AXI_HP0_arvalid (hp0_saxi.ARVALID),  .S_AXI_HP1_arvalid (hp1_saxi.ARVALID), // in
  .S_AXI_HP0_awvalid (hp0_saxi.AWVALID),  .S_AXI_HP1_awvalid (hp1_saxi.AWVALID), // in
  .S_AXI_HP0_bready  (hp0_saxi.BREADY ),  .S_AXI_HP1_bready  (hp1_saxi.BREADY ), // in
  .S_AXI_HP0_rready  (hp0_saxi.RREADY ),  .S_AXI_HP1_rready  (hp1_saxi.RREADY ), // in
  .S_AXI_HP0_wlast   (hp0_saxi.WLAST  ),  .S_AXI_HP1_wlast   (hp1_saxi.WLAST  ), // in
  .S_AXI_HP0_wvalid  (hp0_saxi.WVALID ),  .S_AXI_HP1_wvalid  (hp1_saxi.WVALID ), // in
  .S_AXI_HP0_arburst (hp0_saxi.ARBURST),  .S_AXI_HP1_arburst (hp1_saxi.ARBURST), // in 2
  .S_AXI_HP0_arlock  (hp0_saxi.ARLOCK ),  .S_AXI_HP1_arlock  (hp1_saxi.ARLOCK ), // in 2
  .S_AXI_HP0_arsize  (hp0_saxi.ARSIZE ),  .S_AXI_HP1_arsize  (hp1_saxi.ARSIZE ), // in 3
  .S_AXI_HP0_awburst (hp0_saxi.AWBURST),  .S_AXI_HP1_awburst (hp1_saxi.AWBURST), // in 2
  .S_AXI_HP0_awlock  (hp0_saxi.AWLOCK ),  .S_AXI_HP1_awlock  (hp1_saxi.AWLOCK ), // in 2
  .S_AXI_HP0_awsize  (hp0_saxi.AWSIZE ),  .S_AXI_HP1_awsize  (hp1_saxi.AWSIZE ), // in 3
  .S_AXI_HP0_arprot  (hp0_saxi.ARPROT ),  .S_AXI_HP1_arprot  (hp1_saxi.ARPROT ), // in 3
  .S_AXI_HP0_awprot  (hp0_saxi.AWPROT ),  .S_AXI_HP1_awprot  (hp1_saxi.AWPROT ), // in 3
  .S_AXI_HP0_araddr  (hp0_saxi.ARADDR ),  .S_AXI_HP1_araddr  (hp1_saxi.ARADDR ), // in 32
  .S_AXI_HP0_awaddr  (hp0_saxi.AWADDR ),  .S_AXI_HP1_awaddr  (hp1_saxi.AWADDR ), // in 32
  .S_AXI_HP0_arcache (hp0_saxi.ARCACHE),  .S_AXI_HP1_arcache (hp1_saxi.ARCACHE), // in 4
  .S_AXI_HP0_arlen   (hp0_saxi.ARLEN  ),  .S_AXI_HP1_arlen   (hp1_saxi.ARLEN  ), // in 4
  .S_AXI_HP0_arqos   (hp0_saxi.ARQOS  ),  .S_AXI_HP1_arqos   (hp1_saxi.ARQOS  ), // in 4
  .S_AXI_HP0_awcache (hp0_saxi.AWCACHE),  .S_AXI_HP1_awcache (hp1_saxi.AWCACHE), // in 4
  .S_AXI_HP0_awlen   (hp0_saxi.AWLEN  ),  .S_AXI_HP1_awlen   (hp1_saxi.AWLEN  ), // in 4
  .S_AXI_HP0_awqos   (hp0_saxi.AWQOS  ),  .S_AXI_HP1_awqos   (hp1_saxi.AWQOS  ), // in 4
  .S_AXI_HP0_arid    (hp0_saxi.ARID   ),  .S_AXI_HP1_arid    (hp1_saxi.ARID   ), // in 6
  .S_AXI_HP0_awid    (hp0_saxi.AWID   ),  .S_AXI_HP1_awid    (hp1_saxi.AWID   ), // in 6
  .S_AXI_HP0_wid     (hp0_saxi.WID    ),  .S_AXI_HP1_wid     (hp1_saxi.WID    ), // in 6
  .S_AXI_HP0_wdata   (hp0_saxi.WDATA  ),  .S_AXI_HP1_wdata   (hp1_saxi.WDATA  ), // in 64
  .S_AXI_HP0_wstrb   (hp0_saxi.WSTRB  ),  .S_AXI_HP1_wstrb   (hp1_saxi.WSTRB  ), // in 8

  // HP2                                  // HP3
  .S_AXI_HP2_arready (hp2_saxi.ARREADY),  .S_AXI_HP3_arready (hp3_saxi.ARREADY), // out
  .S_AXI_HP2_awready (hp2_saxi.AWREADY),  .S_AXI_HP3_awready (hp3_saxi.AWREADY), // out
  .S_AXI_HP2_bvalid  (hp2_saxi.BVALID ),  .S_AXI_HP3_bvalid  (hp3_saxi.BVALID ), // out
  .S_AXI_HP2_rlast   (hp2_saxi.RLAST  ),  .S_AXI_HP3_rlast   (hp3_saxi.RLAST  ), // out
  .S_AXI_HP2_rvalid  (hp2_saxi.RVALID ),  .S_AXI_HP3_rvalid  (hp3_saxi.RVALID ), // out
  .S_AXI_HP2_wready  (hp2_saxi.WREADY ),  .S_AXI_HP3_wready  (hp3_saxi.WREADY ), // out
  .S_AXI_HP2_bresp   (hp2_saxi.BRESP  ),  .S_AXI_HP3_bresp   (hp3_saxi.BRESP  ), // out 2
  .S_AXI_HP2_rresp   (hp2_saxi.RRESP  ),  .S_AXI_HP3_rresp   (hp3_saxi.RRESP  ), // out 2
  .S_AXI_HP2_bid     (hp2_saxi.BID    ),  .S_AXI_HP3_bid     (hp3_saxi.BID    ), // out 6
  .S_AXI_HP2_rid     (hp2_saxi.RID    ),  .S_AXI_HP3_rid     (hp3_saxi.RID    ), // out 6
  .S_AXI_HP2_rdata   (hp2_saxi.RDATA  ),  .S_AXI_HP3_rdata   (hp3_saxi.RDATA  ), // out 64
  .S_AXI_HP2_aclk    (hp2_saxi.ACLK   ),  .S_AXI_HP3_aclk    (hp3_saxi.ACLK   ), // in
  .S_AXI_HP2_arvalid (hp2_saxi.ARVALID),  .S_AXI_HP3_arvalid (hp3_saxi.ARVALID), // in
  .S_AXI_HP2_awvalid (hp2_saxi.AWVALID),  .S_AXI_HP3_awvalid (hp3_saxi.AWVALID), // in
  .S_AXI_HP2_bready  (hp2_saxi.BREADY ),  .S_AXI_HP3_bready  (hp3_saxi.BREADY ), // in
  .S_AXI_HP2_rready  (hp2_saxi.RREADY ),  .S_AXI_HP3_rready  (hp3_saxi.RREADY ), // in
  .S_AXI_HP2_wlast   (hp2_saxi.WLAST  ),  .S_AXI_HP3_wlast   (hp3_saxi.WLAST  ), // in
  .S_AXI_HP2_wvalid  (hp2_saxi.WVALID ),  .S_AXI_HP3_wvalid  (hp3_saxi.WVALID ), // in
  .S_AXI_HP2_arburst (hp2_saxi.ARBURST),  .S_AXI_HP3_arburst (hp3_saxi.ARBURST), // in 2
  .S_AXI_HP2_arlock  (hp2_saxi.ARLOCK ),  .S_AXI_HP3_arlock  (hp3_saxi.ARLOCK ), // in 2
  .S_AXI_HP2_arsize  (hp2_saxi.ARSIZE ),  .S_AXI_HP3_arsize  (hp3_saxi.ARSIZE ), // in 3
  .S_AXI_HP2_awburst (hp2_saxi.AWBURST),  .S_AXI_HP3_awburst (hp3_saxi.AWBURST), // in 2
  .S_AXI_HP2_awlock  (hp2_saxi.AWLOCK ),  .S_AXI_HP3_awlock  (hp3_saxi.AWLOCK ), // in 2
  .S_AXI_HP2_awsize  (hp2_saxi.AWSIZE ),  .S_AXI_HP3_awsize  (hp3_saxi.AWSIZE ), // in 3
  .S_AXI_HP2_arprot  (hp2_saxi.ARPROT ),  .S_AXI_HP3_arprot  (hp3_saxi.ARPROT ), // in 3
  .S_AXI_HP2_awprot  (hp2_saxi.AWPROT ),  .S_AXI_HP3_awprot  (hp3_saxi.AWPROT ), // in 3
  .S_AXI_HP2_araddr  (hp2_saxi.ARADDR ),  .S_AXI_HP3_araddr  (hp3_saxi.ARADDR ), // in 32
  .S_AXI_HP2_awaddr  (hp2_saxi.AWADDR ),  .S_AXI_HP3_awaddr  (hp3_saxi.AWADDR ), // in 32
  .S_AXI_HP2_arcache (hp2_saxi.ARCACHE),  .S_AXI_HP3_arcache (hp3_saxi.ARCACHE), // in 4
  .S_AXI_HP2_arlen   (hp2_saxi.ARLEN  ),  .S_AXI_HP3_arlen   (hp3_saxi.ARLEN  ), // in 4
  .S_AXI_HP2_arqos   (hp2_saxi.ARQOS  ),  .S_AXI_HP3_arqos   (hp3_saxi.ARQOS  ), // in 4
  .S_AXI_HP2_awcache (hp2_saxi.AWCACHE),  .S_AXI_HP3_awcache (hp3_saxi.AWCACHE), // in 4
  .S_AXI_HP2_awlen   (hp2_saxi.AWLEN  ),  .S_AXI_HP3_awlen   (hp3_saxi.AWLEN  ), // in 4
  .S_AXI_HP2_awqos   (hp2_saxi.AWQOS  ),  .S_AXI_HP3_awqos   (hp3_saxi.AWQOS  ), // in 4
  .S_AXI_HP2_arid    (hp2_saxi.ARID   ),  .S_AXI_HP3_arid    (hp3_saxi.ARID   ), // in 6
  .S_AXI_HP2_awid    (hp2_saxi.AWID   ),  .S_AXI_HP3_awid    (hp3_saxi.AWID   ), // in 6
  .S_AXI_HP2_wid     (hp2_saxi.WID    ),  .S_AXI_HP3_wid     (hp3_saxi.WID    ), // in 6
  .S_AXI_HP2_wdata   (hp2_saxi.WDATA  ),  .S_AXI_HP3_wdata   (hp3_saxi.WDATA  ), // in 64
  .S_AXI_HP2_wstrb   (hp2_saxi.WSTRB  ),  .S_AXI_HP3_wstrb   (hp3_saxi.WSTRB  )  // in 8
);

// since the PS GP0 port is AXI3 and the local bus is AXI4
assign axi_gp.AWREGION = '0;
assign axi_gp.ARREGION = '0;

endmodule
