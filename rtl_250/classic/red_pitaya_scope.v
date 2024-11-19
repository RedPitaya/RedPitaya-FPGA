/**
 * $Id: red_pitaya_scope.v 965 2014-01-24 13:39:56Z matej.oblak $
 *
 * @brief Red Pitaya oscilloscope application, used for capturing ADC data
 *        into BRAMs, which can be later read by SW.
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
 * This is simple data aquisition module, primerly used for scilloscope 
 * application. It consists from three main parts.
 *
 *
 *                /-----------\            /-----\
 *   ADC CHA ---> | AVG & DEC | ---------> | BUF | --->  SW
 *                \-----------/     |      \-----/
 *                                  ˇ         ^
 *                              /------\      |
 *   ext trigger -------------> | TRIG | -----+
 *                              \------/      |
 *                                  ^         ˇ
 *                /-----------\     |      /-----\
 *   ADC CHB ---> | AVG & DEC | ---------> | BUF | --->  SW
 *                \-----------/            \-----/ 
 *
 *
 * Input data is optionaly averaged and decimated via average filter.
 *
 * Trigger section makes triggers from input ADC data or external digital 
 * signal. To make trigger from analog signal schmitt trigger is used, external
 * trigger goes first over debouncer, which is separate for pos. and neg. edge.
 *
 * Data capture buffer is realized with BRAM. Writing into ram is done with 
 * arm/trig logic. With adc_arm_do signal (SW) writing is enabled, this is active
 * until trigger arrives and adc_dly_cnt counts to zero. Value adc_wp_trig
 * serves as pointer which shows when trigger arrived. This is used to show
 * pre-trigger data.
 * 
 */

module red_pitaya_scope #(
  parameter RSZ = 14  // RAM size 2^RSZ
)(
   // ADC
   input                 adc_clk_i       ,  // ADC clock
   input                 adc_clk2d_i     ,  // ADC clock divided
   input                 adc_rstn_i      ,  // ADC reset - active low
   input      [ 12-1: 0] adc_a_i         ,  // ADC data CHA
   input      [ 12-1: 0] adc_b_i         ,  // ADC data CHB
   // trigger sources
   input                 trig_ext_i      ,  // external trigger
   input                 trig_asg_i      ,  // ASG trigger
   output                daisy_trig_o    ,  // trigger for daisy chaining

   // AXI0 master
   output                axi0_clk_o      ,  // global clock
   output                axi0_rstn_o     ,  // global reset
   output     [ 32-1: 0] axi0_waddr_o    ,  // system write address
   output     [ 64-1: 0] axi0_wdata_o    ,  // system write data
   output     [  8-1: 0] axi0_wsel_o     ,  // system write byte select
   output                axi0_wvalid_o   ,  // system write data valid
   output     [  4-1: 0] axi0_wlen_o     ,  // system write burst length
   output                axi0_wfixed_o   ,  // system write burst type (fixed / incremental)
   input                 axi0_werr_i     ,  // system write error
   input                 axi0_wrdy_i     ,  // system write ready

   // AXI1 master
   output                axi1_clk_o      ,  // global clock
   output                axi1_rstn_o     ,  // global reset
   output     [ 32-1: 0] axi1_waddr_o    ,  // system write address
   output     [ 64-1: 0] axi1_wdata_o    ,  // system write data
   output     [  8-1: 0] axi1_wsel_o     ,  // system write byte select
   output                axi1_wvalid_o   ,  // system write data valid
   output     [  4-1: 0] axi1_wlen_o     ,  // system write burst length
   output                axi1_wfixed_o   ,  // system write burst type (fixed / incremental)
   input                 axi1_werr_i     ,  // system write error
   input                 axi1_wrdy_i     ,  // system write ready
  
   // System bus
   input      [ 32-1: 0] sys_addr      ,  // bus saddress
   input      [ 32-1: 0] sys_wdata     ,  // bus write data
   input                 sys_wen       ,  // bus write enable
   input                 sys_ren       ,  // bus read enable
   output reg [ 32-1: 0] sys_rdata     ,  // bus read data
   output reg            sys_err       ,  // bus error indicator
   output reg            sys_ack          // bus acknowledge signal
);

reg             adc_arm_do   ;
reg             adc_rst_do   ;

//---------------------------------------------------------------------------------
//  Input filtering


//---------------------------------------------------------------------------------
//  Decimate input data

reg  [ 12-1: 0] adc_a_dat     ;
reg  [ 12-1: 0] adc_b_dat     ;
reg  [ 32-1: 0] adc_a_sum     ;
reg  [ 32-1: 0] adc_b_sum     ;
reg  [ 32-1: 0] a_sum_in      ;
reg  [ 32-1: 0] b_sum_in      ;
reg  [ 32-1: 0] a_sum_uns     ;
reg  [ 32-1: 0] b_sum_uns     ;
reg  [ 32-1: 0] a_div_uns     ;
reg  [ 32-1: 0] b_div_uns     ;
reg  [ 17-1: 0] set_dec       ;
reg  [ 17-1: 0] adc_dec_cnt   ;
reg             set_avg_en    ;
reg             adc_dv        ;
reg  [  4-1: 0] adc_dv_r      ;
reg             div_go        ;
wire            div_ok_a      ;
wire            div_ok_b      ;
reg             dat_got       ;
reg             div_dat_got   ;
reg  [ 32-1: 0] a_dat_div     ;
wire [ 32-1: 0] div_out_a     ;
reg  [ 32-1: 0] b_dat_div     ;
wire [ 32-1: 0] div_out_b     ;
reg             adc_dv_div    ;
reg  [ 34-1: 0] sign_sr_a     ;
reg             sign_curr_a   ;
reg  [ 34-1: 0] sign_sr_b     ;
reg             sign_curr_b   ;

reg  [ 12-1: 0] adc_a_fifo [3:0]   ;
reg  [ 12-1: 0] adc_b_fifo [3:0]   ;
reg  [ 12-1: 0] adc_a_bram_in ;
reg  [ 12-1: 0] adc_b_bram_in ;
reg             adc_dv_del    ;

divide #(

   .XDW(32)          , // mod(XDW, PIPE*GRAIN) == 0  !!!!!!!! x data width
   .XDWW(6)          , // ceil(log2(XDW)) x data width, width
   .YDW(17)          , //y data width
   .PIPE(2)          , // how many parallel pipes (1 is minimal)
   .GRAIN(1)         ,
   .RST_ACT_LVL(0)     //positive or negative reset
)
dec_avg_div_a
(
   .clk_i(adc_clk_i) ,
   .rst_i(adc_rstn_i),
   .x_i(a_sum_uns)   , // numerator (dividend) [ XDW-1: 0]
   .y_i(set_dec)     , // denominator (divisor)[ YDW-1: 0]   // Both input values must be unsigned !!!
   .dv_i(div_go)     , //ready to start division
   .q_o(div_out_a)   , // quotient [ XDW-1: 0]
   .dv_o(div_ok_a)     // result available
);

divide #(

   .XDW(32)          ,
   .XDWW(6)          ,
   .YDW(17)          ,
   .PIPE(2)          ,
   .GRAIN(1)         , 
   .RST_ACT_LVL(0)
)
dec_avg_div_b
(
   .clk_i(adc_clk_i) ,
   .rst_i(adc_rstn_i),
   .x_i(b_sum_uns)   ,
   .y_i(set_dec)     ,
   .dv_i(div_go)     ,
   .q_o(div_out_b)   ,
   .dv_o(div_ok_b)
);

