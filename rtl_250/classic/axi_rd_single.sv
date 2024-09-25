/*
* Copyright (c) 2018 Instrumentation Technologies
* All Rights Reserved.
*
* $Id: $
*/


// synopsys translate_off
`timescale 1ns / 1ps
// synopsys translate_on

module axi_rd_single #(
  parameter   DW  =  64          , // data width (8,16,...,1024)
  parameter   DWW =  $clog2(DW/8),
  parameter   AW  =  32          , // address width
  parameter   LW  =   8          , // length width
  parameter   BYTE_SEL = 0       ,
  parameter   FW  = 4       , // address width of FIFO pointers
  parameter   SW  = DW >> 3        // strobe width - 1 bit for every data byte
)
(
   // AXI master signals
   axi_sys_if.s           axi_sys            ,

   // configuration signals
   input                  cfg_clk_i          , // config clock
   input                  cfg_rstn_i         , // config reset

   input       [ AW-1: 0] ctrl_addr_i        , // request start address
   input       [ LW-1: 0] ctrl_size_i        , // request size
   input       [  3-1: 0] ctrl_rsize_i       , // read size (in bytes)
   input                  ctrl_val_i         , // request transfer
   input                  ctrl_clr_i         , // request clear

   // data
   output      [ DW-1: 0] rd_data_o          , // read data @axi_clk
   output                 rd_dval_o          , // read data valid @axi_clk
   input                  rd_drdy_i          , // read data ready @axi_clk

   output                 ctrl_busy_o        , // status @axi_clk
   output reg             ctrl_overflow_o    , // status @axi_clk
   output reg             stat_busy_o          // status @cfg_clk
);



//---------------------------------------------------------------------------------
//
// Read address channel



reg  [ FW-1: 0] wr_pt              ;
reg  [ FW-1: 0] rd_pt              ;
reg  [ FW  : 0] fill_lvl           ;
reg             clear              ;

wire push = ctrl_val_i && !fill_lvl[FW] ;
wire pop ;
wire [ 3*AW-1: 0] fifo_rdr      ;
reg  [ 3*AW-1: 0] fifo[(1<<FW)-1:0]  ;

reg             pop_r;
reg             artransf_r;

reg  [  8-1: 0] req_cnt;

localparam MAX_REQ = 250;

assign pop = (req_cnt < MAX_REQ) && !axi_sys.Rtransfer && axi_sys.rardy && !axi_sys.rvalid && (fill_lvl > 0) && !pop_r;

always @ (posedge axi_sys.clk)
begin
   pop_r <= pop;
   artransf_r <= axi_sys.ARtransfer;
end


// overflow detection & indication
always @ (posedge axi_sys.clk)
begin
   if (!axi_sys.rstn) begin
      req_cnt <= 'h0 ;
   end
   else begin
      if (axi_sys.Rtransfer && !axi_sys.ARtransfer && req_cnt > 0)
         req_cnt <= req_cnt - 1;
      else if (artransf_r && !axi_sys.ARtransfer && !axi_sys.Rtransfer && req_cnt < MAX_REQ)
         req_cnt <= req_cnt + 1;
   end
end


// number of outstanding reads
always @ (posedge axi_sys.clk)
begin
   if (!axi_sys.rstn) begin
      ctrl_overflow_o <= 'h0 ;
   end
   else begin
      ctrl_overflow_o <= fill_lvl[FW] && ctrl_val_i;
   end
end


reg clear_do ;
always @ (posedge axi_sys.clk)
begin
   if (!axi_sys.rstn) begin
      clear    <= 1'h1 ;
      clear_do <= 1'b0 ;
   end
   else begin 
      if (ctrl_clr_i)
         clear_do <= 1'b1 ;
      else if (clear)
         clear_do <= 1'b0 ;

      clear <= clear_do && !axi_sys.rvalid && !pop;
   end
end


assign fifo_rdr      = fifo[rd_pt];
always @ (posedge axi_sys.clk)
begin
   if (clear) begin
      wr_pt <= 4'h0 ;
      rd_pt <= 4'h0 ;
   end
   else begin
      if (push) begin
         fifo[wr_pt]      <= {{AW-3{1'b0}},ctrl_rsize_i,{AW-LW{1'b0}},ctrl_size_i,ctrl_addr_i} ;
         wr_pt            <= wr_pt + {{FW-1{1'b0}},1'b1} ;
      end

      if (pop) begin
         axi_sys.raddr <= fifo_rdr[0*AW +: AW] ;
         axi_sys.rlen  <= fifo_rdr[1*AW +:  8] ;
         axi_sys.rsize <= fifo_rdr[2*AW +:  3] ;
         rd_pt       <= rd_pt + {{FW-1{1'b0}},1'b1} ;
      end
   end
end


always @(posedge axi_sys.clk)
begin
   if (clear) begin
      fill_lvl   <= {FW+1{1'h0}} ;
   end
   else begin
      if (push && !pop)
         fill_lvl <= fill_lvl + {{FW{1'b0}}, 1'h1} ;
      else if(!push && pop)
         fill_lvl <= fill_lvl - {{FW{1'b0}}, 1'h1} ;
   end
end

always @(posedge axi_sys.clk)
begin
   if (clear) begin
      axi_sys.rfixed <= 1'b0 ;
      axi_sys.rvalid <= 1'b0 ;
   end
   else begin
      if (pop)
         axi_sys.rvalid <= 1'b1 ;
      else if (!axi_sys.rardy) begin
         axi_sys.rvalid <= 1'b0 ;
      end
   end
end

//------------------------------------------------------------------------------
// FIFO interface

assign axi_sys.rrdys = rd_drdy_i   ;
assign rd_data_o  = axi_sys.rdata ;
assign rd_dval_o  = axi_sys.rrdym  ;








//------------------------------------------------------------------------------
// IRQ status

reg  [ 1-1: 0] axi_busy  ;

always @(posedge axi_sys.clk)
begin
   if (!axi_sys.rstn) begin
      axi_busy <= 1'b0  ;
   end
   else begin
      axi_busy <= req_cnt >= MAX_REQ ;
   end
end

assign ctrl_busy_o = axi_busy;









//------------------------------------------------------------------------------
// cfg domain

reg [1:0] stat_busy_csff   ;

always @ (posedge cfg_clk_i)
begin
   if (!cfg_rstn_i) begin
      stat_busy_csff   <= 2'h0 ;
      stat_busy_o      <= 1'b0 ;
   end
   else begin
      stat_busy_csff <= {stat_busy_csff[0], axi_busy};
      stat_busy_o    <= stat_busy_csff[1] ;
   end
end











endmodule // axi_rd_fifo
