/**
 * $Id: rp_decim.v 2024-03-15
 *
 * @brief Red Pitaya ADC data decimator
 *
 * @Author Jure Trnovec
 *
 * (c) Red Pitaya  http://www.redpitaya.com
 *
 * This part of code is written in Verilog hardware description language (HDL).
 * Please visit http://en.wikipedia.org/wiki/Verilog
 * for more details on the language used herein.
 */


/*
GENERAL DESCRIPTION:
This module decimates the raw ADC data. 
This data can either be decimated with averaging or not. 
*/
module rp_decim #(
  parameter DW   = 14
)(
   input                adc_clk_i       ,  // ADC clock
   input                adc_rstn_i      ,  // ADC reset - active low

   input      [DW-1: 0] dec_dat_i       ,  // filtered data input
   input      [17-1: 0] set_dec_i       ,  // decimation value
   input                set_hres_en_i     ,  // high-resolution precision enable
   input      [ 3-1: 0] dec_mode_i      ,  // predecoded averaging/output mode
   input                adc_arm_do_i    ,  // trigger armed

   output               dec_val_o       ,  // decimated data valid
   output     [DW-1: 0] dec_dat_o          // decimated data
);

localparam integer HRES_SHL = 4;
localparam signed [31:0] BASE_MAX = 32'sd2047;
localparam signed [31:0] BASE_MIN = -32'sd2048;
localparam signed [31:0] HRES_MAX = 32'sd32767;
localparam signed [31:0] HRES_MIN = -32'sd32768;

localparam [2:0] DEC_MODE_PASS = 3'd0;
localparam [2:0] DEC_MODE_SUM  = 3'd1;
localparam [2:0] DEC_MODE_SHR1 = 3'd2;
localparam [2:0] DEC_MODE_SHR2 = 3'd3;
localparam [2:0] DEC_MODE_SHR3 = 3'd4;
localparam [2:0] DEC_MODE_DIV  = 3'd5;

function [DW-1:0] clamp_dec_out;
   input signed [31:0] dat_i;
   input               hres_en_i;
begin
   if (hres_en_i) begin
      // HRES limits are exactly the signed 16-bit range.  A value fits when
      // every bit above bit 14 is a copy of its sign bit; no wide magnitude
      // comparator or carry chain is needed.
      if (|(dat_i[31:15] ^ {17{dat_i[31]}}))
         clamp_dec_out = dat_i[31] ? HRES_MIN[DW-1:0] : HRES_MAX[DW-1:0];
      else
         clamp_dec_out = dat_i[DW-1:0];
   end else begin
      // BASE limits are exactly the signed 12-bit range.  Overflow is any
      // upper bit that differs from the sign extension of bit 11.
      if (|(dat_i[31:11] ^ {21{dat_i[31]}}))
         clamp_dec_out = dat_i[31] ? BASE_MIN[DW-1:0] : BASE_MAX[DW-1:0];
      else
         clamp_dec_out = dat_i[DW-1:0];
   end
end
endfunction

//---------------------------------------------------------------------------------
//  Decimate input data

reg  [ DW-1: 0] adc_dat     ;
reg  [ 32-1: 0] adc_sum     ;
reg  [ 32-1: 0] sum_in      ;
reg  [ 32-1: 0] sum_uns     ;
reg  [ 17-1: 0] adc_dec_cnt ;
reg             adc_dv      ;
reg             adc_dv_next ;
reg             div_go      ;
wire            div_ok      ;
reg             dat_got     ;
reg             div_dat_got ;
reg  [ 32-1: 0] dat_div     ;
wire [ 32-1: 0] div_out     ;
reg             adc_dv_div  ;
reg  [ 34-1: 0] sign_sr     ;
reg             sign_curr   ;
reg  [ DW-1: 0] adc_dat_next;
wire dec_valid = (adc_dec_cnt >= set_dec_i);
wire hres_active = set_hres_en_i;
wire signed [31:0] dec_dat_base = $signed(dec_dat_i);
wire signed [31:0] dec_dat_hres = hres_active ? (dec_dat_base <<< HRES_SHL) : dec_dat_base;
wire signed [31:0] adc_sum_s = $signed(adc_sum);
wire signed [31:0] dat_div_s = $signed(dat_div);
wire [DW-1:0] adc_dat_pass = clamp_dec_out(dec_dat_hres, hres_active);
wire [DW-1:0] adc_dat_sum  = clamp_dec_out(adc_sum_s, hres_active);
wire [DW-1:0] adc_dat_shr1 = clamp_dec_out(adc_sum_s >>> 1, hres_active);
wire [DW-1:0] adc_dat_shr2 = clamp_dec_out(adc_sum_s >>> 2, hres_active);
wire [DW-1:0] adc_dat_shr3 = clamp_dec_out(adc_sum_s >>> 3, hres_active);
wire [DW-1:0] adc_dat_div  = clamp_dec_out(dat_div_s, hres_active);