always @(posedge adc_clk_i)
if (adc_rstn_i == 1'b0) begin
   div_go      <= 1'b0;
   adc_dv_div  <= 1'b0;
   dat_got     <= 1'b0;
   div_dat_got <= 1'b0;
   a_div_uns   <= 32'h0;
   b_div_uns   <= 32'h0;
   a_sum_uns   <= 32'h0;
   b_sum_uns   <= 32'h0;
   a_sum_in    <= 32'h0;
   b_sum_in    <= 32'h0;
   a_dat_div   <= 32'h0;
   b_dat_div   <= 32'h0;
   sign_curr_a <= 1'b0;
   sign_sr_a   <= 34'b0;
   sign_curr_b <= 1'b0;
   sign_sr_b   <= 34'b0;
end else begin
   sign_sr_a<={sign_sr_a[34-2:0],sign_curr_a}; // sign shift register
   sign_sr_b<={sign_sr_b[34-2:0],sign_curr_b};
   if(adc_dec_cnt >= set_dec && set_dec >= 17'd16) begin //save sign and sum 
      sign_curr_a <= adc_a_sum[32-1];
      a_sum_in    <= adc_a_sum;
      sign_curr_b <= adc_b_sum[32-1];
      b_sum_in    <= adc_b_sum;
      dat_got     <= 1'b1; //data was acquired
   end else
      dat_got     <= 1'b0;  
        
   if (dat_got) begin
      div_go <= 1'b1; // when input data is unsigned, start division
      if (sign_curr_a) //handle signs 
         a_sum_uns <= -a_sum_in; // division has about 33 cycles of latency, new data may be fed every 16 cycles
      else 
         a_sum_uns <=  a_sum_in;
      
      if (sign_curr_b) //handle signs 
         b_sum_uns <= -b_sum_in;
      else 
         b_sum_uns <=  b_sum_in;
   end else
      div_go <= 1'b0;

   if (div_ok_a || div_ok_b) begin // division finished
      div_dat_got <= 1'b1;    
      a_div_uns   <= div_out_a; //get unsigned output data  
      b_div_uns   <= div_out_b;   
   end else
      div_dat_got <= 1'b0;
   
   if(div_dat_got) begin
      adc_dv_div<=1'b1;
      if (sign_sr_a[34-1]) // handle signs after division
         a_dat_div <= -div_out_a;
      else 
         a_dat_div <=  div_out_a;

      if (sign_sr_b[34-1]) // handle signs after division
         b_dat_div <= -div_out_b;
      else 
         b_dat_div <=  div_out_b;
      
   end else
      adc_dv_div <= 1'b0;
end

wire dec_valid = (adc_dec_cnt >= set_dec);

always @(posedge adc_clk_i)
if (adc_rstn_i == 1'b0) begin
   adc_a_sum   <= 32'h0 ;
   adc_b_sum   <= 32'h0 ;
   adc_dec_cnt <= 17'h0 ;
   adc_dv      <=  1'b0 ;
end else begin
   if (dec_valid || adc_arm_do) begin // start again or arm
      adc_dec_cnt <= 17'h1    ;              
      adc_a_sum   <= $signed(adc_a_i) ;
      adc_b_sum   <= $signed(adc_b_i) ;
   end else begin
      adc_dec_cnt <= adc_dec_cnt + 17'h1 ;
      adc_a_sum   <= $signed(adc_a_sum) + $signed(adc_a_i) ;
      adc_b_sum   <= $signed(adc_b_sum) + $signed(adc_b_i) ;
   end
   adc_dv_r <= {adc_dv_r[3-1:0], adc_dv};

   case (set_dec & {17{set_avg_en}}) // allowed dec factors: 1,2,4,8; if 16 or greater, use divider
      17'h0     : begin adc_a_dat <= adc_a_i;              adc_b_dat <= adc_b_i;              adc_dv <= dec_valid;  end // if averaging is disabled
      17'h1     : begin adc_a_dat <= adc_a_sum[12+0 :  0]; adc_b_dat <= adc_b_sum[12+0 :  0]; adc_dv <= dec_valid;  end
      17'h2     : begin adc_a_dat <= adc_a_sum[12+1 :  1]; adc_b_dat <= adc_b_sum[12+1 :  1]; adc_dv <= dec_valid;  end
      17'h4     : begin adc_a_dat <= adc_a_sum[12+2 :  2]; adc_b_dat <= adc_b_sum[12+2 :  2]; adc_dv <= dec_valid;  end
      17'h8     : begin adc_a_dat <= adc_a_sum[12+3 :  3]; adc_b_dat <= adc_b_sum[12+3 :  3]; adc_dv <= dec_valid;  end
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
      17'd15    : begin adc_a_dat <= adc_a_i;              adc_b_dat <= adc_b_i;              adc_dv <= dec_valid;  end // no division for any other decimation factor
      default   : begin adc_a_dat <= a_dat_div;            adc_b_dat <= b_dat_div;            adc_dv <= adc_dv_div; end
   endcase
end

always @(posedge adc_clk_i) begin
   adc_a_fifo[0] <= adc_a_dat;
   adc_a_fifo[1] <= adc_a_fifo[0];
   adc_a_fifo[2] <= adc_a_fifo[1];
   adc_a_fifo[3] <= adc_a_fifo[2];

   adc_b_fifo[0] <= adc_b_dat;
   adc_b_fifo[1] <= adc_b_fifo[0];
   adc_b_fifo[2] <= adc_b_fifo[1];
   adc_b_fifo[3] <= adc_b_fifo[2];
end

//---------------------------------------------------------------------------------
//  ADC buffer RAM

reg   [  12-1: 0] adc_a_buf [0:(1<<RSZ)-1] ;
reg   [  12-1: 0] adc_b_buf [0:(1<<RSZ)-1] ;
reg   [  12-1: 0] adc_a_rd      ;
reg   [  12-1: 0] adc_b_rd      ;
reg   [ RSZ-1: 0] adc_wp        ;
reg   [ RSZ-1: 0] adc_raddr     ;
reg   [ RSZ-1: 0] adc_a_raddr   ;
reg   [ RSZ-1: 0] adc_b_raddr   ;
reg   [   4-1: 0] adc_rval      ;
wire              adc_rd_dv     ;
reg               adc_we        ;
reg               adc_we_keep   ;
reg               adc_trig      ;
reg               trig_dis_clr  ;

reg   [ RSZ-1: 0] adc_wp_trig   ;
reg   [ RSZ-1: 0] adc_wp_cur_rd ;
reg   [ RSZ-1: 0] adc_wp_trig_rd;
reg   [ RSZ-1: 0] adc_wp_cur    ;
reg   [  32-1: 0] set_dly       ;
reg   [  32-1: 0] adc_we_cnt    ;
reg   [  32-1: 0] adc_we_cnt_rd ;
reg   [  33-1: 0] adc_dly_cnt   ;
reg               adc_dly_do    ;
reg               adc_dly_end   ;
reg               adc_dly_end_reg;
reg               adc_trg_rd    ;
reg               adc_trg_rd_reg;
reg    [ 20-1: 0] set_deb_len   ; // debouncing length (glitch free time after a posedge)
wire              dec1    ;

assign dec1  = (set_dec==17'h1);

// Write
always @(posedge adc_clk_i) begin
   if (adc_rstn_i == 1'b0) begin
      adc_wp      <= {RSZ{1'b0}};
      adc_we      <=  1'b0      ;
      adc_wp_trig <= {RSZ{1'b0}};
      adc_wp_cur  <= {RSZ{1'b0}};
      adc_we_cnt  <= 32'h0      ;
      adc_dly_cnt <= 32'h0      ;
      adc_dly_do  <=  1'b0      ;
      adc_dly_end <=  1'b0      ;
      adc_dly_end_reg <= 1'b0   ;
      adc_trg_rd  <=  1'b0      ;
      adc_trg_rd_reg  <= 1'b0   ;
   end
   else begin
      if (adc_arm_do)
         adc_we <= 1'b1 ;
      else if (((adc_dly_do || adc_trig) && (adc_dly_cnt == 32'h1) && ~adc_we_keep) || adc_rst_do) //delayed reached or reset
         adc_we <= 1'b0 ;

      // count how much data was written into the buffer before trigger
      if ((adc_rst_do || adc_arm_do) || (trig_dis_clr && adc_we_keep)) // at arm, in cont mode at trigger protect clear
         adc_we_cnt <= 32'h0;
      else if (adc_we & ~adc_dly_do & adc_dv_del & ~&adc_we_cnt)
         adc_we_cnt <= adc_we_cnt + 1;

      if (adc_rst_do)
         adc_wp <= {RSZ{1'b0}};
      else if (adc_we && adc_dv_del)
         adc_wp <= adc_wp + 1;

      if (adc_rst_do)
         adc_wp_trig <= {RSZ{1'b0}};
      else if (adc_trig && !adc_dly_do)
         adc_wp_trig <= adc_wp; // save write pointer at trigger arrival

      if (adc_rst_do)
         adc_wp_cur <= {RSZ{1'b0}};
      else if (adc_we && adc_dv_del)
         adc_wp_cur <= adc_wp; // save current write pointer


      if (adc_trig)
         adc_dly_do  <= 1'b1;
      else if ((adc_dly_do && (adc_dly_cnt <= 32'h1)) || adc_rst_do || adc_arm_do) //delay reached or reset; delay is shortened by 1
         adc_dly_do  <= 1'b0;
      
      adc_dly_end_reg <= adc_dly_do; 
      
      if (adc_rst_do || adc_arm_do)
         adc_dly_end<=1'b0;
      else if (adc_dly_end_reg && ~adc_dly_do) //check if delay is over
         adc_dly_end<=1'b1; //register remains 1 until next arm or reset

      adc_trg_rd_reg<=adc_trig;
      if (~adc_trg_rd_reg && adc_trig) //check if trigger happenned
         adc_trg_rd<=1'b1; //register remains 1 until next arm or reset
      else if (adc_rst_do || adc_arm_do)
         adc_trg_rd<=1'b0;

      if ((adc_dly_do && adc_we && adc_dv_del) || (adc_trig && dec1))
         adc_dly_cnt <= adc_dly_cnt - 1;
      else if (!adc_dly_do)
         adc_dly_cnt <= set_dly ;

   end
end

always @(posedge adc_clk_i) begin
   if (adc_we && adc_dv_del) begin
      adc_a_buf[adc_wp] <= adc_a_bram_in ;
      adc_b_buf[adc_wp] <= adc_b_bram_in ;
   end
end

// Read
always @(posedge adc_clk2d_i) begin
   if (adc_rstn_i == 1'b0)
      adc_rval <= 4'h0 ;
   else
      adc_rval <= {adc_rval[2:0], (sys_ren || sys_wen)};
end
assign adc_rd_dv = adc_rval[3];

always @(posedge adc_clk2d_i) begin
   adc_raddr   <= sys_addr[RSZ+1:2] ; // address synchronous to clock
   adc_a_raddr <= adc_raddr     ; // double register 
   adc_b_raddr <= adc_raddr     ; // otherwise memory corruption at reading
   adc_a_rd    <= adc_a_buf[adc_a_raddr] ;
   adc_b_rd    <= adc_b_buf[adc_b_raddr] ;

   adc_wp_cur_rd  <= adc_wp_cur  ;
   adc_wp_trig_rd <= adc_wp_trig ;
   adc_we_cnt_rd  <= adc_we_cnt  ;
end




//---------------------------------------------------------------------------------
//
//  AXI CHA connection

reg  [ 32-1: 0] set_a_axi_start    ;
reg  [ 32-1: 0] set_a_axi_stop     ;
reg  [ 32-1: 0] set_a_axi_dly      ;
reg             set_a_axi_en       ;
reg  [ 32-1: 0] set_a_axi_trig     ;
reg  [ 32-1: 0] set_a_axi_cur      ;
reg             axi_a_we           ;
reg             axi_a_we_r         ;
reg  [ 64-1: 0] axi_a_dat          ;

wire            axi_a_trig    ;
reg  [  8-1: 0] axi_a_trig_r  ;
reg  [  2-1: 0] axi_a_sel     ;
reg  [ 12-1: 0] axi_a_dat_align [0:2];
wire [128-1: 0] axi_a_fifo_out     ;
wire [128-1: 0] axi_a_fifo_in      ;
reg  [128-1: 0] axi_a_fifo_o_r     ;
wire            axi_a_fifo_rdreq   ;
reg  [  2-1: 0] axi_a_fifo_rdack   ;

reg  [  2-1: 0] axi_a_dat_sel      ;
reg  [  3-1: 0] axi_a_md           ;

reg             axi_a_dv           ;
reg             axi_a_fifo_wr      ;
reg  [ 32-1: 0] axi_a_dly_cnt      ;
reg             axi_a_dly_do       ;
reg             axi_a_dly_end      ;
reg             axi_a_dly_end_reg  ;
wire            axi_a_clr          ;
wire [ 32-1: 0] axi_a_cur_addr     ;
wire [  5-1: 0] axi_a_state        ;
wire            fifo_a_empty       ;
reg  [  8-1: 0] axi_a_val_byte     ;
reg  [  8-1: 0] axi_a_val_byte_f   ;

assign axi_a_clr = adc_rst_do || (sys_wen && (sys_addr[19:0]==20'h5C) && sys_wdata[0]) ; // when AXI A is enabled
assign axi_a_state = {axi_a_dly_end, adc_we_keep, adc_trg_rd, 1'b0, axi_a_we};           // current state of AXI transfers

// disable FIFO reads when there is a trigger, when there is a current read being handled
assign axi_a_fifo_rdreq = ~fifo_a_empty && ~axi_a_fifo_rdack[0] && ~(axi_a_trig || |axi_a_trig_r); 

assign axi_a_trig = axi_a_fifo_o_r[64] && axi_a_fifo_rdack[1];             // pulse when a valid trigger is received
assign axi_a_fifo_in    = {53'h0, axi_a_val_byte, axi_a_md, axi_a_dat};    // inputs to FIFO

always @(posedge adc_clk_i) begin
   if (adc_rstn_i == 1'b0) begin
      axi_a_dat_sel     <=  2'h0 ;
      axi_a_fifo_wr     <=  1'b0 ;
      axi_a_dly_cnt     <= 32'h0 ;
      axi_a_dly_do      <=  1'b0 ;
      axi_a_dly_end     <=  1'b0 ;
      axi_a_dly_end_reg <=  1'b0 ;
      axi_a_md          <=  3'h0 ;
      axi_a_val_byte    <=  8'h0 ;
   end
   else begin
      if (adc_arm_do && set_a_axi_en)
         axi_a_we <= 1'b1 ;
      else if (((axi_a_dly_do || adc_trig) && (axi_a_dly_cnt == 32'h1)) || adc_rst_do) //delay reached or reset
         axi_a_we <= 1'b0 ;

      if (adc_trig && axi_a_we)
         axi_a_dly_do  <= 1'b1 ;
      else if ((axi_a_dly_do && (axi_a_dly_cnt <= 32'h1)) || axi_a_clr || adc_arm_do) //delay reached or clear or start of acquisition
         axi_a_dly_do  <= 1'b0 ;

      if ((axi_a_dly_do && axi_a_we && axi_a_dv) || (adc_trig && dec1)) // shorthen by 1 if decimation is 1
         axi_a_dly_cnt <= axi_a_dly_cnt - 1;
      else if (!axi_a_dly_do)
         axi_a_dly_cnt <= set_a_axi_dly ;

      axi_a_dly_end_reg <= axi_a_dly_do; 
      
      if (adc_rst_do || adc_arm_do)
         axi_a_dly_end<=1'b0;
      else if (axi_a_dly_end_reg && ~axi_a_dly_do) //check if delay is over
         axi_a_dly_end<=1'b1;                      //register remains 1 until next arm or reset

      if (axi_a_clr || (~axi_a_we && axi_a_we_r))
         axi_a_dat_sel <= 2'h0 ;
      else if (axi_a_we && axi_a_dv)
         axi_a_dat_sel <= axi_a_dat_sel + 2'h1 ;

      axi_a_dv     <= adc_dv_r[1];

      axi_a_dat_align[0] <= adc_a_dat; //align data to trigger
      axi_a_dat_align[1] <= axi_a_dat_align[0];
      axi_a_dat_align[2] <= axi_a_dat_align[1];

      axi_a_we_r    <= axi_a_we;
      axi_a_fifo_wr <= (axi_a_we && (axi_a_dat_sel == 2'b11) && axi_a_dv) || ((axi_a_dat_sel != 2'b00) && (~axi_a_we && axi_a_we_r)) ; // fill up by four samples or until the last sample in trigger delay
   end

   if (axi_a_we && axi_a_dv) begin
      if (axi_a_dat_sel == 2'b00) begin axi_a_dat[ 16-1:  0] <= $signed(axi_a_dat_align[2]); axi_a_val_byte <= {2'b00, 2'b00, 2'b00, 2'b11}; end
      if (axi_a_dat_sel == 2'b01) begin axi_a_dat[ 32-1: 16] <= $signed(axi_a_dat_align[2]); axi_a_val_byte <= {2'b00, 2'b00, 2'b11, 2'b11}; end
      if (axi_a_dat_sel == 2'b10) begin axi_a_dat[ 48-1: 32] <= $signed(axi_a_dat_align[2]); axi_a_val_byte <= {2'b00, 2'b11, 2'b11, 2'b11}; end
      if (axi_a_dat_sel == 2'b11) begin axi_a_dat[ 64-1: 48] <= $signed(axi_a_dat_align[2]); axi_a_val_byte <= {2'b11, 2'b11, 2'b11, 2'b11}; end
   end

   if (axi_a_fifo_rdack[0]) begin
      axi_a_sel         <= axi_a_fifo_out[66:65];
      axi_a_val_byte_f  <= axi_a_fifo_out[74:67];
   end

   if (adc_trig)
      axi_a_md <= {axi_a_dat_sel,(!axi_a_dly_do && axi_a_we)}; //valid trig
   else if (axi_a_fifo_wr)
      axi_a_md <= 3'h0;

   if (axi_a_clr)
      set_a_axi_cur <= set_a_axi_start ;
   else if (axi0_wvalid_o)
      set_a_axi_cur <= axi_a_cur_addr ;
end

sync_fifo 
  U_sync_fifo_a(
  .wr_clk         (adc_clk_i        ),
  .rd_clk         (axi0_clk_o       ),
  .rst            ((axi0_rstn_o==1'b0 ) || axi_a_clr),
  .din            (axi_a_fifo_in    ),
  .wr_en          (axi_a_fifo_wr    ),
  .full           (                 ),
  .dout           (axi_a_fifo_out   ),
  .rd_en          (axi_a_fifo_rdreq ),
  .empty          (fifo_a_empty     ),
  .wr_rst_busy    (                 ),
  .rd_rst_busy    (                 ));

always @(posedge axi0_clk_o) begin
   axi_a_trig_r <= {axi_a_trig_r[7-1:0],axi_a_trig}; //axi_trig fifod
   axi_a_fifo_rdack <= {axi_a_fifo_rdack[0],axi_a_fifo_rdreq};
   
   if (axi_a_fifo_rdack[0]) begin
      axi_a_fifo_o_r <= axi_a_fifo_out;
   end

   if (axi_a_clr)
      set_a_axi_trig <= {RSZ{1'b0}};
   else if (axi_a_trig_r[1]) // wait for the address to update from last write to AXI FIFO
      set_a_axi_trig <= {axi_a_cur_addr[32-1:3],axi_a_sel, 1'b0}; // save write pointer at trigger arrival
end

axi_wr_fifo #(
  .DW  (  64    ), // data width (8,16,...,1024)
  .AW  (  32    ), // address width
  .FW  (   8    ), // address width of FIFO pointers
  .BYTE_SEL ( 1 )
) i_wr0 (
   // global signals
  .axi_clk_i          (  axi0_clk_o        ), // global clock
  .axi_rstn_i         (  axi0_rstn_o       ), // global reset

   // Connection to AXI master
  .axi_waddr_o        (  axi0_waddr_o      ), // write address
  .axi_wdata_o        (  axi0_wdata_o      ), // write data
  .axi_wsel_o         (  axi0_wsel_o       ), // write byte select
  .axi_wvalid_o       (  axi0_wvalid_o     ), // write data valid
  .axi_wlen_o         (  axi0_wlen_o       ), // write burst length
  .axi_wfixed_o       (  axi0_wfixed_o     ), // write burst type (fixed / incremental)
  .axi_werr_i         (  axi0_werr_i       ), // write error
  .axi_wrdy_i         (  axi0_wrdy_i       ), // write ready

   // data and configuration
  .wr_data_i          (  axi_a_fifo_o_r[63:0]), // write data
  .wr_byte_val_i      (  axi_a_val_byte_f    ), // valid bytes
  .wr_val_i           (  axi_a_fifo_rdack[1] ), // write data valid
  .ctrl_start_addr_i  (  set_a_axi_start   ), // range start address
  .ctrl_stop_addr_i   (  set_a_axi_stop    ), // range stop address
  .ctrl_trig_size_i   (  4'hF              ), // trigger level
  .ctrl_wrap_i        (  1'b1              ), // start from begining when reached stop
  .ctrl_clr_i         (  axi_a_clr         ), // clear / flush
  .stat_overflow_o    (                    ), // overflow indicator
  .stat_cur_addr_o    (  axi_a_cur_addr    ), // current write address
  .stat_write_data_o  (                    )  // write data indicator
);

assign axi0_clk_o  = adc_clk2d_i ;
assign axi0_rstn_o = adc_rstn_i;

//---------------------------------------------------------------------------------
//
//  AXI CHB connection

reg  [ 32-1: 0] set_b_axi_start    ;
reg  [ 32-1: 0] set_b_axi_stop     ;
reg  [ 32-1: 0] set_b_axi_dly      ;
reg             set_b_axi_en       ;
reg  [ 32-1: 0] set_b_axi_trig     ;
reg  [ 32-1: 0] set_b_axi_cur      ;
reg             axi_b_we           ;
reg             axi_b_we_r         ;
reg  [ 64-1: 0] axi_b_dat          ;
wire            axi_b_trig    ;
reg  [  8-1: 0] axi_b_trig_r  ;
reg  [  2-1: 0] axi_b_sel     ;
reg  [ 12-1: 0] axi_b_dat_align [0:2];
wire [128-1: 0] axi_b_fifo_dat     ;
wire [128-1: 0] axi_b_fifo_out     ;
reg  [128-1: 0] axi_b_fifo_o_r     ;
wire [128-1: 0] axi_b_fifo_in      ;
wire            axi_b_fifo_rdreq   ;
reg  [  2-1: 0] axi_b_fifo_rdack   ;

reg  [  2-1: 0] axi_b_dat_sel      ;
reg  [  3-1: 0] axi_b_md           ;

reg             axi_b_dv           ;
reg             axi_b_fifo_wr      ;
reg  [ 32-1: 0] axi_b_dly_cnt      ;
reg             axi_b_dly_do       ;
reg             axi_b_dly_end      ;
reg             axi_b_dly_end_reg  ;
wire            axi_b_clr          ;
wire [ 32-1: 0] axi_b_cur_addr     ;
wire [  5-1: 0] axi_b_state        ;
wire            fifo_b_empty       ;
reg  [  8-1: 0] axi_b_val_byte     ;
reg  [  8-1: 0] axi_b_val_byte_f   ;

assign axi_b_clr = adc_rst_do || (sys_wen && (sys_addr[19:0]==20'h7C) && sys_wdata[0]) ; // when AXI B is enabled
assign axi_b_state = {axi_b_dly_end, adc_we_keep, adc_trg_rd, 1'b0, axi_b_we};

// disable FIFO reads when there is a trigger, when there is a current read being handled
assign axi_b_fifo_rdreq = ~fifo_b_empty && ~axi_b_fifo_rdack[0] && ~(axi_b_trig || |axi_b_trig_r); 

assign axi_b_trig = axi_b_fifo_o_r[64] && axi_b_fifo_rdack[1];
assign axi_b_fifo_in    = {53'h0, axi_b_val_byte, axi_b_md, axi_b_dat};

always @(posedge adc_clk_i) begin
   if (adc_rstn_i == 1'b0) begin
      axi_b_dat_sel     <=  2'h0 ;
      axi_b_fifo_wr     <=  1'b0 ;
      axi_b_dly_cnt     <= 32'h0 ;
      axi_b_dly_do      <=  1'b0 ;
      axi_b_dly_end     <=  1'b0 ;
      axi_b_dly_end_reg <=  1'b0 ;
      axi_b_md          <=  3'h0 ;
      axi_b_val_byte    <=  8'h0 ;
   end
   else begin
      if (adc_arm_do && set_b_axi_en)
         axi_b_we <= 1'b1 ;
      else if (((axi_b_dly_do || adc_trig) && (axi_b_dly_cnt == 32'h1)) || adc_rst_do) //delay reached or reset
         axi_b_we <= 1'b0 ;

      if (adc_trig && axi_b_we)
         axi_b_dly_do  <= 1'b1 ;
      else if ((axi_b_dly_do && (axi_b_dly_cnt <= 32'h1)) || axi_b_clr || adc_arm_do) //delay reached or reset
         axi_b_dly_do  <= 1'b0 ;

      if ((axi_b_dly_do && axi_b_we && axi_b_dv) || (adc_trig && dec1))
         axi_b_dly_cnt <= axi_b_dly_cnt - 1;
      else if (!axi_b_dly_do)
         axi_b_dly_cnt <= set_b_axi_dly ;

      axi_b_dly_end_reg <= axi_b_dly_do; 
      
      if (adc_rst_do || adc_arm_do)
         axi_b_dly_end<=1'b0;
      else if (axi_b_dly_end_reg && ~axi_b_dly_do) //check if delay is over
         axi_b_dly_end<=1'b1; //register remains 1 until next arm or reset

      if (axi_b_clr || (~axi_b_we && axi_b_we_r))
         axi_b_dat_sel <= 2'h0 ;
      else if (axi_b_we && axi_b_dv)
         axi_b_dat_sel <= axi_b_dat_sel + 2'h1 ;

      axi_b_dv     <= adc_dv_r[1];

      axi_b_dat_align[0] <= adc_b_dat; //align data to trigger
      axi_b_dat_align[1] <= axi_b_dat_align[0];
      axi_b_dat_align[2] <= axi_b_dat_align[1];

      axi_b_we_r    <= axi_b_we;
      axi_b_fifo_wr <= (axi_b_we && (axi_b_dat_sel == 2'b11) && axi_b_dv) || ((axi_b_dat_sel != 2'b00) && (~axi_b_we && axi_b_we_r)) ;

   end

   if (axi_b_we && axi_b_dv) begin
      if (axi_b_dat_sel == 2'b00) begin axi_b_dat[ 16-1:  0] <= $signed(axi_b_dat_align[2]); axi_b_val_byte <= {2'b00, 2'b00, 2'b00, 2'b11}; end
      if (axi_b_dat_sel == 2'b01) begin axi_b_dat[ 32-1: 16] <= $signed(axi_b_dat_align[2]); axi_b_val_byte <= {2'b00, 2'b00, 2'b11, 2'b11}; end
      if (axi_b_dat_sel == 2'b10) begin axi_b_dat[ 48-1: 32] <= $signed(axi_b_dat_align[2]); axi_b_val_byte <= {2'b00, 2'b11, 2'b11, 2'b11}; end
      if (axi_b_dat_sel == 2'b11) begin axi_b_dat[ 64-1: 48] <= $signed(axi_b_dat_align[2]); axi_b_val_byte <= {2'b11, 2'b11, 2'b11, 2'b11}; end
   end

   if (axi_b_fifo_rdack[0]) begin
      axi_b_sel         <= axi_b_fifo_out[66:65];
      axi_b_val_byte_f  <= axi_b_fifo_out[74:67];
   end

   if (adc_trig)
      axi_b_md <= {axi_b_dat_sel,(!axi_b_dly_do && axi_b_we)}; //valid trig
   else if (axi_b_fifo_wr)
      axi_b_md <= 3'h0;

   if (axi_b_clr)
      set_b_axi_cur <= set_b_axi_start ;
   else if (axi0_wvalid_o)
      set_b_axi_cur <= axi_b_cur_addr ;
end

sync_fifo 
  U_sync_fifo_b(
  .wr_clk         (adc_clk_i        ),
  .rd_clk         (axi1_clk_o       ),
  .rst            ((axi1_rstn_o==1'b0 ) || axi_b_clr),
  .din            (axi_b_fifo_in    ),
  .wr_en          (axi_b_fifo_wr    ),
  .full           (                 ),
  .dout           (axi_b_fifo_out   ),
  .rd_en          (axi_b_fifo_rdreq ),
  .empty          (fifo_b_empty     ),
  .wr_rst_busy    (                 ),
  .rd_rst_busy    (                 ));

always @(posedge axi1_clk_o) begin
   axi_b_trig_r <= {axi_b_trig_r[7-1:0],axi_b_trig}; //axi_trig fifod
   axi_b_fifo_rdack <= {axi_b_fifo_rdack[0],axi_b_fifo_rdreq};

   if (axi_b_fifo_rdack[0]) begin
      axi_b_fifo_o_r <= axi_b_fifo_out;
   end

   if (axi_b_clr)
      set_b_axi_trig <= {RSZ{1'b0}};
   else if (axi_b_trig_r[1])                                      // wait for the address to update from last write to AXI FIFO
      set_b_axi_trig <= {axi_b_cur_addr[32-1:3],axi_b_sel, 1'b0}; // save write pointer at trigger arrival
end

axi_wr_fifo #(
  .DW  (  64    ), // data width (8,16,...,1024)
  .AW  (  32    ), // address width
  .FW  (   8    ), // address width of FIFO pointers
  .BYTE_SEL ( 1 )
) i_wr1 (
   // global signals
  .axi_clk_i          (  axi1_clk_o        ), // global clock
  .axi_rstn_i         (  axi1_rstn_o       ), // global reset

   // Connection to AXI master
  .axi_waddr_o        (  axi1_waddr_o      ), // write address
  .axi_wdata_o        (  axi1_wdata_o      ), // write data
  .axi_wsel_o         (  axi1_wsel_o       ), // write byte select
  .axi_wvalid_o       (  axi1_wvalid_o     ), // write data valid
  .axi_wlen_o         (  axi1_wlen_o       ), // write burst length
  .axi_wfixed_o       (  axi1_wfixed_o     ), // write burst type (fixed / incremental)
  .axi_werr_i         (  axi1_werr_i       ), // write error
  .axi_wrdy_i         (  axi1_wrdy_i       ), // write ready

   // data and configuration
  .wr_data_i          (  axi_b_fifo_o_r[63:0]), // write data
  .wr_byte_val_i      (  axi_b_val_byte_f    ), // valid bytes
  .wr_val_i           (  axi_b_fifo_rdack[1] ), // write data valid
  .ctrl_start_addr_i  (  set_b_axi_start   ), // range start address
  .ctrl_stop_addr_i   (  set_b_axi_stop    ), // range stop address
  .ctrl_trig_size_i   (  4'hF              ), // trigger level
  .ctrl_wrap_i        (  1'b1              ), // start from begining when reached stop
  .ctrl_clr_i         (  axi_b_clr         ), // clear / flush
  .stat_overflow_o    (                    ), // overflow indicator
  .stat_cur_addr_o    (  axi_b_cur_addr    ), // current write address
  .stat_write_data_o  (                    )  // write data indicator
);

assign axi1_clk_o  = adc_clk2d_i ;
assign axi1_rstn_o = adc_rstn_i;

//---------------------------------------------------------------------------------
//  Trigger source selector

reg               adc_trig_ap      ;
reg               adc_trig_an      ;
reg               adc_trig_bp      ;
reg               adc_trig_bn      ;
wire              adc_trig_sw      ;
wire              adc_trig_sw_p    ;
reg               adc_trig_sw_r    ;

reg   [   4-1: 0] set_trig_src     ;
wire              ext_trig_p       ;
wire              ext_trig_n       ;
wire              asg_trig_p       ;
wire              asg_trig_n       ;
wire              adc_trig_clr     ;
wire              adc_trig_clr2d   ;
reg               adc_trg_dis      = 1'b0;
reg   [   4-1:0]  trig_dis_clr_r   ;

assign adc_trig_clr = (adc_dly_do || adc_trig);

sync #(.DW(1), .PULSE(1)) i_sync
   (.sclk_i(adc_clk_i),   .srstn_i(adc_rstn_i), .src_i(adc_trig_clr),
    .dclk_i(adc_clk2d_i), .drstn_i(adc_rstn_i), .dst_o(adc_trig_clr2d)
);

assign adc_trig_sw_p = sys_wen && (sys_addr[19:0]==20'h4 ) && (sys_wdata[3:0]==4'h1); // trigger pulse
assign adc_trig_sw   = (adc_trig_sw_r) && adc_dv_r[dat_dly];

always @(posedge adc_clk2d_i)
if (adc_rstn_i == 1'b0) begin
   adc_arm_do    <= 1'b0 ;
   adc_rst_do    <= 1'b0 ;
   adc_trig_sw_r <= 1'b0 ;
   trig_dis_clr  <= 1'b0 ;
   set_trig_src  <= 4'h0 ;
end else begin
   adc_arm_do   <= sys_wen && (sys_addr[19:0]==20'h0 ) && sys_wdata[0] ; // SW ARM
   adc_rst_do   <= sys_wen && (sys_addr[19:0]==20'h0 ) && sys_wdata[1] ; // reset
   trig_dis_clr <= sys_wen && (sys_addr[19:0]==20'h94) && (sys_wdata[0]==1'b1);   // clear trigger protect/disable

   if (adc_trig_sw_p)// extend wait for next valid sample 
      adc_trig_sw_r <= 1'b1; 
   else if (adc_dv_r[dat_dly])
      adc_trig_sw_r <= 1'b0; 

   if (sys_wen && (sys_addr[19:0]==20'h4))
      set_trig_src <= sys_wdata[3:0] ;
   else if (adc_trig_clr2d || adc_rst_do) //delayed reached or reset
      set_trig_src <= 4'h0 ;
end

always @(posedge adc_clk_i) begin
   trig_dis_clr_r <= {trig_dis_clr_r[2:0],trig_dis_clr};
   if (trig_dis_clr_r[3] && !trig_dis_clr_r[2])
      adc_trg_dis <= 1'b0 ;
   else if (adc_trig)
      adc_trg_dis <= 1'b1 ;
end

always @(posedge adc_clk_i)
if (adc_rstn_i == 1'b0) begin
   adc_trig  <= 1'b0 ;
end else begin
   case (set_trig_src & ({4{!adc_trg_dis}}))
       4'd1 : adc_trig <= adc_trig_sw   ; // manual
       4'd2 : adc_trig <= adc_trig_ap   ; // A ch rising edge
       4'd3 : adc_trig <= adc_trig_an   ; // A ch falling edge
       4'd4 : adc_trig <= adc_trig_bp   ; // B ch rising edge
       4'd5 : adc_trig <= adc_trig_bn   ; // B ch falling edge
       4'd6 : adc_trig <= ext_trig_p    ; // external - rising edge
       4'd7 : adc_trig <= ext_trig_n    ; // external - falling edge
       4'd8 : adc_trig <= asg_trig_p    ; // ASG - rising edge
       4'd9 : adc_trig <= asg_trig_n    ; // ASG - falling edge
    default : adc_trig <= 1'b0          ;
   endcase
end



reg [4-1:0] last_src = 4'h0;
always @(posedge adc_clk_i) begin
  if (sys_wen && (sys_addr[19:0]==20'h4))
   last_src <= sys_wdata[3:0] ;
end

reg [2-1:0] dat_dly  = 2'h0;
reg [2-1:0] prev_dly = 2'h0;
always @(posedge adc_clk_i) begin //delay to trigger
   case (last_src)
       4'd2,
       4'd3,
       4'd4,
       4'd5,
       4'd10,
       4'd11,
       4'd12,
       4'd13  : begin dat_dly <= 2'h1; prev_dly <= 2'h1; end // level trigger
       4'd6,
       4'd7,
       4'd8,
       4'd9   : begin dat_dly <= 2'h2; prev_dly <= 2'h2; end // external and ASG trigger
      default : begin dat_dly <= prev_dly;              end // manual trigger
   endcase

   adc_a_bram_in <= adc_a_fifo[dat_dly]; 
   adc_b_bram_in <= adc_b_fifo[dat_dly]; 
   adc_dv_del    <= adc_dv_r[dat_dly];
end

assign trig_ch_o = {adc_trig_bn, adc_trig_bp, adc_trig_an, adc_trig_ap};
assign daisy_trig_o = adc_trig;
//---------------------------------------------------------------------------------
//  Trigger created from input signal

reg  [  2-1: 0] adc_scht_ap  ;
reg  [  2-1: 0] adc_scht_an  ;
reg  [  2-1: 0] adc_scht_bp  ;
reg  [  2-1: 0] adc_scht_bn  ;
reg  [ 12-1: 0] set_a_tresh  ;
reg  [ 12-1: 0] set_a_treshp ;
reg  [ 12-1: 0] set_a_treshn ;
reg  [ 12-1: 0] set_b_tresh  ;
reg  [ 12-1: 0] set_b_treshp ;
reg  [ 12-1: 0] set_b_treshn ;
reg  [ 12-1: 0] set_a_hyst   ;
reg  [ 12-1: 0] set_b_hyst   ;

always @(posedge adc_clk_i)
if (adc_rstn_i == 1'b0) begin
   adc_scht_ap  <=  2'h0 ;
   adc_scht_an  <=  2'h0 ;
   adc_scht_bp  <=  2'h0 ;
   adc_scht_bn  <=  2'h0 ;
   adc_trig_ap  <=  1'b0 ;
   adc_trig_an  <=  1'b0 ;
   adc_trig_bp  <=  1'b0 ;
   adc_trig_bn  <=  1'b0 ;
end else begin
   set_a_treshp <= set_a_tresh + set_a_hyst ; // calculate positive
   set_a_treshn <= set_a_tresh - set_a_hyst ; // and negative treshold
   set_b_treshp <= set_b_tresh + set_b_hyst ;
   set_b_treshn <= set_b_tresh - set_b_hyst ;

   if (adc_dv) begin
           if ($signed(adc_a_dat) >= $signed(set_a_tresh ))      adc_scht_ap[0] <= 1'b1 ;  // treshold reached
      else if ($signed(adc_a_dat) <  $signed(set_a_treshn))      adc_scht_ap[0] <= 1'b0 ;  // wait until it goes under hysteresis
           if ($signed(adc_a_dat) <= $signed(set_a_tresh ))      adc_scht_an[0] <= 1'b1 ;  // treshold reached
      else if ($signed(adc_a_dat) >  $signed(set_a_treshp))      adc_scht_an[0] <= 1'b0 ;  // wait until it goes over hysteresis

           if ($signed(adc_b_dat) >= $signed(set_b_tresh ))      adc_scht_bp[0] <= 1'b1 ;
      else if ($signed(adc_b_dat) <  $signed(set_b_treshn))      adc_scht_bp[0] <= 1'b0 ;
           if ($signed(adc_b_dat) <= $signed(set_b_tresh ))      adc_scht_bn[0] <= 1'b1 ;
      else if ($signed(adc_b_dat) >  $signed(set_b_treshp))      adc_scht_bn[0] <= 1'b0 ;
   end

   adc_scht_ap[1] <= adc_scht_ap[0] ;
   adc_scht_an[1] <= adc_scht_an[0] ;
   adc_scht_bp[1] <= adc_scht_bp[0] ;
   adc_scht_bn[1] <= adc_scht_bn[0] ;

   adc_trig_ap <= adc_scht_ap[0] && !adc_scht_ap[1] ; // make 1 cyc pulse 
   adc_trig_an <= adc_scht_an[0] && !adc_scht_an[1] ;
   adc_trig_bp <= adc_scht_bp[0] && !adc_scht_bp[1] ;
   adc_trig_bn <= adc_scht_bn[0] && !adc_scht_bn[1] ;
end

//---------------------------------------------------------------------------------
//  External trigger

reg  [  3-1: 0] ext_trig_in    ;
reg  [  2-1: 0] ext_trig_dp    ;
reg  [  2-1: 0] ext_trig_dn    ;
reg  [ 20-1: 0] ext_trig_debp  ;
reg  [ 20-1: 0] ext_trig_debn  ;
reg  [  3-1: 0] asg_trig_in    ;
reg  [  2-1: 0] asg_trig_dp    ;
reg  [  2-1: 0] asg_trig_dn    ;
reg  [ 20-1: 0] asg_trig_debp  ;
reg  [ 20-1: 0] asg_trig_debn  ;

always @(posedge adc_clk_i)
if (adc_rstn_i == 1'b0) begin
   ext_trig_in   <=  3'h0 ;
   ext_trig_dp   <=  2'h0 ;
   ext_trig_dn   <=  2'h0 ;
   ext_trig_debp <= 20'h0 ;
   ext_trig_debn <= 20'h0 ;
   asg_trig_in   <=  3'h0 ;
   asg_trig_dp   <=  2'h0 ;
   asg_trig_dn   <=  2'h0 ;
   asg_trig_debp <= 20'h0 ;
   asg_trig_debn <= 20'h0 ;
end else begin
   //----------- External trigger
   // synchronize FFs
   ext_trig_in <= {ext_trig_in[1:0],trig_ext_i} ;

   // look for input changes
   if ((ext_trig_debp == 20'h0) && (ext_trig_in[1] && !ext_trig_in[2]))
      ext_trig_debp <= set_deb_len ; // ~0.5ms
   else if (ext_trig_debp != 20'h0)
      ext_trig_debp <= ext_trig_debp - 20'd1 ;

   if ((ext_trig_debn == 20'h0) && (!ext_trig_in[1] && ext_trig_in[2]))
      ext_trig_debn <= set_deb_len ; // ~0.5ms
   else if (ext_trig_debn != 20'h0)
      ext_trig_debn <= ext_trig_debn - 20'd1 ;

   // update output values
   ext_trig_dp[1] <= ext_trig_dp[0] ;
   if (ext_trig_debp == 20'h0)
      ext_trig_dp[0] <= ext_trig_in[1] ;

   ext_trig_dn[1] <= ext_trig_dn[0] ;
   if (ext_trig_debn == 20'h0)
      ext_trig_dn[0] <= ext_trig_in[1] ;

   //----------- ASG trigger
   // synchronize FFs
   asg_trig_in <= {asg_trig_in[1:0],trig_asg_i} ;

   // look for input changes
   if ((asg_trig_debp == 20'h0) && (asg_trig_in[1] && !asg_trig_in[2]))
      asg_trig_debp <= set_deb_len ; // ~0.5ms
   else if (asg_trig_debp != 20'h0)
      asg_trig_debp <= asg_trig_debp - 20'd1 ;

   if ((asg_trig_debn == 20'h0) && (!asg_trig_in[1] && asg_trig_in[2]))
      asg_trig_debn <= set_deb_len ; // ~0.5ms
   else if (asg_trig_debn != 20'h0)
      asg_trig_debn <= asg_trig_debn - 20'd1 ;

   // update output values
   asg_trig_dp[1] <= asg_trig_dp[0] ;
   if (asg_trig_debp == 20'h0)
      asg_trig_dp[0] <= asg_trig_in[1] ;

   asg_trig_dn[1] <= asg_trig_dn[0] ;
   if (asg_trig_debn == 20'h0)
      asg_trig_dn[0] <= asg_trig_in[1] ;
end

assign ext_trig_p = (ext_trig_dp == 2'b01) ;
assign ext_trig_n = (ext_trig_dn == 2'b10) ;
assign asg_trig_p = (asg_trig_dp == 2'b01) ;
assign asg_trig_n = (asg_trig_dn == 2'b10) ;

//---------------------------------------------------------------------------------
//  System bus connection

always @(posedge adc_clk2d_i)
if (adc_rstn_i == 1'b0) begin
   adc_we_keep   <=   1'b0      ;
   set_a_tresh   <=  12'd2000   ;
   set_b_tresh   <= -12'd2000   ;
   set_dly       <=  32'd0      ;
   set_dec       <=  17'd1      ;
   set_a_hyst    <=  12'd20     ;
   set_b_hyst    <=  12'd20     ;
   set_avg_en    <=   1'b1      ;
   set_deb_len   <=  20'd62500  ;
   set_a_axi_en  <=   1'b0      ;
   set_b_axi_en  <=   1'b0      ;
end else begin
   if (sys_wen) begin
      if (sys_addr[19:0]==20'h00)   adc_we_keep   <= sys_wdata[     3] ;

      if (sys_addr[19:0]==20'h08)   set_a_tresh   <= sys_wdata[12-1:0] ;
      if (sys_addr[19:0]==20'h0C)   set_b_tresh   <= sys_wdata[12-1:0] ;
      if (sys_addr[19:0]==20'h10)   set_dly       <= sys_wdata[32-1:0] ;
      if (sys_addr[19:0]==20'h14)   set_dec       <= sys_wdata[17-1:0] ;
      if (sys_addr[19:0]==20'h20)   set_a_hyst    <= sys_wdata[12-1:0] ;
      if (sys_addr[19:0]==20'h24)   set_b_hyst    <= sys_wdata[12-1:0] ;
      if (sys_addr[19:0]==20'h28)   set_avg_en    <= sys_wdata[     0] ;


      if (sys_addr[19:0]==20'h50)   set_a_axi_start <= sys_wdata[32-1:0] ;
      if (sys_addr[19:0]==20'h54)   set_a_axi_stop  <= sys_wdata[32-1:0] ;
      if (sys_addr[19:0]==20'h58)   set_a_axi_dly   <= sys_wdata[32-1:0] ;
      if (sys_addr[19:0]==20'h5C)   set_a_axi_en    <= sys_wdata[     0] ;

      if (sys_addr[19:0]==20'h70)   set_b_axi_start <= sys_wdata[32-1:0] ;
      if (sys_addr[19:0]==20'h74)   set_b_axi_stop  <= sys_wdata[32-1:0] ;
      if (sys_addr[19:0]==20'h78)   set_b_axi_dly   <= sys_wdata[32-1:0] ;
      if (sys_addr[19:0]==20'h7C)   set_b_axi_en    <= sys_wdata[     0] ;

      if (sys_addr[19:0]==20'h90)   set_deb_len     <= sys_wdata[20-1:0] ;
      // Offset 0x94 reserved for trigger unlock bit

   end
end

wire sys_en;
assign sys_en = sys_wen | sys_ren;

always @(posedge adc_clk2d_i)
if (adc_rstn_i == 1'b0) begin
   sys_err <= 1'b0 ;
   sys_ack <= 1'b0 ;
end else begin
   sys_err <= 1'b0 ;

   casez (sys_addr[19:0])
     20'h00000 : begin sys_ack <= sys_en;          sys_rdata <= {{32- 5{1'b0}}, adc_dly_end               // acquisition delay is over
                                                                              , adc_we_keep               // do not disarm on 
                                                                              , adc_trg_rd                // trigger status
                                                                              , 1'b0                      // reset
                                                                              , adc_we}             ; end // arm

     20'h00004 : begin sys_ack <= sys_en;          sys_rdata <= {{32- 5{1'b0}}, adc_trg_dis, set_trig_src}; end 

     20'h00008 : begin sys_ack <= sys_en;          sys_rdata <= {{32-12{1'b0}}, set_a_tresh}        ; end
     20'h0000C : begin sys_ack <= sys_en;          sys_rdata <= {{32-12{1'b0}}, set_b_tresh}        ; end
     20'h00010 : begin sys_ack <= sys_en;          sys_rdata <= {               set_dly}            ; end
     20'h00014 : begin sys_ack <= sys_en;          sys_rdata <= {{32-17{1'b0}}, set_dec}            ; end

     20'h00018 : begin sys_ack <= sys_en;          sys_rdata <= {{32-RSZ{1'b0}}, adc_wp_cur_rd}     ; end
     20'h0001C : begin sys_ack <= sys_en;          sys_rdata <= {{32-RSZ{1'b0}}, adc_wp_trig_rd}    ; end

     20'h00020 : begin sys_ack <= sys_en;          sys_rdata <= {{32-14{1'b0}}, set_a_hyst}         ; end
     20'h00024 : begin sys_ack <= sys_en;          sys_rdata <= {{32-14{1'b0}}, set_b_hyst}         ; end

     20'h00028 : begin sys_ack <= sys_en;          sys_rdata <= {{32- 1{1'b0}}, set_avg_en}         ; end

     20'h0002C : begin sys_ack <= sys_en;          sys_rdata <=                 adc_we_cnt_rd       ; end

     20'h00030 : begin sys_ack <= sys_en;          sys_rdata <=                 32'hc0ffe           ; end
     20'h00034 : begin sys_ack <= sys_en;          sys_rdata <=                 32'hc0ffe           ; end
     20'h00038 : begin sys_ack <= sys_en;          sys_rdata <=                 32'hc0ffe           ; end
     20'h0003C : begin sys_ack <= sys_en;          sys_rdata <=                 32'hc0ffe           ; end
     20'h00040 : begin sys_ack <= sys_en;          sys_rdata <=                 32'hc0ffe           ; end
     20'h00044 : begin sys_ack <= sys_en;          sys_rdata <=                 32'hc0ffe           ; end
     20'h00048 : begin sys_ack <= sys_en;          sys_rdata <=                 32'hc0ffe           ; end
     20'h0004C : begin sys_ack <= sys_en;          sys_rdata <=                 32'hc0ffe           ; end

     20'h00050 : begin sys_ack <= sys_en;          sys_rdata <=                 set_a_axi_start     ; end
     20'h00054 : begin sys_ack <= sys_en;          sys_rdata <=                 set_a_axi_stop      ; end
     20'h00058 : begin sys_ack <= sys_en;          sys_rdata <=                 set_a_axi_dly       ; end
     20'h0005C : begin sys_ack <= sys_en;          sys_rdata <= {{32- 1{1'b0}}, set_a_axi_en}       ; end
     20'h00060 : begin sys_ack <= sys_en;          sys_rdata <=                 set_a_axi_trig      ; end
     20'h00064 : begin sys_ack <= sys_en;          sys_rdata <=                 set_a_axi_cur       ; end

     20'h00070 : begin sys_ack <= sys_en;          sys_rdata <=                 set_b_axi_start     ; end
     20'h00074 : begin sys_ack <= sys_en;          sys_rdata <=                 set_b_axi_stop      ; end
     20'h00078 : begin sys_ack <= sys_en;          sys_rdata <=                 set_b_axi_dly       ; end
     20'h0007C : begin sys_ack <= sys_en;          sys_rdata <= {{32- 1{1'b0}}, set_b_axi_en}       ; end
     20'h00080 : begin sys_ack <= sys_en;          sys_rdata <=                 set_b_axi_trig      ; end
     20'h00084 : begin sys_ack <= sys_en;          sys_rdata <=                 set_b_axi_cur       ; end

     20'h00088 : begin sys_ack <= sys_en;          sys_rdata <= {{16- 5{1'b0}}, axi_b_state,
                                                                 {16- 5{1'b0}}, axi_a_state }       ; end
                                                                 
     20'h00090 : begin sys_ack <= sys_en;          sys_rdata <= {{32-20{1'b0}}, set_deb_len}        ; end

     20'h1???? : begin sys_ack <= adc_rd_dv;       sys_rdata <= {16'h0, 4'h0, adc_a_rd}             ; end
     20'h2???? : begin sys_ack <= adc_rd_dv;       sys_rdata <= {16'h0, 4'h0, adc_b_rd}             ; end

       default : begin sys_ack <= sys_en;          sys_rdata <=  32'h0                              ; end
   endcase
end

endmodule
