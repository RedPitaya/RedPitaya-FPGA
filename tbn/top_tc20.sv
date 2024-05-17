

`include "tb_defines.sv"

module top_tc20 ();
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
end
*/

default clocking cb @ (posedge top_tb.clk0);
endclocking: cb

task init_adc_01(
  int unsigned offset
);
localparam CHA_THR      = 32'd100;
localparam CHB_THR      = 32'd100;
localparam TRG_SRC      =  3'h0;
localparam TRG_DLY      = 32'h100;
localparam TRG_DEB      = 32'd100;
localparam ADCTRG_DEB   = 32'd1000;
localparam DEC          = 32'd1;
localparam DEC_AVG      =  1'b1;
localparam CHA_HYST     = 32'd10;
localparam CHB_HYST     = 32'd10;
localparam CHA_AA       = 32'h7D93;
localparam CHA_BB       = 32'h497C7;
localparam CHA_KK       = 32'hD9999A;
localparam CHA_PP       = 32'h2666;
localparam CHB_AA       = 32'h7D93;
localparam CHB_BB       = 32'h497C7;
localparam CHB_KK       = 32'hD9999A;
localparam CHB_PP       = 32'h2666;
localparam CHA_AXI_LADR = 32'h100000;
localparam CHA_AXI_HADR = 32'h110000;
localparam CHA_AXI_TDLY = 32'h800;
localparam CHA_AXI_EN   =  1'b1;
localparam CHB_AXI_LADR = 32'h200000;
localparam CHB_AXI_HADR = 32'h210000;
localparam CHB_AXI_TDLY = 32'h800;
localparam CHB_AXI_EN   =  1'b1;

set_osc(.offset(offset),    
        .cha_thr(CHA_THR),             .chb_thr(CHB_THR),  
        .trig_src(TRG_SRC),            .trig_dly(TRG_DLY),           .trig_deb(TRG_DEB),  .adctrig_deb(ADCTRG_DEB),
        .dec(DEC),                     .dec_avg(DEC_AVG),
        .cha_hyst(CHA_HYST),           .chb_hyst(CHB_HYST),
        .cha_aa(CHA_AA),               .cha_bb(CHA_BB),              .cha_kk(CHA_KK),     .cha_pp(CHA_PP),
        .chb_aa(CHB_AA),               .chb_bb(CHB_BB),              .chb_kk(CHB_KK),     .chb_pp(CHB_PP),
        .cha_axi_ladr(CHA_AXI_LADR),   .cha_axi_hadr(CHA_AXI_HADR),
        .cha_axi_trgdly(CHA_AXI_TDLY), .cha_axi_en(CHA_AXI_EN),
        .chb_axi_ladr(CHB_AXI_LADR),   .chb_axi_hadr(CHB_AXI_HADR),
        .chb_axi_trgdly(CHB_AXI_TDLY), .chb_axi_en(CHB_AXI_EN));
endtask: init_adc_01

task init_adc_23(
  int unsigned offset
);
localparam CHA_THR      = 32'd100;
localparam CHB_THR      = 32'd100;
localparam TRG_SRC      =  3'h0;
localparam TRG_DLY      = 32'h100;
localparam TRG_DEB      = 32'd100;
localparam ADCTRG_DEB   = 32'd100;
localparam DEC          = 32'd1;
localparam DEC_AVG      =  1'b1;
localparam CHA_HYST     = 32'd10;
localparam CHB_HYST     = 32'd10;
localparam CHA_AA       = 32'h7D93;
localparam CHA_BB       = 32'h497C7;
localparam CHA_KK       = 32'hD9999A;
localparam CHA_PP       = 32'h2666;
localparam CHB_AA       = 32'h7D93;
localparam CHB_BB       = 32'h497C7;
localparam CHB_KK       = 32'hD9999A;
localparam CHB_PP       = 32'h2666;
localparam CHA_AXI_LADR = 32'h100000;
localparam CHA_AXI_HADR = 32'h101000;
localparam CHA_AXI_TDLY = 32'hFF8;
localparam CHA_AXI_EN   =  1'b1;
localparam CHB_AXI_LADR = 32'h100000;
localparam CHB_AXI_HADR = 32'h101000;
localparam CHB_AXI_TDLY = 32'hFF8;
localparam CHB_AXI_EN   =  1'b1;

set_osc(.offset(offset),    
        .cha_thr(CHA_THR),             .chb_thr(CHB_THR),  
        .trig_src(TRG_SRC),            .trig_dly(TRG_DLY),           .trig_deb(TRG_DEB),  .adctrig_deb(ADCTRG_DEB),
        .dec(DEC),                     .dec_avg(DEC_AVG),
        .cha_hyst(CHA_HYST),           .chb_hyst(CHB_HYST),
        .cha_aa(CHA_AA),               .cha_bb(CHA_BB),              .cha_kk(CHA_KK),     .cha_pp(CHA_PP),
        .chb_aa(CHB_AA),               .chb_bb(CHB_BB),              .chb_kk(CHB_KK),     .chb_pp(CHB_PP),
        .cha_axi_ladr(CHA_AXI_LADR),   .cha_axi_hadr(CHA_AXI_HADR),
        .cha_axi_trgdly(CHA_AXI_TDLY), .cha_axi_en(CHA_AXI_EN),
        .chb_axi_ladr(CHB_AXI_LADR),   .chb_axi_hadr(CHB_AXI_HADR),
        .chb_axi_trgdly(CHB_AXI_TDLY), .chb_axi_en(CHB_AXI_EN));
endtask: init_adc_23

task init_dac(
  int unsigned offset
);
localparam CHA_TRIG_SRC =  3'h1;
localparam CHA_WRAP     =  1'b0;
localparam CHA_ONCE     =  1'b0;
localparam CHA_RST      =  1'b0;
localparam CHA_ZERO     =  1'b0;
localparam CHA_RGATE    =  1'b0;
localparam CHB_TRIG_SRC =  3'h1;
localparam CHB_WRAP     =  1'b1;
localparam CHB_ONCE     =  1'b0;
localparam CHB_RST      =  1'b0;
localparam CHB_ZERO     =  1'b0;
localparam CHB_RGATE    =  1'b0;
localparam CHA_AMP      = 14'h2000;
localparam CHA_DC       = 14'h0;
localparam CHB_AMP      = 14'h2000;
localparam CHB_DC       = 14'h0;
localparam CHA_SIZE     = 32'h10000;
localparam CHA_OFFS     = 32'h0;
localparam CHA_STEP     = 32'h3150;
localparam CHA_STEP_LO  = 32'h0;
localparam CHA_NCYC     = 16'd10;
localparam CHA_RNUM     = 16'd1;
localparam CHA_RDLY     = 32'd20;
localparam CHA_LAST     = 14'h0;
localparam CHA_FIRST    = 14'h10;
localparam CHB_SIZE     = 32'h800;
localparam CHB_OFFS     = 32'h0;
localparam CHB_STEP     = 32'h3150;
localparam CHB_STEP_LO  = 32'h0;
localparam CHB_NCYC     = 16'd3;
localparam CHB_RNUM     = 16'd999;
localparam CHB_RDLY     = 32'd20;
localparam CHB_LAST     = 14'h100;
localparam CHB_FIRST    = 14'h200;
localparam DEB_LEN      = 20'h1;
localparam NUM_SAMP     = 32'h4000;
localparam SET_BUF      =  1'b1;

set_asg_init( .offset(offset),
              .cha_trig_src(CHA_TRIG_SRC), .cha_wrap(CHA_WRAP),   .cha_once(CHA_ONCE),   .cha_rst(CHA_RST), .cha_zero(CHA_ZERO), 
              .chb_trig_src(CHB_TRIG_SRC), .chb_wrap(CHB_WRAP),   .chb_once(CHB_ONCE),   .chb_rst(CHB_RST), .chb_zero(CHB_ZERO), 
              .cha_rgate(CHA_RGATE),       .chb_rgate(CHB_RGATE),
              .cha_amp(CHA_AMP),           .cha_dc(CHA_DC),       .chb_amp(CHB_AMP),     .chb_dc(CHB_DC),
              //.cha_size(CHA_SIZE),         .chb_size(CHB_SIZE),
              .cha_size(NUM_SAMP<<14),     .chb_size(NUM_SAMP<<14),
              .cha_offs(CHA_OFFS),         .chb_offs(CHB_OFFS),
              .cha_step(CHA_STEP),         .cha_step_lo(CHA_STEP_LO),
              .chb_step(CHB_STEP),         .chb_step_lo(CHB_STEP_LO),
              .cha_rnum(CHA_RNUM),         .cha_rdly(CHA_RDLY),   .cha_ncyc(CHA_NCYC),
              .chb_rnum(CHB_RNUM),         .chb_rdly(CHB_RDLY),   .chb_ncyc(CHB_NCYC),
              .cha_first(CHA_FIRST),       .cha_last(CHA_LAST),   .chb_first(CHB_FIRST), .chb_last(CHB_LAST),
              .deb_len(DEB_LEN),           .num_samp(NUM_SAMP),   .set_buf(SET_BUF));

endtask: init_dac

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
    axi_write(offset+'hc, 32'b0); // LED
   $display("HK setting") ;

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

task test_dac (
  int unsigned offset
);
  int init_ctrl;
  #5000;
  init_ctrl = ({29'h0, `SW_TRIG_ADC}  );
  axi_write(offset+'h00, init_ctrl);

  #1000;
  init_ctrl = (1<<`CTRL_DAC_ZERO      ) +
              ({29'h0, `SW_TRIG_ADC}  );  
  axi_write(offset+'h00, init_ctrl);

  #1000;
  init_ctrl = (0<<`CTRL_DAC_ZERO      ) +
              ({29'h0, `SW_TRIG_ADC}  );  
  axi_write(offset+'h00, init_ctrl);

  #1000;
  init_ctrl = (1<<`CTRL_DAC_RST      ) +
              ({29'h0, `SW_TRIG_ADC}  );  
  axi_write(offset+'h00, init_ctrl);

  #2000;
  init_ctrl = (0<<`CTRL_DAC_RST      ) +
              ({29'h0, `SW_TRIG_ADC}  );  
  axi_write(offset+'h00, init_ctrl);

  #1000;
  init_ctrl = 32'h0;
  axi_write(offset+'h00, init_ctrl);

  #1000;
  init_ctrl = ({29'h0, `SW_TRIG_ADC}  );
  axi_write(offset+'h00, init_ctrl);
/*
  init_ctrl = ({29'h0, `SW_TRIG_ADC}  );
  axi_write(offset+'h00, init_ctrl); // write trigger and reset at the same time


  init_ctrl = (1<<`CTRL_DAC_RST       ) +
            //  (1<<`CTRL_DAC_WRAP      ) +
              ({29'h0, `SW_TRIG_ADC}  );

  axi_write(offset+'h00, init_ctrl); // write trigger and reset at the same time
  ##1000;
  axi_write(offset+'h00, (1<<`CTRL_DAC_WRAP)); // write trigger and reset at the same time
  init_ctrl =((1<<`CTRL_DAC_WRAP      ) +
              {29'h0, `SW_TRIG_ADC}   );
  axi_write(offset+'h00, init_ctrl); // write trigger*/
endtask: test_dac


task daisy_trigs (
);
  int unsigned dat;
  // test registers
   $display("setting up daisy triggering") ;
  axi_write(32'h40000000+'h1000, 32'h1); // reset IDELAY
 // ##100;
 // axi_write(32'h40500000+'h0, 32'h1); // reset IDELAY
 // ##100;
 // axi_write(32'h40500000+'h0, 32'h3); // reset IDELAY
 // ##100;
 // axi_write(32'h40500000+'h4, 32'h1); // reset IDELAY

endtask: daisy_trigs

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
// Testing osciloscope
////////////////////////////////////////////////////////////////////////////////


task set_osc(
  int offset,
  int cha_thr,
  int chb_thr,
  int trig_src,
  int trig_dly,
  int trig_deb,
  int adctrig_deb,
  int dec,
  int dec_avg,
  int cha_hyst,
  int chb_hyst,
  int cha_aa,
  int cha_bb,
  int cha_kk,
  int cha_pp,
  int chb_aa,
  int chb_bb,
  int chb_kk,
  int chb_pp,
  int cha_axi_ladr,
  int cha_axi_hadr,
  int cha_axi_trgdly,
  int cha_axi_en,
  int chb_axi_ladr,
  int chb_axi_hadr,
  int chb_axi_trgdly,
  int chb_axi_en
);
   int unsigned dat;

  axi_write(offset+'h8 ,  cha_thr);  // chA threshold
  axi_write(offset+'hC ,  chb_thr);  // chB threshold
  axi_write(offset+'h4 ,  trig_src);  // manual trigger
  axi_write(offset+'h10,  trig_dly);  // delay after trigger
  axi_write(offset+'h110, trig_dly);  // delay after trigger

  axi_write(offset+'h90,  trig_deb);  // trig debounce
  //axi_write(offset+'h94,  adctrig_deb);  // ADC trig debounce

  axi_write(offset+'h14,  dec);  // decimation
  axi_write(offset+'h114, dec);  // decimation

  axi_write(offset+'h20,  cha_hyst);  // chA hysteresis
  axi_write(offset+'h24,  cha_hyst);  // chB hysteresis
  axi_write(offset+'h28,  dec_avg);  // enable signal average at decimation

  axi_write(offset+'h50,  cha_axi_ladr);  // chA AXI low address
  axi_write(offset+'h54,  cha_axi_hadr);  // chA AXI hi address
  axi_write(offset+'h58,  cha_axi_trgdly);  // chA AXI trig dly
  axi_write(offset+'h5C,  cha_axi_en);  // chA AXI enable master

  axi_write(offset+'h70,  chb_axi_ladr);  // chA AXI low address
  axi_write(offset+'h74,  chb_axi_hadr);  // chA AXI hi address
  axi_write(offset+'h78,  chb_axi_trgdly);  // chA AXI trig dly
  axi_write(offset+'h7C,  chb_axi_en);  // chA AXI enable master

  axi_write(offset+'h30,  cha_aa);  // filter
  axi_write(offset+'h34,  cha_bb);  // filter
  axi_write(offset+'h38,  cha_kk);  // filter
  axi_write(offset+'h3C,  cha_pp);  // filter
  
  axi_write(offset+'h40,  chb_aa);  // filter
  axi_write(offset+'h44,  chb_bb);  // filter
  axi_write(offset+'h48,  chb_kk);  // filter
  axi_write(offset+'h4C,  chb_pp);  // filter

endtask: set_osc


task test_osc(
  int offset,
  int trig_src,
  int cycles,
  int dec,
  int del,
  logic read_trig,
  int mode
);
   int unsigned dat;
int i;
  ##5000;

// MODE 0 regular BRAM mode, wait for the end of trigger
// MODE 1 AXI0 mode, wait for the end of trigger
// MODE 2 AXI1 mode, wait for the end of trigger
// MODE 3 trigger before end of delay

for (i=0; i<cycles; i++) begin: triggering
  if (mode != 3) begin
    axi_write(offset+'h0 ,  'd2  );  // reset
    wait_clks(del);
    axi_write(offset+'h14,  dec);  // decimation
    wait_clks(del);
  axi_write(offset+'h10,  32'h100);  // delay after trigger
  axi_write(offset+'h8 ,  32'd100);  // chA threshold
  axi_write(offset+'h20,  32'h29);  // chA hysteresis
  axi_write(offset+'h10,  32'h100);  // delay after trigger
    axi_write(offset+'h0 ,  'd1  );  // ARM trigger
    wait_clks(del);
    axi_write(offset+'h94 , 32'h1);    // clear trigger protect

    wait_clks(del);

    axi_write(offset+'h4 , trig_src);  // level trigger
    //#1000;
    //axi_write(offset+'h4 , 32'h1);  // manual trigger
  end
  if (mode == 0)
    reg_wait_bit(32'h40100000,32'h10);
  else if (mode == 1)
    reg_wait_bit(32'h40100088,32'h10);  
  else if (mode == 2)
    reg_wait_bit(32'h40100088,32'h100000);  
  else if (mode == 3) begin
    #2000;
    axi_write(offset+'h4 , trig_src);  // manual trigger
  end
    axi_write(offset+'h4 , 1);  // sw trigger

  if (read_trig)
    trig_samps(offset);
end

endtask: test_osc

task test_osc_common(
  int offset,
  int trig_src,
  int cycles,
  int dec,
  int del,
  logic read_trig,
  int mode
);
  reg [32-1:0] start_mask;
  reg [ 8-1:0] trig_src0;
  reg [ 8-1:0] trig_src1;
  reg [ 8-1:0] trig_src2;
  reg [ 8-1:0] trig_src3;

   int unsigned dat;
int i;
  ##5000;

    start_mask={4{8'h21}};
    trig_src0=8'h2;
    trig_src1=8'h4;
    trig_src2=8'hA;
    trig_src3=8'hC;
// MODE 0 regular BRAM mode, wait for the end of trigger
// MODE 1 AXI0 mode, wait for the end of trigger
// MODE 2 AXI1 mode, wait for the end of trigger
// MODE 3 trigger before end of delay
 
  axi_write(offset+'h14,  dec);  // decimation
  axi_write(offset+'h114, dec);  // decimation
  axi_write(32'h40200000+'h14,  dec);  // decimation
  axi_write(32'h40200000+'h114, dec);  // decimation
  axi_write(offset+'h0 ,  start_mask); // ARM trigger
  axi_write(offset+'h94,  {8'h1,8'h1,8'h1,8'h1}); // clear trigger protect
  //axi_write(offset+'h4 ,  {4{trig_src[7:0]}});  // level trigger
  axi_write(offset+'h4 ,  {trig_src3,trig_src2,trig_src1,trig_src0});  // level trigger
  axi_write(offset+'h28,  {4{8'h1}});  // enable decimation averaging

for (i=0; i<cycles; i++) begin: triggering
  //fork
    handle_channel(offset,trig_src0,read_trig, 1, mode);
    handle_channel(offset,trig_src1,read_trig, 2, mode);
    handle_channel(offset,trig_src2,read_trig, 3, mode);
    handle_channel(offset,trig_src3,read_trig, 4, mode);
  //join
end

endtask: test_osc_common


task automatic handle_channel(
  int offset,
  int trig_src,
  logic read_trig,
  int ch_num,
  int mode
);
  reg [32-1:0] ind_mask;
  reg [32-1:0] arm_mask;
  reg [32-1:0] clr_mask;
  reg [32-1:0] end_mask;
  reg [32-1:0] axi_end_mask;
  reg [32-1:0] trg_mask;
  reg [32-1:0] trg2_mask;
  reg [32-1:0] trigs_ofs;

  if (ch_num == 1) begin
    ind_mask = {8'h0, 8'h0, 8'h0, 8'h20};
    arm_mask = {8'h0, 8'h0, 8'h0, 8'h1 };
    clr_mask = {8'h0, 8'h0, 8'h0, 8'h1 };
    end_mask = {8'h0, 8'h0, 8'h0, 8'h10};
    axi_end_mask = {8'h0, 8'h0, 8'h0, 8'h10};
    trg_mask = {8'h0, 8'h0, 8'h0, 8'h1 };
    trg2_mask = {8'h0, 8'h0, 8'h0, trig_src[7:0] };
    trigs_ofs = 32'h01C;
  end else if (ch_num == 2) begin
    ind_mask = {8'h0, 8'h0, 8'h20,8'h0 };
    arm_mask = {8'h0, 8'h0, 8'h1, 8'h0 };
    clr_mask = {8'h0, 8'h0, 8'h1, 8'h0 };
    end_mask = {8'h0, 8'h0, 8'h10,8'h0 };
    axi_end_mask = {8'h0, 8'h10,8'h0, 8'h0 };
    trg_mask = {8'h0, 8'h0, 8'h1, 8'h0 };
    trg2_mask = {8'h0, 8'h0, trig_src[7:0], 8'h0};
    trigs_ofs = 32'h11C;
  end else if (ch_num == 3) begin
    ind_mask = {8'h0, 8'h20,8'h0, 8'h0 };
    arm_mask = {8'h0, 8'h1, 8'h0, 8'h0 };
    clr_mask = {8'h0, 8'h1, 8'h0, 8'h0 };
    end_mask = {8'h0, 8'h10,8'h0, 8'h0 };
    axi_end_mask = {8'h0, 8'h0, 8'h0, 8'h10};
    trg_mask = {8'h0, 8'h1, 8'h0, 8'h0 };
    trg2_mask = {8'h0, trig_src[7:0], 8'h0, 8'h0};
    trigs_ofs = 32'h21C;
  end else if (ch_num == 4) begin
    ind_mask = {8'h20,8'h0, 8'h0, 8'h0 };
    arm_mask = {8'h1, 8'h0, 8'h0, 8'h0 };
    clr_mask = {8'h1, 8'h0, 8'h0, 8'h0 };
    end_mask = {8'h10,8'h0, 8'h0, 8'h0 };
    axi_end_mask = {8'h0, 8'h10,8'h0, 8'h0 };
    trg_mask = {8'h1, 8'h0, 8'h0, 8'h0 };
    trg2_mask = {trig_src[7:0], 8'h0, 8'h0, 8'h0};
    trigs_ofs = 32'h31C;
  end

  if (mode == 0)
    reg_wait_bit(32'h40100000,end_mask);
  else if (mode == 1)
    reg_wait_bit(32'h40100088,axi_end_mask);  
  else if (mode == 2)
    reg_wait_bit(32'h40100088,axi_end_mask);  
  else if (mode == 3) begin
    #2000;
    axi_write(offset+'h4 , trg2_mask);  // manual trigger
  end
    $display("Got trig on CH %d at %t", ch_num, $time);
    axi_write(offset+'h4 , trg_mask);  // sw trigger

  if (read_trig)
    trig_samps(offset+trigs_ofs);

  axi_write(offset+'h0 , arm_mask | ind_mask); // ARM trigger
  axi_write(offset+'h94, clr_mask); // clear trigger protect
  axi_write(offset+'h4 , trg2_mask);  // level trigger

endtask: handle_channel

task wait_clks(
  int unsigned del
);
  logic [32-1:0] cnt;
  cnt = 0;
  do begin
    @(posedge top_tb.clk0);
    cnt <= cnt + 1;
  end while (cnt < del);
endtask: wait_clks

task custom_test(
);
  logic [32-1:0] cnt;
  cnt = 0;
  axi_write(32'h40000000+'h34,  1);  // decimation
  do begin
    @(posedge top_tb.clk0);
    top_tb.red_pitaya_top.ps.system_i.CAN0_tx_r <= $random();
    top_tb.red_pitaya_top.ps.system_i.CAN1_tx_r <= $random();

    wait_clks(32);
    cnt <= cnt + 1;
  end while (cnt < 10000);
endtask: custom_test

task automatic reg_wait_bit(
  int unsigned offset,
  logic[32-1:0] bit_mask  
);
  int unsigned dat;
  ##10;
  do begin
    axi_read(offset, dat);
    ##5;
  end while (|(dat & bit_mask) == 1'b0); // BUF 1 is full
  ##10;

endtask: reg_wait_bit

task automatic trig_samps(
  int unsigned offset
);
  int unsigned trig_adr;
  int unsigned dat1;
  int unsigned dat2;
  int unsigned dat3;
  int unsigned dat4;
  int unsigned dat5;
  ##10;
  // configure
    axi_read(offset, trig_adr);
    axi_read(32'h40110000+{(trig_adr+32'd2),2'h0}, dat1);
    axi_read(32'h40110000+{(trig_adr+32'd1),2'h0}, dat1);
    axi_read(32'h40110000+{(trig_adr+32'd0),2'h0}, dat1);
    axi_read(32'h40110000+{(trig_adr-32'd1),2'h0}, dat1);
    axi_read(32'h40110000+{(trig_adr-32'd2),2'h0}, dat2);
    axi_read(32'h40110000+{(trig_adr-32'd3),2'h0}, dat3);
    axi_read(32'h40110000+{(trig_adr-32'd4),2'h0}, dat4);
    axi_read(32'h40110000+{(trig_adr-32'd5),2'h0}, dat5);
    ##5;
endtask: trig_samps


////////////////////////////////////////////////////////////////////////////////
// Testing arbitrary signal generator
////////////////////////////////////////////////////////////////////////////////

task set_asg_init(
  int unsigned offset,
  logic [ 3-1:0] cha_trig_src,
  logic          cha_wrap,
  logic          cha_once,
  logic          cha_rst,
  logic          cha_zero,
  logic          cha_rgate,
  logic [ 3-1:0] chb_trig_src,
  logic          chb_wrap,
  logic          chb_once,
  logic          chb_rst,
  logic          chb_zero,
  logic          chb_rgate,
  logic [16-1:0] cha_amp,
  logic [16-1:0] cha_dc,
  logic [16-1:0] chb_amp,
  logic [16-1:0] chb_dc,
  int            cha_size,
  int            cha_offs,
  int            cha_step,
  int            cha_step_lo,
  int            cha_ncyc,
  int            cha_rnum,
  int            cha_rdly,
  int            cha_last,
  int            cha_first,
  int            chb_size,
  int            chb_offs,
  int            chb_step,
  int            chb_step_lo,
  int            chb_ncyc,
  int            chb_rnum,
  int            chb_rdly,
  int            chb_last,
  int            chb_first,
  int            deb_len,
  int            num_samp,
  logic          set_buf
);
  // CHA DAC settings
  axi_write(offset+32'h4 , {cha_dc, cha_amp}    );
  axi_write(offset+32'h8 , cha_size             );
  axi_write(offset+32'hC , cha_offs             );
  axi_write(offset+32'h10, cha_step             );
  axi_write(offset+32'h14, cha_step_lo          );
  axi_write(offset+32'h18, cha_ncyc             );
  axi_write(offset+32'h1C, cha_rnum             );
  axi_write(offset+32'h20, cha_rdly             );
  axi_write(offset+32'h44, cha_last             );
  axi_write(offset+32'h68, cha_first            );

  // CHB DAC settings
  axi_write(offset+32'h24, {chb_dc, chb_amp}    );
  axi_write(offset+32'h28, chb_size             );
  axi_write(offset+32'h2C, chb_offs             );
  axi_write(offset+32'h30, chb_step             );
  axi_write(offset+32'h34, chb_step_lo          );
  axi_write(offset+32'h38, chb_ncyc             ); 
  axi_write(offset+32'h3C, chb_rnum             );
  axi_write(offset+32'h40, chb_rdly             );
  axi_write(offset+32'h48, chb_last             );
  axi_write(offset+32'h6C, chb_first            );

  axi_write(offset+32'h54, deb_len              );

if (set_buf == 1) begin
  write_buf_both(offset,   num_samp             );
end

  set_asg_conf (offset, cha_trig_src, cha_wrap, cha_once, cha_rst, cha_zero, cha_rgate, 
                        chb_trig_src, chb_wrap, chb_once, chb_rst, chb_zero, chb_rgate);
endtask: set_asg_init

task set_asg_conf(
  int            offset,
  logic [ 3-1:0] cha_trig_src,
  logic          cha_wrap,
  logic          cha_once,
  logic          cha_rst,
  logic          cha_zero,
  logic          cha_rgate,
  logic [ 3-1:0] chb_trig_src,
  logic          chb_wrap,
  logic          chb_once,
  logic          chb_rst,
  logic          chb_zero,
  logic          chb_rgate
);
  logic [16-1: 0] cha_conf = {7'h0, cha_rgate, cha_zero, cha_rst, cha_once, cha_wrap, 1'b0, cha_trig_src};
  logic [16-1: 0] chb_conf = {7'h0, chb_rgate, chb_zero, chb_rst, chb_once, chb_wrap, 1'b0, chb_trig_src};

  axi_write(offset+32'h0 , {chb_conf, cha_conf} );

endtask: set_asg_conf

task write_buf_both(
  int offset,
  int num_samp
);
  write_buf(offset+32'h10000, num_samp, 1       );
  write_buf(offset+32'h20000, num_samp, 2       );
endtask: write_buf_both

task write_buf(
  int offset,
  int num_samp,
  int file
);

  if (file == 2) begin
    for (int k=0; k<num_samp; k++) begin
      axi_write(offset + (k*4), {16'h0, `MEM_DAC_LOC.mem_dac2[k][7:0],`MEM_DAC_LOC.mem_dac2[k][15:8]});  // write table
    end
  end else begin
    for (int k=0; k<num_samp; k++) begin
      axi_write(offset + (k*4), {16'h0, `MEM_DAC_LOC.mem_dac1[k][7:0],`MEM_DAC_LOC.mem_dac1[k][15:8]});  // write table
    end
  end
endtask: write_buf



////////////////////////////////////////////////////////////////////////////////
// Testing SATA
////////////////////////////////////////////////////////////////////////////////

task test_sata(
  int unsigned offset,
  int unsigned sh = 0
);
logic        [ 32-1: 0] rdata;
  ##10;

  // configure
  ##100; axi_write(offset+'h0, 32'h1      );        // Enable transmitter
  ##20;  axi_write(offset+'h0, 32'h3      );        // Enable transmitter & receiver
  ##101; axi_write(offset+'h4, 32'h3      );        // enable TX train
  ##10;  axi_write(offset+'h8, 32'h1      );        // enable RX train
  ##1500; axi_read (offset+'hC, rdata      );        // Return read value
  ##20;  axi_write(offset+'h8, 32'h0      );        // disable RX train
  ##20;  axi_write(offset+'h4, {16'hF419, 16'h2});  // Custom value
  ##20;  axi_write(offset+'h4, {16'hF419, 16'h5});  // Random valu
  ##20;  axi_write(offset+'h10, 32'h1      );       // Clear error counter
  ##20;  axi_write(offset+'h10, 32'h0      );       // Enable error counter
  ##404; axi_write(offset+'h4, {16'h0, 16'h4});     // Sent back read value

  ##1000;

endtask: test_sata


////////////////////////////////////////////////////////////////////////////////
// AXI4 read/write tasks
////////////////////////////////////////////////////////////////////////////////

task axi_read (
  input  logic [32-1:0] adr,
  output logic [32-1:0] dat
);
  top_tb.red_pitaya_top.ps.system_i.i_m_axi_gp0.rd_single(
    .adr_i (adr),
    .dat_o (dat),
    .id_i  ('h0),
    .size_i('h1),
    .lock_i('h0),
    .prot_i('h0)
  );

endtask: axi_read


task axi_write (
  input  logic [32-1:0] adr,
  input  logic [32-1:0] dat
);
  top_tb.red_pitaya_top.ps.system_i.i_m_axi_gp0.wr_single(
    .adr_i (adr),
    .dat_i (dat),
    .id_i  ('h0),
    .size_i('h1),
    .lock_i('h0),
    .prot_i('h0)
  );
endtask: axi_write







endmodule