// Saturate each candidate before selecting the active decimation mode.  This
// keeps the mode-select path out of the wide saturation reduction tree while
// preserving the selected value and the existing register latency.
always @* begin
   case (dec_mode_i)
      DEC_MODE_SUM  : begin adc_dat_next = adc_dat_sum;  adc_dv_next = dec_valid;  end
      DEC_MODE_SHR1 : begin adc_dat_next = adc_dat_shr1; adc_dv_next = dec_valid;  end
      DEC_MODE_SHR2 : begin adc_dat_next = adc_dat_shr2; adc_dv_next = dec_valid;  end
      DEC_MODE_SHR3 : begin adc_dat_next = adc_dat_shr3; adc_dv_next = dec_valid;  end
      DEC_MODE_DIV  : begin adc_dat_next = adc_dat_div;  adc_dv_next = adc_dv_div; end
      default       : begin adc_dat_next = adc_dat_pass; adc_dv_next = dec_valid;  end
   endcase
end



divide #(

   .XDW(32)          , // mod(XDW, PIPE*GRAIN) == 0  !!!!!!!! x data width
   .XDWW(6)          , // ceil(log2(XDW)) x data width, width
   .YDW(17)          , //y data width
   .PIPE(2)          , // how many parallel pipes (1 is minimal)
   .GRAIN(1)         ,
   .RST_ACT_LVL(0)     //positive or negative reset
)
dec_avg_div
(
   .clk_i(adc_clk_i) ,
   .rst_i(adc_rstn_i),
   .x_i(sum_uns)   , // numerator (dividend) [ XDW-1: 0]
   .y_i(set_dec_i)     , // denominator (divisor)[ YDW-1: 0]   // Both input values must be unsigned !!!
   .dv_i(div_go)     , //ready to start division
   .q_o(div_out)   , // quotient [ XDW-1: 0]
   .dv_o(div_ok)     // result available
);

always @(posedge adc_clk_i)
if (adc_rstn_i == 1'b0) begin
   div_go      <= 1'b0;
   dat_got     <= 1'b0;
   adc_dv_div  <= 1'b0;
   div_dat_got <= 1'b0;
   sum_uns   <= 32'h0;
   sum_in    <= 32'h0;
   dat_div   <= 32'h0;
   sign_curr <= 1'b0;
   sign_sr   <= 34'b0;
end else begin
   sign_sr<={sign_sr[34-2:0],sign_curr}; // sign shift register
   if(adc_dec_cnt >= set_dec_i && set_dec_i >= 17'd16) begin //save sign and sum 
      sign_curr <= adc_sum[32-1];
      sum_in    <= adc_sum;
      dat_got     <= 1'b1; //data was acquired
   end else
      dat_got     <= 1'b0;  
        
   if (dat_got) begin
      div_go <= 1'b1; // when input data is unsigned, start division
      if (sign_curr) //handle signs 
         sum_uns <= -sum_in; // division has about 33 cycles of latency, new data may be fed every 16 cycles
      else 
         sum_uns <=  sum_in;
   end else
      div_go <= 1'b0;

   if (div_ok) begin // division finished
      div_dat_got <= 1'b1;    
   end else
      div_dat_got <= 1'b0;
   
   if(div_dat_got) begin
      adc_dv_div<=1'b1;
      if (sign_sr[34-1]) // handle signs after division
         dat_div <= -div_out;
      else 
         dat_div <=  div_out;
      
   end else
      adc_dv_div <= 1'b0;
end

always @(posedge adc_clk_i)
if (adc_rstn_i == 1'b0) begin
   adc_sum   <= 32'h0 ;
   adc_dec_cnt <= 17'h0 ;
   adc_dv      <=  1'b0 ;
   adc_dat     <= {DW{1'b0}};
end else begin
   if (dec_valid || adc_arm_do_i) begin // start again or arm
      adc_dec_cnt <= 17'h1    ;              
      adc_sum   <= $signed(dec_dat_hres) ;
   end else begin
      adc_dec_cnt <= adc_dec_cnt + 17'h1 ;
      adc_sum   <= $signed(adc_sum) + $signed(dec_dat_hres) ;
   end

   adc_dv  <= adc_dv_next;
   adc_dat <= adc_dat_next;
end

assign dec_dat_o = adc_dat;
assign dec_val_o = adc_dv;

endmodule
