`timescale 1ns / 1ps

module osc_decimator
  #(parameter AXIS_DATA_BITS  = 16,
    parameter CNT_BITS        = 17,
    parameter SHIFT_BITS      = 4)(
  input  wire                       clk,
  input  wire                       rst_n,
  // Slave AXI-S
  input  wire [AXIS_DATA_BITS-1:0]  s_axis_tdata,
  input  wire                       s_axis_tvalid,
  output wire                       s_axis_tready,
  // Master AXI-S
  output reg  [AXIS_DATA_BITS-1:0]  m_axis_tdata,
  output reg                        m_axis_tvalid,
  input  wire                       m_axis_tready,
  // Control
  input  wire                       ctl_rst, 
  // Config
  input  wire                       cfg_avg_en, 
  input  wire [CNT_BITS-1:0]        cfg_dec_factor, 
  input  wire [SHIFT_BITS-1:0]      cfg_dec_rshift 
);

////////////////////////////////////////////////////////////
// Parameters
////////////////////////////////////////////////////////////

localparam ACC_BITS = AXIS_DATA_BITS+CNT_BITS-1;

assign s_axis_tready = 1;


//---------------------------------------------------------------------------------
//  Decimate input data

reg  [ ACC_BITS-1: 0] adc_sum     ;
reg  [ ACC_BITS-1: 0] sum_in      ;
reg  [ ACC_BITS-1: 0] sum_uns     ;
reg  [ ACC_BITS-1: 0] div_uns     ;
reg  [ CNT_BITS-1: 0] adc_dec_cnt ;
reg                   adc_dv      ;
reg                   div_go      ;
wire                  div_ok      ;
reg                   dat_got     ;
reg                   div_dat_got ;
reg  [ ACC_BITS-1: 0] dat_div     ;
wire [ ACC_BITS-1: 0] div_out     ;
reg                   adc_dv_div  ;
reg  [       34-1: 0] sign_sr     ;
reg                   sign_curr   ;


divide #(

   .XDW(ACC_BITS)       ,
   .XDWW(6)             ,
   .YDW(CNT_BITS)       ,
   .PIPE(2)             ,
   .GRAIN(1)            ,
   .RST_ACT_LVL(0)
)
dec_avg_div
(
   .clk_i(clk)          ,
   .rst_i(rst_n)        ,
   .x_i(sum_uns)        ,
   .y_i(cfg_dec_factor) ,
   .dv_i(div_go)        ,
   .q_o(div_out)        ,
   .dv_o(div_ok)
);


always @(posedge clk)
if (rst_n == 1'b0) begin
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
   if(adc_dec_cnt >= cfg_dec_factor && cfg_dec_factor >= 17'd16) begin //save sign and sum 
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

wire dec_valid = (adc_dec_cnt >= cfg_dec_factor);

always @(posedge clk)
if (rst_n == 1'b0 || ctl_rst) begin
   adc_sum   <= 32'h0 ;
   adc_dec_cnt <= 17'h0 ;
   adc_dv      <=  1'b0 ;
end else begin
  if (s_axis_tvalid) begin
    if (dec_valid) begin // start again or arm
      adc_dec_cnt <= 17'h1    ;              
      adc_sum   <= $signed(s_axis_tdata) ;
    end else begin
      adc_dec_cnt <= adc_dec_cnt + 17'h1 ;
      adc_sum   <= $signed(adc_sum) + $signed(s_axis_tdata) ;
    end
  end

   case (cfg_dec_factor & {17{cfg_avg_en}}) // allowed dec factors: 1,2,4,8; if 16 or greater, use divider
      17'h0     : begin m_axis_tdata <= s_axis_tdata;        m_axis_tvalid <= dec_valid;  end // if averaging is disabled
      17'h1     : begin m_axis_tdata <= adc_sum[15+0 :  0];  m_axis_tvalid <= dec_valid;  end
      17'h2     : begin m_axis_tdata <= adc_sum[15+1 :  1];  m_axis_tvalid <= dec_valid;  end
      17'h4     : begin m_axis_tdata <= adc_sum[15+2 :  2];  m_axis_tvalid <= dec_valid;  end
      17'h8     : begin m_axis_tdata <= adc_sum[15+3 :  3];  m_axis_tvalid <= dec_valid;  end
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
      17'd15    : begin m_axis_tdata <= s_axis_tdata;        m_axis_tvalid <= dec_valid;  end // no division for any other decimation factor
      default   : begin m_axis_tdata <= dat_div;             m_axis_tvalid <= adc_dv_div; end
   endcase
end

endmodule