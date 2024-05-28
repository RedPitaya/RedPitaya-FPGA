`timescale 1ns / 1ps

`define TRIG_ACT_LVL  0
`define MASTER        1
`define LOCALM        1
`define FILERD        1
`define SINE          0
`define DAC_SAMPS     100000

`define AXI_MON       1
`define ADC_MON       1
`define DAC_MON       1
`define GPIO_MON      1

`define HK_REG_OFS         0
`define SCOPE1_REG_OFS     1
`define SCOPE2_REG_OFS     2
`define ASG_REG_OFS        2
`define PID_REG_OFS        3
`define AMS_REG_OFS        4
`define DAISY_REG_OFS      5

`define STRM_SCOPE_REG_OFS 0
`define STRM_ASG_REG_OFS   1
`define STRM_GPIO_REG_OFS  2
`define STRM_HK_REG_OFS    3

`define BASE_OFS           32'h40000000
`define OFS_SHIFT          20

`define DAC_SRC_CH0  "dac_src_ch0.bin"
`define DAC_SRC_CH1  "dac_src_ch1.bin"
`define GPIO_SRC_OUT "gpio_src_out.bin"
`define ADC_SRC_CH0  "adc_src_ch0.bin"
`define ADC_SRC_CH1  "adc_src_ch1.bin"
`define ADC_SRC_CH2  "adc_src_ch2.bin"
`define ADC_SRC_CH3  "adc_src_ch3.bin"

`define CH0      0
`define CH1      1
`define CH2      2
`define CH3      3
`define GPIO     4

`define GPIO_IN  1
`define GPIO_OUT 0

`define IP_PS_LOC     top_tb.red_pitaya_top.system_wrapper_i.system_i.system_model.inst

`define AXI_REG_LOC   `IP_PS_LOC.i_m_axi_gp0
`define AXI_OSC01_LOC `IP_PS_LOC.i_s_axi_hp0
`define AXI_OSC23_LOC `IP_PS_LOC.i_s_axi_hp0
`define AXI_DAC0_LOC  `IP_PS_LOC.i_s_axi_hp2
`define AXI_DAC1_LOC  `IP_PS_LOC.i_s_axi_hp3
`define AXI_GPIO_LOC  `IP_PS_LOC.i_s_axi_hp1

// `define AXI_REG_LOC   top_tb.red_pitaya_top.system_wrapper_i.REG_AXI.inst
// `define AXI_OSC01_LOC top_tb.red_pitaya_top.system_wrapper_i.OSC01_AXI.inst
// `define AXI_OSC23_LOC top_tb.red_pitaya_top.system_wrapper_i.OSC23_AXI.inst
// `define AXI_DAC0_LOC  top_tb.red_pitaya_top.system_wrapper_i.DAC0_AXI.inst
// `define AXI_DAC1_LOC  top_tb.red_pitaya_top.system_wrapper_i.DAC1_AXI.inst
// `define AXI_GPIO_LOC  top_tb.red_pitaya_top.system_wrapper_i.GPIO_AXI.inst

`define IP_TOP_LOC    top_tb.red_pitaya_top.system_wrapper_i.system_i.rp_oscilloscope.inst
`define IP_SCOPE_LOC  top_tb.red_pitaya_top.system_wrapper_i.system_i.rp_oscilloscope.inst
`define IP_DAC_LOC    top_tb.red_pitaya_top.system_wrapper_i.system_i.rp_dac.inst
`define IP_GPIO_LOC   top_tb.red_pitaya_top.system_wrapper_i.system_i.rp_gpio.inst
`define MEM_DAC_LOC   top_tb.tb_dac_drv

`define FCLK0_PER     8000
`define FCLK1_PER     4000
`define FCLK2_PER    20000
`define FCLK3_PER     5000
//`define FCLK2_PER     5000
//`define FCLK3_PER     6000

`define FCLK0_JIT        0
`define FCLK1_JIT        0
`define FCLK2_JIT        0
`define FCLK3_JIT        0

`define GPIO_INT_CHECK   1
`define ADC_INT_CHECK    0

