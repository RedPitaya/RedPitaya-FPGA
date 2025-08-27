/*
A simple AXI slave interface that creates a read burst.
Request and data FIFOs must be external. 
*/


// synopsys translate_off
`timescale 1ns / 1ps
// synopsys translate_on

module axi_rd_burst #(
  parameter   DW  =  64          , // data width (8,16,...,1024)
  parameter   DWB =  DW/8        , // data width in bytes
  parameter   DWW =  $clog2(DWB),
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

   // data
   output reg  [ DW-1: 0] rd_data_o          , // read data @axi_clk
   output reg  [ AW-1: 0] rd_addr_o          , // read data @axi_clk
   output reg             rd_dval_o          , // read data valid @axi_clk
   input                  rd_drdy_i          , // read data ready @axi_clk

   output      [ 32-1: 0] diags_o          , // read data @axi_clk


   output reg             ctrl_busy_o        , // status @axi_clk
   output reg             stat_busy_o          // status @cfg_clk
);



//---------------------------------------------------------------------------------
//
// Read address channel


reg  [  1-1: 0] axi_busy  ;
reg  [ LW-1: 0] burst_cnt = 'h0;

// busy indicator
always @ (posedge axi_sys.clk)
begin
   if (ctrl_val_i)
      burst_cnt <= ctrl_size_i;
   else if (axi_sys.Rtransfer && burst_cnt > 0)
      burst_cnt <= burst_cnt - 1;
end

always @ (posedge axi_sys.clk)
begin
   if (ctrl_val_i)
      rd_addr_o <= ctrl_addr_i;
   else if (rd_dval_o)
      rd_addr_o <= rd_addr_o + DWB;
end

always @ (posedge axi_sys.clk)
begin
   axi_sys.rfixed <= 1'b0 ;
   if (ctrl_val_i) begin
      axi_sys.raddr <= ctrl_addr_i  ;
      axi_sys.rlen  <= ctrl_size_i  ;
      axi_sys.rsize <= ctrl_rsize_i ;
   end
end

always @(posedge axi_sys.clk)
begin
   if (!axi_sys.rstn) begin
      axi_sys.rvalid <= 1'b0 ;
   end
   else begin
      if (ctrl_val_i)
         axi_sys.rvalid <= 1'b1 ;
      else if (axi_sys.rardy) begin
         axi_sys.rvalid <= 1'b0 ;
      end
   end
end

//------------------------------------------------------------------------------
// FIFO interface

assign axi_sys.rrdys = rd_drdy_i       ;

always @(posedge axi_sys.clk)
begin
   rd_data_o  <= axi_sys.rdata ;
   rd_dval_o  <= axi_sys.Rtransfer  ;
end





//------------------------------------------------------------------------------
// IRQ status

always @(posedge axi_sys.clk)
begin
   ctrl_busy_o <= axi_busy;
   if (!axi_sys.rstn) begin
      axi_busy <= 1'b0  ;
   end
   else begin
      if (ctrl_val_i)
         axi_busy <= 1'b1;
      else if (burst_cnt == 0 && axi_sys.Rtransfer)
         axi_busy <= 1'b0;
   end
end










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
