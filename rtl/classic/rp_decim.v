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
   input                set_avg_en_i    ,  // averaging enable
   input                adc_arm_do_i    ,  // trigger armed

   output               dec_val_o       ,  // decimated data valid
   output     [DW-1: 0] dec_dat_o          // decimated data
);

//---------------------------------------------------------------------------------
//  Decimate input data

reg  [ DW-1: 0] adc_dat     ;
reg  [ 32-1: 0] adc_sum     ;
reg  [ 32-1: 0] sum_in      ;
reg  [ 32-1: 0] sum_uns     ;
reg  [ 32-1: 0] div_uns     ;
reg  [ 17-1: 0] adc_dec_cnt ;
reg             adc_dv      ;
reg             div_go      ;
wire            div_ok      ;
reg             dat_got     ;
reg             div_dat_got ;
reg  [ 32-1: 0] dat_div     ;
wire [ 32-1: 0] div_out     ;
reg             adc_dv_div  ;
reg  [ 34-1: 0] sign_sr     ;
reg             sign_curr   ;



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
   div_uns   <= 32'h0;
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
      div_uns   <= div_out; //get unsigned output data  
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

wire dec_valid = (adc_dec_cnt >= set_dec_i);

always @(posedge adc_clk_i)
if (adc_rstn_i == 1'b0) begin
   adc_sum   <= 32'h0 ;
   adc_dec_cnt <= 17'h0 ;
   adc_dv      <=  1'b0 ;
end else begin
   if (dec_valid || adc_arm_do_i) begin // start again or arm
      adc_dec_cnt <= 17'h1    ;              
      adc_sum   <= $signed(dec_dat_i) ;
   end else begin
      adc_dec_cnt <= adc_dec_cnt + 17'h1 ;
      adc_sum   <= $signed(adc_sum) + $signed(dec_dat_i) ;
   end

   case (set_dec_i & {17{set_avg_en_i}}) // allowed dec factors: 1,2,4,8; if 16 or greater, use divider
      17'h0     : begin adc_dat <= dec_dat_i;          adc_dv <= dec_valid;  end // if averaging is disabled
      17'h1     : begin adc_dat <= adc_sum[15+0 :  0]; adc_dv <= dec_valid;  end
      17'h2     : begin adc_dat <= adc_sum[15+1 :  1]; adc_dv <= dec_valid;  end
      17'h4     : begin adc_dat <= adc_sum[15+2 :  2]; adc_dv <= dec_valid;  end
      17'h8     : begin adc_dat <= adc_sum[15+3 :  3]; adc_dv <= dec_valid;  end
      17'd3, 
      17'd5, 
      17'd6,
      17'd7, 
      17'd9, 
      17'd10, 
      17'd11, 
      17'd12, 
      17'd13, 
      17'd14, 
      17'd15    : begin adc_dat <= dec_dat_i; adc_dv <= dec_valid;  end // no division for any other decimation factor
      default   : begin adc_dat <= dat_div;   adc_dv <= adc_dv_div; end
   endcase
end

assign dec_dat_o = adc_dat;
assign dec_val_o = adc_dv;

endmodule
