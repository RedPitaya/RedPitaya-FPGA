/*
* Copyright (c) 2018 Instrumentation Technologies
* All Rights Reserved.
*
* $Id: $
*/


// synopsys translate_off
`timescale 1ns / 1ps
// synopsys translate_on

module axi_rd_fifo #(
  parameter   DW  =  64          , // data width (8,16,...,1024)
  parameter   DWW =  $clog2(DW/8),
  parameter   AW  =  32          , // address width
  parameter   LW  =   8          , // length width
//  parameter   FW  =   5          , // address width of FIFO pointers
  parameter   FW  = LW + 1       , // address width of FIFO pointers
  parameter   BW  = (LW >= 6) ? 6 : LW ,  // length is max 4k
  parameter   SW  = DW >> 3        // strobe width - 1 bit for every data byte
)
(
   // AXI master signals
   input                  axi_clk_i          , // axi clock
   input                  axi_rstn_i         , // axi reset

   output reg  [ AW-1: 0] axi_raddr_o        , // read address
   input                  axi_rardy_i        , // read address ready
   output      [ LW-1: 0] axi_rlen_o         , // read burst length
   output reg             axi_rfixed_o       , // read burst type (fixed / incremental)
   output reg             axi_rvalid_o       , // read address valid
   input       [ DW-1: 0] axi_rdata_i        , // read data
   output                 axi_rrdy_o         , // read ready to receive data 
   input                  axi_rrdy_i         , // read data is ready
   input                  axi_rerr_i         , // read error

   // data
   output      [ DW-1: 0] rd_data_o          , // read data @axi_clk
   output                 rd_dval_o          , // read data valid @axi_clk
   input                  rd_drdy_i          , // read data ready @axi_clk

   // write pointer
   input       [ AW-1: 0] wbuf_adr_i         , // write address
   input       [ LW-1: 0] wbuf_lng_i         , // write length
   input                  wbuf_act_i         , // write active

   // configuration signals
   input                  cfg_clk_i          , // config clock
   input                  cfg_rstn_i         , // config reset

   input       [ AW-1: 0] ctrl_msk_i         , // address mask
   input       [ AW-1: 0] ctrl_addr_i        , // request start address
   input       [ AW-1: 0] ctrl_size_i        , // request size
   input                  ctrl_start_i       , // request transfer
   input                  ctrl_clr_i         , // request clear

   output reg             stat_ovrrun_o      , // status @cfg_clk
   output reg             stat_busy_o          // status @cfg_clk
);



//---------------------------------------------------------------------------------
//
// Read address channel

reg             clear    ;
reg             start    ;
reg  [ LW-1: 0] dat_cnt  ;
reg  [ AW-1: 0] mem_cnt  ;
reg  [  2-1: 0] overrun  ;

wire new_burst ;


reg [2:0] start_csff ;
reg       start_do   ;
always @ (posedge axi_clk_i)
begin
   if (!axi_rstn_i) begin
      start_csff <= 3'h0;
      start_do   <= 1'b0 ;
   end
   else begin 
      start_csff <= {start_csff[1:0], ctrl_start_i};

      if (start_csff[1] ^ start_csff[2])
         start_do <= 1'b1 ;
      else if (start || clear)
         start_do <= 1'b0 ;

      start <= start_do && new_burst ;
   end
end

reg [2:0] clear_csff ;
reg       clear_do   ;
always @ (posedge axi_clk_i)
begin
   if (!axi_rstn_i) begin
      clear_csff <= 3'h7 ;
      clear_do   <= 1'b1 ;
      clear      <= 1'h1 ;
   end
   else begin 
      clear_csff <= {clear_csff[1:0], ctrl_clr_i};

      if (clear_csff[1]  ^ clear_csff[2])
         clear_do <= 1'b1 ;
      else if (start_csff[1] ^ start_csff[2]) // clear
         clear_do <= 1'b0 ;

      clear <= clear_do && !axi_rvalid_o && !new_burst;
   end
end



reg [ AW-1: 0] wbuf_adr ;
reg            wbuf_act ;
always @ (posedge axi_clk_i) begin
  /*if (wbuf_act_i)*/  wbuf_adr <= wbuf_adr_i + {wbuf_lng_i+1,{DWW{1'b0}}} ;
  wbuf_act <= wbuf_act_i ;
end




wire [AW  :0] mem_diff = (wbuf_adr - axi_raddr_o) ; // overwrite?
//wire [AW  :0] mem_size =  mem_diff & ctrl_msk_i ; // available data
reg  [AW  :0] mem_size ;
wire [AW  :0] mem_req  = (mem_size < mem_cnt) ? mem_size : mem_cnt ; // who is smaller

wire [AW  :0] next_end_address   = axi_raddr_o[11: 0] + mem_req ; // to where we have data - 4k boundary

wire [2   :0] boundary_cross     = {1'b0, |next_end_address[AW:12], 1'b0} ;

// prevents data to be trapped in output register
reg  single_burst    ;
reg  single_burst_r  ;
wire single_burst_posedge = !single_burst_r && single_burst;

reg aa;
reg aaa;
reg bb;
reg bbb;
reg cc;
reg ccc;
reg dd;
always @(posedge axi_clk_i)
begin
   if (clear) begin
      single_burst   <= 'h0 ;
      single_burst_r <= 'h0 ;
   end
   else begin
      single_burst   <= (1'b0 && !dat_cnt) ;
      single_burst_r <= single_burst ;
   end

   if (start_do)
     dd <= 1'b1 ;
   else
     dd <= (dd || (axi_rrdy_i && axi_rrdy_o && !dat_cnt)) && !new_burst ;


  mem_size <= mem_diff & ctrl_msk_i ; // available data

  bb <= (axi_rrdy_i && axi_rrdy_o) && !dat_cnt; // last data read
  bbb <=  bb;
  cc <=  wbuf_act && dd ; // new data available
  ccc <=  cc;
  aa <= (start_do || (|mem_cnt && bbb) || (|mem_cnt && ccc)) ;
  aaa <= aa;
  
end


assign new_burst = (aaa && axi_rardy_i && !dat_cnt && |mem_size ) && !clear_do;



always @(posedge axi_clk_i)
begin
   if (!axi_rstn_i || clear_do) begin
      dat_cnt      <= {LW{1'h0}} ;
      axi_rfixed_o <= 1'b0 ;
   end
   else if (start_do) begin
      dat_cnt      <= {LW{1'h0}} ;
      axi_rfixed_o <= 1'b0 ;
   end
   else begin
      if (new_burst) begin
         if (!boundary_cross[1:0]) begin  //enough space to stop address
            dat_cnt  <= mem_req[LW+DWW-1:DWW] - 1 ;
         end
         else if (boundary_cross[1]) begin // 4kb boundary
            dat_cnt  <= {12-DWW{1'b1}} - axi_raddr_o[11:  DWW];
         end
         else begin
            dat_cnt  <= dat_cnt - 4'h1;
         end
      end
      else if (axi_rrdy_i && axi_rrdy_o && |dat_cnt) begin
         dat_cnt  <= dat_cnt - 4'h1;
      end
   end
end

assign axi_rlen_o = dat_cnt ;



always @(posedge axi_clk_i)
begin

   if (!axi_rstn_i || clear_do) begin
      axi_rvalid_o  <=  1'h0  ;
      axi_raddr_o   <= 32'h0  ;
      mem_cnt       <= 32'h0  ;
      overrun       <=  2'h0  ;
   end
   else if (start_do) begin
      axi_rvalid_o  <= 1'h0        ;
      axi_raddr_o   <= ctrl_addr_i ;
      mem_cnt       <= ctrl_size_i ;
      overrun       <= 2'h0        ;
   end
   else begin

      if (axi_rrdy_i && axi_rrdy_o) begin  // counting readed data
         axi_raddr_o  <= ((axi_raddr_o + DW/8) & ctrl_msk_i) | (axi_raddr_o & ~ctrl_msk_i) ;

         mem_cnt      <= mem_cnt - DW/8 ;
      end

      if (wbuf_act)
        overrun[0] <= mem_diff[AW] ; // wr pointer behind
      if (wbuf_act)
        overrun[1] <= overrun[1] || (overrun[0] && !mem_diff[AW]) ; // latch || write pointer in front


      if (new_burst)
         axi_rvalid_o <= 1'h1 ;
      else if (axi_rardy_i)
         axi_rvalid_o <= 1'h0 ;

   end
end













//------------------------------------------------------------------------------
// FIFO interface

assign axi_rrdy_o = rd_drdy_i   ;
assign rd_data_o  = axi_rdata_i ;
assign rd_dval_o  = axi_rrdy_i  ;








//------------------------------------------------------------------------------
// IRQ status

reg  [ 1-1: 0] axi_busy  ;

always @(posedge axi_clk_i)
begin
   if (!axi_rstn_i) begin
      axi_busy <= 1'b0  ;
   end
   else begin
      axi_busy <= |mem_cnt ;
   end
end










//------------------------------------------------------------------------------
// cfg domain

reg [1:0] stat_ovrrun_csff ;
reg [1:0] stat_busy_csff   ;

always @ (posedge cfg_clk_i)
begin
   if (!cfg_rstn_i) begin
      stat_ovrrun_csff <= 2'h0 ;
      stat_ovrrun_o    <= 1'b0 ;
      stat_busy_csff   <= 2'h0 ;
      stat_busy_o      <= 1'b0 ;
   end
   else begin
      stat_ovrrun_csff <= {stat_ovrrun_csff[0], overrun[1]};
      stat_ovrrun_o    <= stat_ovrrun_csff[1] ;

      stat_busy_csff <= {stat_busy_csff[0], axi_busy};
      stat_busy_o    <= stat_busy_csff[1] ;
   end
end











endmodule // axi_rd_fifo
