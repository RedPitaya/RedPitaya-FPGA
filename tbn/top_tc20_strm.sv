

`include "tb_defines.sv"

module top_tc20_strm ();
/*
localparam N_SAMP = 100000-1;
reg [15:0] mem_dac1[0:N_SAMP];
reg [15:0] mem_dac2[0:N_SAMP];
integer file1, readi1;
integer file2, readi2;

initial begin
  file1  = $fopen(`DAC_SRC_CH0,"r");
  $display("Loaded DAC file 1 %d ", file1);
  readi1 = $fread(mem_dac1[0],file1);
  $display("Loaded %0d entries for DAC file 1 \n", readi1);
  $fclose(file1);
end

initial begin
  file2  = $fopen(`DAC_SRC_CH1,"r");
  $display("Loaded DAC file 2 %d ", file2);
  readi2 = $fread(mem_dac2[0],file2);
  $display("Loaded %0d entries for DAC file 2 \n", readi2);
  $fclose(file2);
end*/
integer file3;

//default clocking cb @ (posedge gpio_sim.clk0);
default clocking cb @ (posedge top_tb.clk0);
endclocking: cb

logic [12-1:0] id_test;
logic [32-1:0] test;

task test_hk (
  int unsigned offset,
  int unsigned led=0 
);
  int unsigned dat;
  // test registers
  axi_read(offset+'h0, dat); //ID
  axi_read(offset+'h4, dat); //DNA
  axi_read(offset+'h8, dat); //DNA
  axi_write(offset+'h30, led); // LED
  axi_read(offset+'h30, dat); // LED

  ##1000;
  axi_write(offset+'h40, 1); // enable PLL
  ##1000;
  axi_read(offset+'h40, dat); // PLL status


  axi_write(offset+'h44, 32'hFFFF); // reset IDELAY

  //ADC SPI
  axi_write(offset+'h50, 32'h8016); // SPI offset
  axi_write(offset+'h54, 32'h20); // SPI offset
  ##1000;
  axi_read(offset+'h58, dat); // SPI offset

  //DAC SPI
  axi_write(offset+'h60, 32'h83); // SPI offset
  axi_write(offset+'h64, 32'h54); // SPI offset
  ##1000;
  axi_read(offset+'h68, dat); // SPI offset


  for (int k=0; k<4; k++) begin
  ##100;
   $display("%m - Increment IDELAY @%0t.", $time) ;
   axi_write(offset+'h48, 32'hFFFF); // increment IDELAY A
   //axi_write(offset+'h4C, 32'hFFFF); // increment IDELAY B
  end
  axi_write(offset+'h44, 32'hFFFF); // reset IDELAY

endtask: test_hk



////////////////////////////////////////////////////////////////////////////////
// Testing osciloscope
////////////////////////////////////////////////////////////////////////////////


task set_osc_dma(
  int offset,
  int buf_size,
  int buf_adr1_ch1,
  int buf_adr2_ch1,
  int buf_adr1_ch2,
  int buf_adr2_ch2,
  int buf_adr1_ch3,
  int buf_adr2_ch3,
  int buf_adr1_ch4,
  int buf_adr2_ch4
);
  axi_write(offset+'h58, buf_size);  // buffer size
  set_osc_dma_dest(offset+'h000, buf_adr1_ch1, buf_adr2_ch1); // destinations chA
  set_osc_dma_dest(offset+'h008, buf_adr1_ch2, buf_adr2_ch2); // destinations chB
  set_osc_dma_dest(offset+'h100, buf_adr1_ch3, buf_adr2_ch3); // destinations chC
  set_osc_dma_dest(offset+'h108, buf_adr1_ch4, buf_adr2_ch4); // destinations chD

endtask: set_osc_dma

task check_dma_lost(
  int offset,
  int mode
);
  if (mode == `ADC_INT_CHECK) begin
    check_dma_lost_single(offset+'h000, 1);  // lost samples on chA
    check_dma_lost_single(offset+'h040, 2);  // lost samples on chB
    check_dma_lost_single(offset+'h100, 3);  // lost samples on chC
    check_dma_lost_single(offset+'h140, 4);  // lost samples on chD
  end else begin
    check_dma_lost_single(offset+'h054, 1);  // lost samples on GPIO (checks B0 and B4)
  end
endtask: check_dma_lost


task check_dma_lost_single(
  int offset,
  int ch_num
);
  int buf1_lost;
  int buf2_lost;

  axi_read(offset+'h5C, buf1_lost);  // lost in buffer 1
  axi_read(offset+'h60, buf2_lost);  // lost in buffer 2

  if (buf1_lost > 0 || buf2_lost > 0) begin
    $display(`LFORMAT, `LVALS);
    file3=$fopen("lost_samples.txt", "a");
    $fwrite(file3, `LFORMAT, `LVALS);  
    $fclose(file3);
  end
endtask: check_dma_lost_single

task set_osc_dma_dest(
  int offset,
  int buf_adr1,
  int buf_adr2
);
  axi_write(offset+'h064, buf_adr1);  // buffer 1
  axi_write(offset+'h068, buf_adr2);  // buffer 2
endtask: set_osc_dma_dest

task osc_dma_start(
  int offset
);
  int init_ctrl;
  init_ctrl = (1<<`CTRL_MODE_STREAM_ADC) +
              (1<<`CTRL_RESET_ADC      ) +
              (1<<`CTRL_BUF2_ACK       ) +
              (1<<`CTRL_BUF1_ACK       ) +
              (1<<`CTRL_INTR_ACK       ) ;

  axi_write(offset+'h50, init_ctrl    );
  axi_write(offset+'h50, 1<<`CTRL_STRT);
endtask: osc_dma_start

task set_osc_cal(
  int offset,
  int cal_ofs,
  int cal_gain
);
  axi_write(offset+'h074, cal_ofs);  // offset
  axi_write(offset+'h078, cal_gain);  // gain
endtask: set_osc_cal


task set_osc_filt(
  int offset,
  int filt_aa,
  int filt_bb,
  int filt_kk,
  int filt_pp
);
  axi_write(offset+'hC0, filt_aa);  // AA factor
  axi_write(offset+'hC4, filt_bb);  // BB factor
  axi_write(offset+'hC8, filt_kk);  // KK factor
  axi_write(offset+'hCC, filt_pp);  // PP factor

endtask: set_osc_filt

task set_osc_basic(
  int unsigned offset,
  int trig_mask,
  int pre_trig_s,
  int post_trig_s,
  int trig_lo,
  int trig_hi,
  int trig_edge,
  int dec_fact,
  int dec_shift, 
  int avg_en,
  int filt_byp,
  int loopback,
  int use_8bit
  );

   int unsigned dat;
id_test = {4'h0,offset[27:20]};

  ##100;
  // configure
  axi_write(offset+'h10, pre_trig_s );  // pre trigger samples
  axi_write(offset+'h14, post_trig_s);  // pre trigger samples
  axi_write(offset+'h20, trig_lo    );  // LOW LEVEL TRIG
  axi_write(offset+'h24, trig_hi    );  // HI LEVEL TRIG
  axi_write(offset+'h28, trig_edge  );  // TRIG EDGE
  axi_write(offset+'h30, dec_fact   );  // decimation factor
  axi_write(offset+'h34, dec_shift  );  // decimation shift
  axi_write(offset+'h38, avg_en     );  // averaging enable
  axi_write(offset+'h3C, filt_byp   );  // filter bypass
  axi_write(offset+'h40, loopback   );  // loopback
  axi_write(offset+'h44, use_8bit   );  // loopback
  axi_write(offset+'h08, trig_mask  );  // start
endtask: set_osc_basic

task set_osc_event(
  int offset
);
  axi_write(offset+'h00, 1<<`RESET_EVENT  );  // reset
  axi_write(offset+'h00, 1<<`STOP_EVENT   );  // stop
  axi_write(offset+'h04, `OSC1_EVENT      );  // osc1 events
  axi_write(offset+'h00, 1<<`START_EVENT  );  // start
endtask: set_osc_event

task set_osc_full(
  int unsigned offset,
  int trig_mask,
  int pre_trig_s,
  int post_trig_s,
  int trig_lo,
  int trig_hi,
  int trig_edge,
  int dec_fact,
  int dec_shift, 
  int avg_en,
  int filt_byp,
  int loopback,
  int use_8bit,
  int cal_ofs,
  int cal_gain,
  int filt_aa,
  int filt_bb,
  int filt_kk,
  int filt_pp,
  int buf_size,
  int buf_adr1_ch1,
  int buf_adr2_ch1,
  int buf_adr1_ch2,
  int buf_adr2_ch2,
  int buf_adr1_ch3,
  int buf_adr2_ch3,
  int buf_adr1_ch4,
  int buf_adr2_ch4
  );

   int unsigned dat;

  ##100;
  // configure

  set_osc_basic(.offset(offset),          .trig_mask(trig_mask), 
                .pre_trig_s(pre_trig_s),  .post_trig_s(post_trig_s),
                .trig_lo(trig_lo),        .trig_hi(trig_hi),          .trig_edge(trig_edge),
                .dec_fact(dec_fact),      .dec_shift(dec_shift),      .avg_en(avg_en),
                .filt_byp(filt_byp),      .loopback(loopback),        .use_8bit(use_8bit));

  
  set_osc_cal(offset+'h000, cal_ofs, cal_gain); // chA set cal
  set_osc_cal(offset+'h008, cal_ofs, cal_gain); // chB set cal
  set_osc_cal(offset+'h100, cal_ofs, cal_gain); // chC set cal
  set_osc_cal(offset+'h108, cal_ofs, cal_gain); // chD set cal

  set_osc_filt(offset+'h000, filt_aa, filt_bb, filt_kk, filt_pp); // chA set filters
  set_osc_filt(offset+'h010, filt_aa, filt_bb, filt_kk, filt_pp); // chB set filters
  set_osc_filt(offset+'h100, filt_aa, filt_bb, filt_kk, filt_pp); // chC set filters
  set_osc_filt(offset+'h110, filt_aa, filt_bb, filt_kk, filt_pp); // chD set filters

  set_osc_event(offset);

  set_osc_dma(.offset(offset),              .buf_size(buf_size), 
              .buf_adr1_ch1(buf_adr1_ch1),  .buf_adr2_ch1(buf_adr2_ch1),
              .buf_adr1_ch2(buf_adr1_ch2),  .buf_adr2_ch2(buf_adr2_ch2),
              .buf_adr1_ch3(buf_adr1_ch3),  .buf_adr2_ch3(buf_adr2_ch3),
              .buf_adr1_ch4(buf_adr1_ch4),  .buf_adr2_ch4(buf_adr2_ch4));

  osc_dma_start(offset);

endtask: set_osc_full

task scope_test(
  int unsigned offset,
  int cycles,
  int delay
  );

localparam TRIG_MASK          =   'h4;
localparam TRIG_PRE_SAMP      =   'd100;
localparam TRIG_POST_SAMP     =   'd1000;
localparam TRIG_LOW_LEVEL     =  -'d4;
localparam TRIG_HIGH_LEVEL    =   'd4;
localparam TRIG_EDGE          =     1;
localparam DEC_FACTOR         =   'd2;
localparam DEC_RSHIFT         =   'd0;
localparam AVG_EN             =     0;
localparam FILT_BYPASS        =     0;
localparam LOOPBACK           =     0;
localparam SHIFT_8BIT         =     0;
localparam DMA_BUF_SIZE       = 32'h800;

localparam DMA_DST_ADDR1_CH1  = 32'h110000;
localparam DMA_DST_ADDR2_CH1  = 32'h118000;
localparam DMA_DST_ADDR1_CH2  = 32'h210000;
localparam DMA_DST_ADDR2_CH2  = 32'h218000;
localparam DMA_DST_ADDR1_CH3  = 32'h310000;
localparam DMA_DST_ADDR2_CH3  = 32'h318000;
localparam DMA_DST_ADDR1_CH4  = 32'h410000;
localparam DMA_DST_ADDR2_CH4  = 32'h418000;

localparam FILT_COEFF_AA      = 32'h7D93;
localparam FILT_COEFF_BB      = 32'h497C7;
localparam FILT_COEFF_KK      = 32'hD9999A;
localparam FILT_COEFF_PP      = 32'h2666;

localparam CALIB_OFFSET       = 16'h0;
localparam CALIB_GAIN         = 16'h2000;

id_test = {4'h0,offset[27:20]};

  ##100;
  // configure

  set_osc_full( .offset(offset),            .trig_mask(TRIG_MASK), 
                .pre_trig_s(TRIG_PRE_SAMP), .post_trig_s(TRIG_POST_SAMP),
                .trig_lo(TRIG_LOW_LEVEL),   .trig_hi(TRIG_HIGH_LEVEL),          .trig_edge(TRIG_EDGE),
                .dec_fact(DEC_FACTOR),      .dec_shift(DEC_RSHIFT),      .avg_en(AVG_EN),
                .filt_byp(FILT_BYPASS),     .loopback(LOOPBACK),        .use_8bit(SHIFT_8BIT),
                .cal_ofs(CALIB_OFFSET),     .cal_gain(CALIB_GAIN),
                .filt_aa(FILT_COEFF_AA),    .filt_bb(FILT_COEFF_BB),
                .filt_kk(FILT_COEFF_KK),    .filt_pp(FILT_COEFF_PP),
                .buf_size(DMA_BUF_SIZE), 
                .buf_adr1_ch1(DMA_DST_ADDR1_CH1),  .buf_adr2_ch1(DMA_DST_ADDR2_CH1),
                .buf_adr1_ch2(DMA_DST_ADDR1_CH2),  .buf_adr2_ch2(DMA_DST_ADDR2_CH2),
                .buf_adr1_ch3(DMA_DST_ADDR1_CH3),  .buf_adr2_ch3(DMA_DST_ADDR2_CH3),
                .buf_adr1_ch4(DMA_DST_ADDR1_CH4),  .buf_adr2_ch4(DMA_DST_ADDR2_CH4));

  osc_handling(offset, cycles, delay);

endtask: scope_test

task osc_handling(
  int offset,
  int cycles,
  int delay
);

  int i;
for (i=0; i<cycles; i++) begin: osc_testing
  int_ack(offset+'h50, `ADC_INT_CHECK);
  int_ack(offset+'h50, `ADC_INT_CHECK);
  int_ack_del(offset+'h50, `ADC_INT_CHECK, delay);
end

endtask: osc_handling



////////////////////////////////////////////////////////////////////////////////
// Testing osciloscope
////////////////////////////////////////////////////////////////////////////////
task test_gpio(
  int unsigned offset,
  int cycles,
  int delay
);
localparam TRIG_MASK          =   'h10;
localparam TRIG_CMP_MASK      =   'h10;

localparam TRIG_PRE_SAMP      =   'd2000;
localparam TRIG_POST_SAMP     =   'd6000;
localparam TRIG_LOW_LEVEL     =  -'d4;
localparam TRIG_HIGH_LEVEL    =   'd4;
localparam TRIG_EDGE_POS      =     1;
localparam TRIG_EDGE_NEG      =     0;
localparam TRIG_SEL           =   'h4;
localparam DEC_FACTOR         =   'd2;
localparam RLE_EN             =   'h1;
localparam POLARITY           =   'h0;
localparam DIR_P              =   'h0;
localparam DIR_N              =   'h0;


localparam DMA_BUF_SIZE       = 32'h800;
localparam DMA_DST_ADDR1_IN   = 32'h510000;
localparam DMA_DST_ADDR2_IN   = 32'h518000;
localparam DMA_DST_ADDR1_OUT  = 32'h610000;
localparam DMA_DST_ADDR2_OUT  = 32'h618000;
localparam DMA_STEP           = 32'h1000;

  int unsigned dat;

id_test = {4'h0,offset[27:20]};

  ##100;
  // configure

  axi_write(offset+'h10, TRIG_PRE_SAMP);  // pre trigger samples
  axi_write(offset+'h14, TRIG_POST_SAMP); // pre trigger samples
  axi_write(offset+'h40, TRIG_CMP_MASK);  // trig compare mask
  axi_write(offset+'h44, TRIG_MASK);      // trig mask
  axi_write(offset+'h48, TRIG_EDGE_POS);  // TRIG EDGE POS
  axi_write(offset+'h4C, TRIG_EDGE_POS);  // TRIG EDGE POS

  axi_write(offset+'h50, DEC_FACTOR);     // decimation number
  axi_write(offset+'h54, RLE_EN);         // run length encoding enable
  axi_write(offset+'h60, POLARITY);       // bitwise polarity of inputs
  axi_write(offset+'h70, DIR_P);          // direction of P inputs
  axi_write(offset+'h74, DIR_N);          // direction of N inputs

  axi_write(offset+'h84, TRIG_SEL);       // trigger
  axi_write(offset+'hC0, DMA_STEP);       // read address step

  set_gpio_dma(.offset(offset),                  .buf_size(DMA_BUF_SIZE),
               .buf_adr1_in(DMA_DST_ADDR1_IN),   .buf_adr2_in(DMA_DST_ADDR2_IN),
               .buf_adr1_out(DMA_DST_ADDR1_OUT), .buf_adr2_out(DMA_DST_ADDR2_OUT)); 
  
  set_gpio_event(offset);
  gpio_dma_start(offset);
  gpio_handling(offset, cycles, delay);

endtask: test_gpio

task set_gpio_event(
  int offset
);
  axi_write(offset+'h88, 32'h0            );  // reset
  axi_write(offset+'h88, 1<<`RESET_EVENT  );  // reset
  axi_write(offset+'h88, 1<<`STOP_EVENT   );  // stop
  axi_write(offset+'h80, `LA_EVENT        );  // osc1 events
  axi_write(offset+'h88, 1<<`START_EVENT  );  // start
endtask: set_gpio_event

task set_gpio_dma(
  int offset,
  int buf_size    ,
  int buf_adr1_in ,
  int buf_adr2_in ,
  int buf_adr1_out,
  int buf_adr2_out
);
  axi_write(offset+'h9C, buf_size    );  // buffer size
  axi_write(offset+'hA0, buf_adr1_in );  // buffer 1 - IN
  axi_write(offset+'hA8, buf_adr2_in );  // buffer 2 - IN
  axi_write(offset+'hA4, buf_adr1_out);  // buffer 1 - OUT
  axi_write(offset+'hAC, buf_adr2_out);  // buffer 2 - OUT
endtask: set_gpio_dma

task gpio_dma_start(
  int offset
);
  int init_ctrl;
  init_ctrl = (1<<`CTRL_MODE_STREAM_ADC) +
              (1<<`CTRL_RESET_ADC      ) +
              (1<<`CTRL_BUF2_ACK       ) +
              (1<<`CTRL_BUF1_ACK       ) +
              (1<<`CTRL_INTR_ACK       ) ;
##20;
  axi_write(offset+'h8C, init_ctrl    );
##20;
  axi_write(offset+'h8C, 1<<`CTRL_STRT);
##10;
  axi_write(offset+'h90, 'h0    );

  axi_write(offset+'h8C, init_ctrl    );
##10;
  axi_write(offset+'h8C, 1<<`CTRL_STRT);
  init_ctrl = (1<<`CTRL_MODE_STREAM_DAC) +
              (1<<`CTRL_RESET_DAC      );
##10;
  axi_write(offset+'h90, init_ctrl    );
##10;
  axi_write(offset+'h90, 1<<`CTRL_STRT);
endtask: gpio_dma_start

task gpio_handling(
  int offset,
  int cycles,
  int delay
);
  int i;
for (i=0; i<cycles; i++) begin: gpio_testing
  fork
    begin
    buf_ack(offset+'h98, offset+'h90); // OUT handler
    buf_ack(offset+'h98, offset+'h90);
    end
    begin
    int_ack(offset+'h8C, `GPIO_INT_CHECK); // IN handler
    int_ack(offset+'h8C, `GPIO_INT_CHECK);
    end
  join
  //buf_ack_del(offset, delay);
end
endtask: gpio_handling


task wait_clks(
  int unsigned del
);
  logic [32-1:0] cnt = 0;
  do begin
    @(posedge top_tb.clk0);
    cnt <= cnt + 1;
  end while (cnt < del);
endtask: wait_clks

task create_resp(
  input logic buf1_cha,
  input logic buf2_cha,
  input logic buf1_chb,
  input logic buf2_chb,
  input int   buffer,
  output logic [32-1:0] resp
);
  if (buffer == 1) begin
    resp = (buf1_cha << `CTRL_BUF2_RDY) + (buf1_chb << (`CTRL_BUF2_RDY+8));
  end else if (buffer == 2) begin
    resp = (buf2_cha << `CTRL_BUF1_RDY) + (buf2_chb << (`CTRL_BUF1_RDY+8));
  end
endtask: create_resp

task buf_ack(
  int unsigned sts_reg,
  int unsigned ctl_reg
);
  logic [32-1:0] dat;
  logic buf1_cha = 1'b0;
  logic buf1_chb = 1'b0;
  logic buf2_cha = 1'b0;
  logic buf2_chb = 1'b0;
  logic [32-1:0]   resp;
  logic test1;
  logic test2;
  logic [32-1:0]   test3;

  ##20;
  do begin
    axi_read(sts_reg, dat);
      //$display("read out %x",dat[`END_STATE_BUF1]);
    buf1_cha = dat[`END_STATE_BUF1];
    buf1_chb = dat[`END_STATE_BUF1+16];
    buf2_cha = dat[`END_STATE_BUF2];
    buf2_chb = dat[`END_STATE_BUF2+16];
    @(posedge top_tb.clk0);
  end while ((buf1_cha || buf1_chb) != 1'b1); // BUF 1 is full
  create_resp(buf1_cha, buf2_cha, buf1_chb, buf2_chb, 1, resp);
  ##1000;

  axi_write(ctl_reg, resp);  // BUF1 ACK

  @(posedge top_tb.clk0);
    buf1_cha = 1'b0;
    buf1_chb = 1'b0;
    buf2_cha = 1'b0;
    buf2_chb = 1'b0;  
  do begin
    axi_read(sts_reg, dat);
    buf1_cha = dat[`END_STATE_BUF1];
    buf1_chb = dat[`END_STATE_BUF1+16];
    buf2_cha = dat[`END_STATE_BUF2];
    buf2_chb = dat[`END_STATE_BUF2+16];
    @(posedge top_tb.clk0);
  end while ((buf2_cha || buf2_chb) != 1'b1); // BUF 2 is full
  create_resp(buf1_cha, buf2_cha, buf1_chb, buf2_chb, 2, resp);
  ##1000;
  axi_write(ctl_reg, resp);  // BUF1 ACK

endtask: buf_ack

task buf_ack_del(
  int unsigned sts_reg,
  int unsigned ctl_reg,
  int del
);
  logic [32-1:0] dat;
  logic buf1_cha = 1'b0;
  logic buf1_chb = 1'b0;
  logic buf2_cha = 1'b0;
  logic buf2_chb = 1'b0;
  logic [32-1:0] resp;
  do begin
    axi_read(sts_reg, dat);
      //$display("read out %x",dat[`END_STATE_BUF1]);
    buf1_cha = dat[`END_STATE_BUF1];
    buf1_chb = dat[`END_STATE_BUF1+16];
    buf2_cha = dat[`END_STATE_BUF2];
    buf2_chb = dat[`END_STATE_BUF2+16];
    @(posedge top_tb.clk0);
  end while ((buf1_cha || buf1_chb) != 1'b1); // BUF 1 is full
  create_resp(buf1_cha, buf2_cha, buf1_chb, buf2_chb, 1, resp);

  wait_clks(del);
  axi_write(ctl_reg, resp);  // BUF1 ACK

  do begin
    axi_read(sts_reg, dat);
    buf1_cha = dat[`END_STATE_BUF1];
    buf1_chb = dat[`END_STATE_BUF1+16];
    buf2_cha = dat[`END_STATE_BUF2];
    buf2_chb = dat[`END_STATE_BUF2+16];
    @(posedge top_tb.clk0);
  end while ((buf2_cha || buf2_chb) != 1'b1); // BUF 2 is full
  create_resp(buf1_cha, buf2_cha, buf1_chb, buf2_chb, 2, resp);
  
  wait_clks(del);
  axi_write(ctl_reg, resp);  // BUF1 ACK

endtask: buf_ack_del




task int_ack(
  int unsigned ctl_reg,
  int mode
);
  ##20;
  do begin
    @(posedge top_tb.clk0);
  end while (`IP_PS_LOC.IRQ_F2P[15] != 1'b1); // BUF 1 is full
  //end while (1); // BUF 1 is full
    @(posedge top_tb.clk0);
  axi_write(ctl_reg, 1<<`CTRL_INTR_ACK);  // INTR ACK
  ##500;
  axi_write(ctl_reg, 1<<`CTRL_BUF1_ACK);  // BUF1 ACK
  check_dma_lost(ctl_reg, mode);

  do begin
    @(posedge top_tb.clk0);
  end while (`IP_PS_LOC.IRQ_F2P[15] != 1'b1); // BUF 2 is full
  //  end while (1); // BUF 2 is full

    @(posedge top_tb.clk0);
  axi_write(ctl_reg, 1<<`CTRL_INTR_ACK);  // INTR ACK
  ##500;
  axi_write(ctl_reg, 1<<`CTRL_BUF2_ACK);  // BUF2 ACK 
  check_dma_lost(ctl_reg, mode);

endtask: int_ack

task int_ack_del(
  int unsigned ctl_reg,
  int mode,
  int del
);
  do begin
    @(posedge top_tb.clk0);
  end while (`IP_PS_LOC.IRQ_F2P[15] != 1'b1); // BUF 1 is full
  //  end while (1); // BUF 1 is full

  wait_clks(del/4);
  axi_write(ctl_reg, 1<<`CTRL_INTR_ACK);  // INTR ACK

  wait_clks(del);
  axi_write(ctl_reg, 1<<`CTRL_BUF1_ACK);  // BUF1 ACK

  check_dma_lost(ctl_reg, mode);

  do begin
    @(posedge top_tb.clk0);
  end while (`IP_PS_LOC.IRQ_F2P[15] != 1'b1); // BUF 2 is full
  //  end while (1); // BUF 1 is full

  wait_clks(del/4);
  axi_write(ctl_reg, 1<<`CTRL_INTR_ACK);  // INTR ACK

  wait_clks(del);
  axi_write(ctl_reg, 1<<`CTRL_BUF2_ACK);  // BUF2 ACK

  check_dma_lost(ctl_reg, mode);
endtask: int_ack_del

////////////////////////////////////////////////////////////////////////////////
// Testing DAC stream
////////////////////////////////////////////////////////////////////////////////

task test_dac(
  int unsigned offset,
  int cycles,
  int delay
);
  localparam GAIN_CHA     = 16'h2000;
  localparam OFFS_CHA     = 16'h0;
  localparam GAIN_CHB     = 16'h2000;
  localparam OFFS_CHB     = 16'h0;
  localparam STEP_CHA     = 32'h4000;
  localparam STEP_CHB     = 32'h4000;
  localparam SHIFT_CHA    = 32'h0;
  localparam SHIFT_CHB    = 32'h0;
  localparam TRIG_SEL     = 32'h1;
  localparam BUF_SIZE     = 32'h800;
  localparam BUF1_ADR_CHA = 32'h710000;
  localparam BUF2_ADR_CHA = 32'h718000;
  localparam BUF1_ADR_CHB = 32'h810000;
  localparam BUF2_ADR_CHB = 32'h818000;

  // configure
  axi_write(offset+'h0,   'd0);  // DAC module setup, currently unsupported
  set_dac_cal(offset, OFFS_CHA, GAIN_CHA, OFFS_CHB, GAIN_CHB);
  axi_write(offset+'h08, STEP_CHA);  // step CHA
  axi_write(offset+'h14, STEP_CHB);  // step CHB
  axi_write(offset+'h24, TRIG_SEL);  // trigger select
  axi_write(offset+'h60, SHIFT_CHA);  // shift right CHA
  axi_write(offset+'h64, SHIFT_CHB);  // shift right CHA

  set_dac_dma(.offset(offset),              .buf_size(BUF_SIZE),
              .buf_adr1_ch1(BUF1_ADR_CHA),  .buf_adr2_ch1(BUF1_ADR_CHA),
              .buf_adr1_ch2(BUF1_ADR_CHB),  .buf_adr2_ch2(BUF2_ADR_CHB)); 


  dac_dma_start(offset);

  dac_handling(offset, cycles, delay);
endtask: test_dac

task set_dac_cal(
  int offset,
  int cal_ofs_cha,
  int cal_gain_cha,
  int cal_ofs_chb,
  int cal_gain_chb
);
  axi_write(offset+'h004, {cal_ofs_cha[15:0], cal_gain_cha[15:0]}); // CHA
  axi_write(offset+'h010, {cal_ofs_chb[15:0], cal_gain_chb[15:0]}); // CHB
endtask: set_dac_cal

task set_dac_dma(
  int offset,
  int buf_size,
  int buf_adr1_ch1,
  int buf_adr2_ch1,
  int buf_adr1_ch2,
  int buf_adr2_ch2
);
  axi_write(offset+'h34, buf_size);  // buffer size
  axi_write(offset+'h38, buf_adr1_ch1);  // buffer 1 - chA
  axi_write(offset+'h3C, buf_adr2_ch1);  // buffer 2 - chA
  axi_write(offset+'h40, buf_adr1_ch2);  // buffer 1 - chB
  axi_write(offset+'h44, buf_adr2_ch2);  // buffer 2 - chB
endtask: set_dac_dma

task set_dac_event(
  int offset
);
  axi_write(offset+'h1C, 0                );  // reset reg
  axi_write(offset+'h1C, 1<<`RESET_EVENT  );  // reset
  axi_write(offset+'h1C, 1<<`STOP_EVENT   );  // stop
  axi_write(offset+'h20, `GEN1_EVENT      );  // osc1 events
  axi_write(offset+'h1C, 1<<`START_EVENT  );  // start
endtask: set_dac_event

task dac_handling(
  int offset,
  int cycles,
  int delay
);

  int i;
for (i=0; i<cycles; i++) begin: dac_testing
  buf_ack(offset+'h2C, offset+'h28);
  buf_ack(offset+'h2C, offset+'h28);
  //buf_ack_del(offset, delay);
end

endtask: dac_handling

task dac_dma_start(
  int offset
);
  axi_write(offset+'h28, ((1<<`CTRL_RESET_DAC+8)       + (1<<`CTRL_RESET_DAC)));
  axi_write(offset+'h28, ((1<<`CTRL_MODE_STREAM_DAC+8) + (1<<`CTRL_MODE_STREAM_DAC)));
  axi_write(offset+'h28, ((1<<`CTRL_STRT+8)            + (1<<`CTRL_STRT)));
endtask: dac_dma_start

task test_reg_rw (
  int offset,
  int val,
  int reg_adr
);
  int dat;
  axi_write(offset+reg_adr, val); // write value, check number of valid bits!
  axi_read(offset+reg_adr, dat); // read written value

  if (dat == val)
    $display("Register read/write operation OK!");
  else
    $display("Register read/write operation NOK!");

  $display("Tested register address: %x, test value: %x", (offset+reg_adr), val);

endtask: test_reg_rw



////////////////////////////////////////////////////////////////////////////////
// AXI4 read/write tasks
////////////////////////////////////////////////////////////////////////////////
task axi_write (
  input  logic [32-1:0] adr,
  input  logic [32-1:0] dat
);
  `AXI_REG_LOC.wr_single(
    .dat_i  (dat),
    .adr_i  (adr),
    .id_i   (0),
    .size_i (3'b010),
    .lock_i (0),
    .prot_i (0)
);
endtask: axi_write


task axi_read (
  input  logic [32-1:0] adr,
  output logic [32-1:0] dat
);
  `AXI_REG_LOC.rd_single(
    .dat_o  (dat),
    .adr_i  (adr),
    .id_i   (0),
    .size_i (3'b010),
    .lock_i (0),
    .prot_i (0)
);
endtask: axi_read

/*
task axi_write (
  input  logic [32-1:0] adr,
  input  logic [32-1:0] dat
);

  @(posedge top_tb.clk0);
endtask: axi_write


task axi_read (
  input  logic [32-1:0] adr,
  output logic [32-1:0] dat
);
  @(posedge top_tb.clk0);
endtask: axi_read
*/
endmodule