`define SW_TRIG_ADC   1
`define AP_TRIG_ADC   2
`define AN_TRIG_ADC   3
`define BP_TRIG_ADC   4
`define BN_TRIG_ADC   5
`define EXTP_TRIG_ADC 6
`define EXTN_TRIG_ADC 7
`define ASGP_TRIG_ADC 8
`define ASGN_TRIG_ADC 9
`define CP_TRIG_ADC   10
`define CN_TRIG_ADC   11
`define DP_TRIG_ADC   12
`define DN_TRIG_ADC   13

`define SW_TRIG_DAC   3'h1
`define EXTP_TRIG_DAC 3'h2
`define EXTN_TRIG_DAC 3'h3
`define CTRL_DAC_WRAP 4
`define CTRL_DAC_ONCE 5
`define CTRL_DAC_RST  6
`define CTRL_DAC_ZERO 7
`define CTRL_DAC_GATE 8




`define MODE_NORMAL   0
`define MODE_AXI0     1
`define MODE_AXI1     2
`define MODE_FAST     3

// IN events
`define GEN1_EVENT    0
`define GEN2_EVENT    1
`define OSC1_EVENT    2
`define OSC2_EVENT    3
`define LA_EVENT      4

// OUT events
`define TRIG_EVENT    3
`define STOP_EVENT    2
`define START_EVENT   1
`define RESET_EVENT   0

// DMA status reg
`define READ_STATE_BUF1  0
`define END_STATE_BUF1   1
`define READ_STATE_BUF2  2
`define END_STATE_BUF2   3
`define RESET_STATE      4
`define SEND_DMA_STATE1  5
`define SEND_DMA_STATE2  6

`define STS_BUF1_FULL    0
`define STS_BUF2_FULL    1
`define STS_BUF1_OVF     2
`define STS_BUF2_OVF     3
`define STS_CURR_BUF     4


// DMA control reg
`define CTRL_STRT            0
`define CTRL_RESET_DAC       1
`define CTRL_RESET_ADC       4
`define CTRL_MODE_NORM_DAC   4
`define CTRL_MODE_STREAM_DAC 5
`define CTRL_MODE_NORM_ADC   8
`define CTRL_MODE_STREAM_ADC 9
`define CTRL_BUF1_RDY        6
`define CTRL_BUF2_RDY        7
`define CTRL_BUF1_ACK        2
`define CTRL_BUF2_ACK        3
`define CTRL_INTR_ACK        1

`define AFORMAT "Channel: %d, Address: %d, Data: %d \n"
`define AVALS   i, adc_adr[i], $signed(adc_datr[i])

`define XFORMAT "Channel: %d, Address: %d, Data: %d \n"
`define XVALS0  i, axi_wr_adr_r[i]+0, $signed(axi_wdat[i][16*1-1:16*0])
`define XVALS1  i, axi_wr_adr_r[i]+2, $signed(axi_wdat[i][16*2-1:16*1])
`define XVALS2  i, axi_wr_adr_r[i]+4, $signed(axi_wdat[i][16*3-1:16*2])
`define XVALS3  i, axi_wr_adr_r[i]+6, $signed(axi_wdat[i][16*4-1:16*3])

`define GIFORMAT "Address: %d, Data: %b, RLE number: %d \n"
`define GIVALS0  axi_wr_adr_r[i]+0, axi_wdat[i][16*1-9:16*0], axi_wdat[i][16*1-1:16*1-8]
`define GIVALS1  axi_wr_adr_r[i]+2, axi_wdat[i][16*2-9:16*1], axi_wdat[i][16*2-1:16*2-8]
`define GIVALS2  axi_wr_adr_r[i]+4, axi_wdat[i][16*3-9:16*2], axi_wdat[i][16*3-1:16*3-8]
`define GIVALS3  axi_wr_adr_r[i]+6, axi_wdat[i][16*4-9:16*3], axi_wdat[i][16*4-1:16*4-8]

`define LFORMAT "Lost samples on channel %d at time %t, buffer 1: %d, buffer 2: %d"
`define LVALS    ch_num, $time, buf1_lost, buf2_lost

`define GOFORMAT "GPIO_P: %b, GPIO_N %b \n"
`define GOVALS   gpio_p, gpio_n

`define DFORMAT "CHA: %d, CHB %d \n"
`define DVALS   $signed(dac_cha), $signed(dac_cha)

`define TFORMATADC "ADC trigger received at %d, trigger source %d, trigger level %d, sample number %d \n"
`define TVALSADC adc_triga, trig_src_r, $signed(trig_lvl), write_cntADC[i]
`define TFORMATAXI "AXI trigger received at %d, trigger source %d, trigger level %d, sample number %d \n"
`define TVALSAXI axi_triga[20-1:0], trig_src_r, $signed(trig_lvl), write_cntAXI[i]
