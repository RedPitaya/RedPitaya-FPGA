/**
 * $Id: freq_meter.v 961 2014-01-21 11:40:39Z matej.oblak $
 *
 * @brief Module for DRP interface.
 *
 * @Author Matej Oblak
 *
 * (c) Red Pitaya  http://www.redpitaya.com
 *
 * This part of code is written in Verilog hardware description language (HDL).
 * Please visit http://en.wikipedia.org/wiki/Verilog
 * for more details on the language used herein.
 */

/**
 * GENERAL DESCRIPTION:
 *
 * Simple control of DRP (Dynamic Reconfiguration Port) interface
 *
 *
 * Generates DRP request and waits for its ackwnoledge
 * 
 */




module drp_ctrl
(
  input                cfg_clk_i       ,
  input                cfg_rstn_i      ,
  input      [ 7-1: 0] cfg_adr_i       ,
  input                cfg_re_i        ,
  input                cfg_we_i        ,
  input      [16-1: 0] cfg_dat_i       ,
  output reg [16-1: 0] cfg_dat_o       ,
  output reg           cfg_ack_o       ,
  output reg           cfg_bsy_o       ,

  output reg [ 7-1: 0] drp_adr_o       ,
  output reg           drp_en_o        ,
  output reg           drp_we_o        ,
  output reg [16-1: 0] drp_dat_o       ,
  input      [16-1: 0] drp_dat_i       ,
  input                drp_rdy_i        
);




localparam SM_IDLE = 4'h0 ;
localparam SM_WAIT = 4'h1 ;
localparam SM_RESP = 4'h2 ;
localparam SM_ACK0 = 4'h3 ;
localparam SM_ACK1 = 4'h4 ;

reg   [ 4-1: 0] sm_state ;

always @(posedge cfg_clk_i) begin
  if (!cfg_rstn_i) begin
    sm_state <= SM_IDLE ;
  end
  else begin
    case (sm_state)
      SM_IDLE : begin
                  if (cfg_re_i || cfg_we_i)     sm_state <=  SM_WAIT ;
                  else                          sm_state <=  SM_IDLE ;
                end
      SM_WAIT : begin
                  if (drp_rdy_i)                sm_state <=  SM_RESP ;
                  else                          sm_state <=  SM_WAIT ;
                end
      SM_RESP : begin
                                                sm_state <=  SM_ACK0 ;
                end
      SM_ACK0 : begin
                                                sm_state <=  SM_ACK1 ;
                end
      SM_ACK1 : begin
                                                sm_state <=  SM_IDLE ;
                end
    endcase
  end
end

// DRP request
always @(posedge cfg_clk_i) begin
  drp_adr_o  <= ((sm_state == SM_IDLE) && (cfg_re_i || cfg_we_i) )   ?  cfg_adr_i :  7'h0 ;
  drp_en_o   <= ((sm_state == SM_IDLE) && (cfg_re_i || cfg_we_i) )   ?       1'b1 :  1'b0 ;
  drp_we_o   <= ((sm_state == SM_IDLE) &&              cfg_we_i  )   ?       1'b1 :  1'b0 ;
  drp_dat_o  <= ((sm_state == SM_IDLE) &&              cfg_we_i  )   ?  cfg_dat_i : 16'h0 ;
end

// DRP response
always @(posedge cfg_clk_i) begin
  cfg_dat_o  <= ((sm_state == SM_WAIT) &&              drp_rdy_i )   ?  drp_dat_i : cfg_dat_o ;
  cfg_ack_o  <= ((sm_state == SM_WAIT) &&              drp_rdy_i )   ?       1'b1 :  1'b0     ;
  cfg_bsy_o  <=  (sm_state != SM_IDLE) ;
end






endmodule

