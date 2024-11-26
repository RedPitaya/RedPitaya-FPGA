/**
 * $Id: freq_meter.v 961 2014-01-21 11:40:39Z matej.oblak $
 *
 * @brief Module for frequency meter.
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
 * Frequence meter.
 *
 *
 * Generate gate from reference frequency and then count clock cycles of measured clock.
 * To speed up refresh, smaller gates are created.
 * Also implemented measered clock detection.
 * 
 */

module freq_meter #(
  parameter GCL  = 32'd15625000, // Gate counter length - 1/8 of s, 125000000/8
  parameter GCS  =  3            // Gate counter sections (1<<GCS)
)(
  // measured clock
  input                mes_clk_i     ,  // clock
  input                mes_rstn_i    ,  // reset - active low

  // reference clock
  input                ref_clk_i     ,  // clock
  input                ref_rstn_i    ,  // reset - active low

  // result
  output reg [ 32-1:0] freq_o        ,  // @ mes_clk_i
  output reg [ 32-1:0] freq_ref_o       // @ ref_clk_i

);

//---------------------------------------------------------------------------------
//
//  Generate gate

reg  [32-1: 0] ref_cnt   ;
reg            ref_gate  ;

// Create gate from reference
always @(posedge ref_clk_i) begin
if (!ref_rstn_i || (ref_cnt >= GCL))
  ref_cnt <= 32'h1 ;
else
  ref_cnt <= ref_cnt + 32'h1 ;

if (!ref_rstn_i) 
  ref_gate <=  1'b0 ;
else
  ref_gate <= (ref_cnt >= GCL) ? !ref_gate : ref_gate ;
end







//---------------------------------------------------------------------------------
//
//  Counting clock cycles inside gate

(* ASYNC_REG  = "true" *)
reg  [ 3-1: 0] mes_gate_csff ;
reg  [32-1: 0] mes_freq_cnt  ;
reg  [32-1: 0] mes_freq_ltch ;


// Count clock cycles
always @(posedge mes_clk_i)
if (!mes_rstn_i) begin
  mes_gate_csff <=  3'd0 ;
  mes_freq_cnt  <= 32'd0 ;
  mes_freq_ltch <= 32'd0 ;
end else begin
  mes_gate_csff <= {mes_gate_csff[3-2:0], ref_gate};

  if (mes_gate_csff[1])
    mes_freq_cnt <= mes_freq_cnt + 32'd1;
  else
    mes_freq_cnt <= 32'd0 ;

  if (mes_gate_csff[2] && !mes_gate_csff[1]) // end of gate
    mes_freq_ltch <= {mes_freq_cnt[32-1-GCS:0], {GCS{1'b0}} } ; // in Hz
end




//---------------------------------------------------------------------------------
//
//  Synchronize to reference domain

(* ASYNC_REG  = "true" *)
reg  [ 3-1: 0] ref_gate_csff ;
reg  [32-1: 0] ref_freq_ltch ;
reg  [ 3-1: 0] gate_cnt      ;

always @(posedge ref_clk_i) begin
// sync gate
if (!ref_rstn_i)
  ref_gate_csff <=  3'd0 ;
else
  ref_gate_csff <= {ref_gate_csff[3-2:0], mes_gate_csff[2]};

// count gates / detect mes_clk
if (!ref_rstn_i || ((ref_gate_csff[2] && !ref_gate_csff[1]))) // reset || gate from mes_clk
  gate_cnt <=  3'b0 ;
else if (!gate_cnt[2])
  gate_cnt <= (ref_cnt >= GCL) ? (gate_cnt + 3'h1) : gate_cnt ;

// sync value from mes_clk
if (ref_gate_csff[2] && !ref_gate_csff[1]) // end of gate
  ref_freq_ltch <= mes_freq_ltch ; // synchronize

end




//---------------------------------------------------------------------------------
//
//  Output assignments

always @(posedge mes_clk_i)
  freq_o <= mes_freq_ltch ;

always @(posedge ref_clk_i)
  freq_ref_o <= gate_cnt[2] ? 32'h0 : ref_freq_ltch ;




endmodule


