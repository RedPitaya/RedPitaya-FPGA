/*
* Copyright (c) 2015 Instrumentation Technologies
* All Rights Reserved.
*
* $Id: $
*/


// synopsys translate_off
`timescale 1ns / 1ps
// synopsys translate_on

module axi_wr_fifo #(
  parameter   DW  =  64      , // data width (8,16,...,1024)
  parameter   AW  =  32      , // address width
  parameter   LW  =   8      , // length width
  parameter   FW  =   5      , // address width of FIFO pointers
  parameter   BYTE_SEL = 0   ,
  parameter   SW  = DW >> 3    // strobe width - 1 bit for every data byte
)
(
   // global signals
   input                  axi_clk_i          , // global clock
   input                  axi_rstn_i         , // global reset

   // Connection to AXI master
   output reg  [ AW-1: 0] axi_waddr_o        , // write address
   output reg  [ DW-1: 0] axi_wdata_o        , // write data
   output reg  [ SW-1: 0] axi_wsel_o         , // write byte select
   output reg  [  3-1: 0] axi_wsize_o        , // write size
   output reg             axi_wvalid_o       , // write data valid
   output reg  [  4-1: 0] axi_wlen_o         , // write burst length
   output reg             axi_wfixed_o       , // write burst type (fixed / incremental)
   input                  axi_werr_i         , // write error
   input                  axi_wrdy_i         , // write ready

   // data and configuration
   input       [ DW-1: 0] wr_data_i          , // write data
   input       [ SW-1: 0] wr_byte_val_i      ,
   input       [  3-1: 0] wr_size_i          , // write size
   input                  wr_val_i           , // write data valid
   input       [ AW-1: 0] ctrl_start_addr_i  , // range start address
   input       [ AW-1: 0] ctrl_stop_addr_i   , // range stop address
   input       [  4-1: 0] ctrl_trig_size_i   , // trigger level
   input                  ctrl_wrap_i        , // start from begining when reached stop
   input                  ctrl_clr_i         , // clear / flush
   output reg             stat_overflow_o    , // overflow indicator
   output      [ AW-1: 0] stat_cur_addr_o    , // current address
   output reg             stat_write_data_o    // write data indicator
);



//---------------------------------------------------------------------------------
//
// Write address channel


reg  [ FW-1: 0] wr_pt              ;
reg  [ FW-1: 0] rd_pt              ;
reg  [ FW  : 0] fill_lvl           ;
reg             data_in_reg        ;
reg             clear              ;
reg  [  4-1: 0] dat_cnt            ;
reg  [ AW  : 0] next_address       ;
localparam integer WORD_AW = AW - 2;
reg  [WORD_AW:0] stop_distance     ;
reg  [WORD_AW:0] wrap_stop_distance;
reg                address_in_range;
reg                wrap_next_in_range;
reg             fifo_flush         ;
reg  [ AW-1: 0] sys_start_addr_r   ;
reg  [ AW-1: 0] sys_stop_addr_r    ;
reg  [  4-1: 0] sys_trig_size_r    ;

wire push = wr_val_i && !fill_lvl[FW] ;
wire pop ;
wire new_burst ;
wire [    SW-1: 0] byte_selector ;
wire [ DW+SW+2: 0] fifo_rdr      ;
reg  [ DW+SW+2: 0] fifo[(1<<FW)-1:0]  ;


// overflow detection & indication
always @ (posedge axi_clk_i)
begin
   if (!axi_rstn_i) begin
      stat_overflow_o <= 'h0 ;
   end
   else begin
      stat_overflow_o <= fill_lvl[FW] && wr_val_i;
   end
end

reg clear_do ;
always @ (posedge axi_clk_i)
begin
   if (!axi_rstn_i) begin
      clear    <= 1'h1 ;
      clear_do <= 1'b0 ;
   end
   else begin 
      if (ctrl_clr_i)
         clear_do <= 1'b1 ;
      else if (clear)
         clear_do <= 1'b0 ;

      clear <= clear_do && !axi_wvalid_o && !new_burst;
   end
end


assign byte_selector = (BYTE_SEL == 1) ? wr_byte_val_i : {SW{1'b1}};
assign fifo_rdr      = fifo[rd_pt];
always @ (posedge axi_clk_i)
begin
   if (clear) begin
      wr_pt <= 4'h0 ;
      rd_pt <= 4'h0 ;
   end
   else begin
      if (push) begin
         fifo[wr_pt]      <= {wr_size_i, byte_selector, wr_data_i} ;
         wr_pt            <= wr_pt + {{FW-1{1'b0}},1'b1} ;
      end

      if (pop) begin
         axi_wdata_o <= fifo_rdr[ 0    +: DW] ;
         axi_wsel_o  <= fifo_rdr[DW    +: SW] ;
         axi_wsize_o <= fifo_rdr[SW+DW +:  3] ;
         rd_pt       <= rd_pt + {{FW-1{1'b0}},1'b1} ;
      end
   end
end



always @(posedge axi_clk_i)
begin
   if (!axi_rstn_i) begin
      data_in_reg <= 'h0 ;
   end
   else begin
      if (pop)
         data_in_reg <= 1'b1 ;
      else if ((axi_wrdy_i && axi_wvalid_o) || clear)
         data_in_reg <= 1'b0 ;
   end
end


wire fifo_flush_cond = |fill_lvl && !wr_val_i && !dat_cnt[3:1];

always @(posedge axi_clk_i)
begin
   if (clear) begin
      fill_lvl   <= {FW+1{1'h0}} ;
      fifo_flush <= 1'h0 ;
   end
   else begin
      if (push && !pop)
         fill_lvl <= fill_lvl + {{FW{1'b0}}, 1'h1} ;
      else if(!push && pop)
         fill_lvl <= fill_lvl - {{FW{1'b0}}, 1'h1} ;

      if (fifo_flush_cond)
         fifo_flush <= 1'b1 ;
      else if (axi_wrdy_i)
         fifo_flush <= 1'b0 ;
   end
end










wire [8:0] next_end_address = next_address[10:3] + fill_lvl;

// Registered distance from next_address to the inclusive stop address, in
// 64-bit words.  Keeping it in lockstep with next_address removes the
// address-wide subtraction from burst-length generation.
wire                 stop_before_next = stop_distance[WORD_AW];
wire                 stop_distance_big = |stop_distance[WORD_AW-1:FW+1];
wire [FW:0]          stop_distance_low = stop_distance[FW:0];

// These preserve all three original relations, including exact equality:
//   fill_lt_stop_distance == boundary_condition[AW+1]
//   fill_gt_stop_distance == next_stop_address[AW]
wire fill_gt_stop_distance = stop_before_next
                           || (!stop_distance_big && (fill_lvl > stop_distance_low));
wire fill_lt_stop_distance = !stop_before_next
                           && (stop_distance_big || (fill_lvl < stop_distance_low));
wire page_boundary_cross = next_end_address[8];

// Calculate all short burst-length candidates in parallel.  Only the final
// selection depends on the boundary flags.
wire [3:0] page_burst_len = 4'hF - next_address[6:3];
wire [3:0] stop_burst_len = sys_stop_addr_r[6:3] - next_address[6:3];
wire [3:0] fifo_burst_len = (fifo_flush || fifo_flush_cond)
                          ? fill_lvl[3:0] - 4'h1 : fill_lvl[3:0];
wire       boundary_cross = page_boundary_cross || fill_gt_stop_distance;
wire [3:0] next_burst_len = boundary_cross
                          ? (fill_lt_stop_distance ? page_burst_len : stop_burst_len)
                          : (|fill_lvl[FW:4] ? 4'hF : fifo_burst_len);

// prevents data to be trapped in output register
reg  single_burst    ;
reg  single_burst_r  ;
wire single_burst_posedge = !single_burst_r && single_burst;

always @(posedge axi_clk_i)
begin
   if (clear) begin
      single_burst   <= 'h0 ;
      single_burst_r <= 'h0 ;
   end
   else begin
      single_burst   <= (!fill_lvl && !fifo_flush && !dat_cnt && data_in_reg) ;
      single_burst_r <= single_burst ;
   end
end


assign new_burst = (((fifo_flush && axi_wrdy_i) || (fill_lvl >= {{FW-4{1'b0}},sys_trig_size_r})) && !dat_cnt && |fill_lvl 
                 || single_burst_posedge)
                 && !clear_do;

always @(posedge axi_clk_i)
begin
   if (clear) begin
      dat_cnt      <= 4'h0 ;
      axi_wfixed_o <= 1'b0 ;
      axi_wlen_o   <= 4'h0 ;
   end
   else begin
      if (new_burst && address_in_range) begin
         dat_cnt    <= next_burst_len;
         axi_wlen_o <= next_burst_len;
      end
      else if (axi_wrdy_i && axi_wvalid_o && dat_cnt) begin
         dat_cnt    <= dat_cnt    - 4'h1;
         axi_wlen_o <= axi_wlen_o - 4'h1;
      end
   end
end


assign pop =  (!data_in_reg && fill_lvl) || ((|dat_cnt || (new_burst && axi_wvalid_o)) 
            && axi_wrdy_i && axi_wvalid_o && fill_lvl) ;

always @(posedge axi_clk_i)
begin
   if (clear) begin
      axi_wvalid_o     <= 1'h0                     ;
      axi_waddr_o      <= ctrl_start_addr_i        ;
      next_address     <= {1'b0,ctrl_start_addr_i} ;
      stop_distance    <= {2'b0,ctrl_stop_addr_i[AW-1:3]}
                        - {2'b0,ctrl_start_addr_i[AW-1:3]} ;
      wrap_stop_distance <= {2'b0,ctrl_stop_addr_i[AW-1:3]}
                          - {2'b0,ctrl_start_addr_i[AW-1:3]} - 1'b1 ;
      address_in_range <= ({1'b0,ctrl_start_addr_i} <= {1'b0,ctrl_stop_addr_i});
      wrap_next_in_range <= ({1'b0,ctrl_start_addr_i} + DW/8
                             <= {1'b0,ctrl_stop_addr_i});
      sys_start_addr_r <= ctrl_start_addr_i        ;
      sys_stop_addr_r  <= ctrl_stop_addr_i         ;
      sys_trig_size_r  <= ctrl_trig_size_i         ;
   end
   else begin
      if (address_in_range && // still in address range
          ( (new_burst && axi_wrdy_i) || (|dat_cnt && axi_wrdy_i && fill_lvl) ) ) begin  //new burst || still data in package
         axi_wvalid_o <= 1'h1 ;
         next_address <= next_address + DW/8  ; // in bytes
         stop_distance <= stop_distance - 1'b1;
         address_in_range <= !stop_before_next
                          && ((stop_distance > 1)
                              || ((stop_distance == 1)
                                  && (next_address[2:0] <= sys_stop_addr_r[2:0])));
         axi_waddr_o  <= next_address[AW-1:0] ;
      end
      else if (ctrl_wrap_i && new_burst && (axi_waddr_o==sys_stop_addr_r)) begin //wrap around
         axi_wvalid_o <= 1'h1 ;
         next_address <= {1'b0,sys_start_addr_r} + DW/8  ; // in bytes
         stop_distance <= wrap_stop_distance;
         address_in_range <= wrap_next_in_range;
         axi_waddr_o  <= sys_start_addr_r ;
      end
      else if (axi_wrdy_i) begin
         axi_wvalid_o <= 1'h0 ;
      end
   end
end


// write data indication
always @(posedge axi_clk_i)
begin
   if (!axi_rstn_i) begin
      stat_write_data_o <= 'h0 ;
   end
   else begin
      stat_write_data_o <= address_in_range;
   end
end

assign stat_cur_addr_o = (ctrl_wrap_i && (axi_waddr_o==sys_stop_addr_r)) ? sys_start_addr_r : next_address ; // current address



endmodule // axi_wr_fifo
