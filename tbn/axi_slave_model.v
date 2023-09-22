/*
* Copyright (c) 2013 Instrumentation Technologies
* All Rights Reserved.
*
* $Id: $
*/

///////////////////////////////////////////////////////////////////////////////////
//                                                                               //
//                                  DESCRIPTION                                  //
//                                                                               //
///////////////////////////////////////////////////////////////////////////////////
//                                                                               //
//  AHB axi slave mode                                                          //
//                                                                               //
// supported protocols:                                                          //
// - fixed burst                                                                 //
// - incrementing burst                                                          //
// - noncachable and nonbufferable transactions                                  //
// - normal nonsecure data access                                                //
//                                                                               //
// not supported protocols:                                                      //
// - lock                                                                        //
// - protection                                                                  //
// - cache                                                                       //
// - wrap burst                                                                  //
// - IDs                                                                         //
// -                                                                             //
//                                                                               //
///////////////////////////////////////////////////////////////////////////////////
`define MEM_DAC_LOC top_tb.tb_dac_drv
//`include "tb_defines.sv"
 
module axi_slave_model #(
parameter            AXI_DW         =  64           , // data width (8,16,...,1024)
parameter            AXI_AW         =  32           , // address width ()
parameter            AXI_ID         =   0           , // master ID
parameter            AXI_IW         =   4           , // master ID width
parameter            AXI_LW         =   4           , // master ID width   
parameter            AXI_SW         =  AXI_DW >> 3    // strobe width - 1 bit for every data byte
)(
    // global signals
    input                       axi_clk_i     , // global clock
    input                       axi_rstn_i    , // global reset
                
    // axi write address channel
    input       [ AXI_IW-1: 0]  axi_awid_i     , // write address ID
    input       [ AXI_AW-1: 0]  axi_awaddr_i   , // write address
    input       [      4-1: 0]  axi_awlen_i    , // write burst length
    input       [      3-1: 0]  axi_awsize_i   , // write burst size
    input       [      2-1: 0]  axi_awburst_i  , // write burst type
    input       [      2-1: 0]  axi_awlock_i   , // write lock type
    input       [      4-1: 0]  axi_awcache_i  , // write cache type
    input       [      3-1: 0]  axi_awprot_i   , // write protection type
    input                       axi_awvalid_i  , // write address valid
    output reg                  axi_awready_o  , // write ready

    // axi write data channel
    input       [ AXI_IW-1: 0]  axi_wid_i      , // write data ID
    input       [ AXI_DW-1: 0]  axi_wdata_i    , // write data
    input       [ AXI_SW-1: 0]  axi_wstrb_i    , // write strobes
    input                       axi_wlast_i    , // write last
    input                       axi_wvalid_i   , // write valid
    output reg                  axi_wready_o   , // write ready

    // axi write response channel
    output reg  [ AXI_IW-1: 0]  axi_bid_o      , // write response ID
    output reg  [      2-1: 0]  axi_bresp_o    , // write response
    output reg                  axi_bvalid_o   , // write response valid
    input                       axi_bready_i   , // write response ready

    // axi read address channel
    input       [ AXI_IW-1: 0]  axi_arid_i     , // read address ID
    input       [ AXI_AW-1: 0]  axi_araddr_i   , // read address
    input       [ AXI_LW-1: 0]  axi_arlen_i    , // read burst length
    input       [      3-1: 0]  axi_arsize_i   , // read burst size
    input       [      2-1: 0]  axi_arburst_i  , // read burst type
    input       [      2-1: 0]  axi_arlock_i   , // read lock type
    input       [      4-1: 0]  axi_arcache_i  , // read cache type
    input       [      3-1: 0]  axi_arprot_i   , // read protection type
    input                       axi_arvalid_i  , // read address valid
    output reg                  axi_arready_o  , // read address ready
    
    // axi read data channel
    output reg  [ AXI_IW-1: 0]  axi_rid_o      , // read response ID
    output reg  [ AXI_DW-1: 0]  axi_rdata_o    , // read data
    output reg  [      2-1: 0]  axi_rresp_o    , // read response
    output                      axi_rlast_o    , // read last
    output reg                  axi_rvalid_o   , // read response valid
    input                       axi_rready_i     // read response ready


);

//------------------------------------------------
// parameters/constant
//------------------------------------------------ 

parameter   WR_ADR_RDY_RND_W    = 2;
parameter   WR_DAT_RDY_RND_W    = 2;
parameter   WR_RSP_VLD_RND_W    = 2;
parameter   RD_ADR_RDY_RND_W    = 2;
parameter   RD_DAT_VLD_RND_W    = 2;


parameter   RAM_D               = 15;


parameter   OKAY                = 2'b00; 
parameter   EXOKAY              = 2'b01;
parameter   SLVERR              = 2'b10;
parameter   DECERR              = 2'b11;

integer     SEED              = 16;
integer     i;

//------------------------------------------------
// ram
//------------------------------------------------ 

reg [ AXI_DW-1: 0] ram [(1 << RAM_D) - 1 : 0];
wire [16-1:0] samples [3*4 - 1 :0];
initial
begin
    for (i = 0; i < 1 << RAM_D ; i = i + 1)
    begin
        ram[i] <= {64{1'b0}};
    end
end

reg                                 wr_data;
reg                                 rd_data;        
//------------------------------------------------
//  axi write address channel signals
//------------------------------------------------ 
reg     [               3-1: 0]     wr_adr_rdy_sel = 3'b001;
reg     [WR_ADR_RDY_RND_W-1: 0]     wr_adr_rdy_rnd;
wire                                wr_adr_en;
reg     [           RAM_D-1: 0]     wr_adr;    
//------------------------------------------------
//  axi write data channel signals
//------------------------------------------------ 

reg     [               3-1: 0]     wr_dat_rdy_sel = 3'b001;
reg     [WR_DAT_RDY_RND_W-1: 0]     wr_dat_rdy_rnd;
wire                                wr_dat_en;
reg     [          AXI_DW-1: 0]     wr_dat_ram;
wire    [          AXI_DW-1: 0]     wr_dat_stb;
//------------------------------------------------
//  axi write response channel signals
//------------------------------------------------ 

reg     [               2-1: 0]     wr_rsp_vld_sel = 2'b00;
reg     [WR_RSP_VLD_RND_W-1: 0]     wr_rsp_vld_rnd;
wire                                wr_rsp_en;
wire    [               2-1: 0]     wr_rsp_typ     = 2'b00;
reg                                 wr_rsp_start;
reg                                 wr_rsp_start_rnd;
reg     [               4-1: 0]     wr_len; 
reg     [               4-1: 0]     wr_cnt;
reg     [               4-1: 0]     wr_cnt_q;
reg     [               8-1: 0]     dbg_cnt = 0;
//------------------------------------------------
//  axi read address channel signals
//------------------------------------------------ 

reg     [               2-1: 0]     rd_adr_rdy_sel = 2'b01;
reg     [RD_ADR_RDY_RND_W-1: 0]     rd_adr_rdy_rnd;
wire                                rd_adr_en;
reg     [           RAM_D-1: 0]     rd_adr;     
//------------------------------------------------
//  axi read data channel signals
//------------------------------------------------ 

reg     [               2-1: 0]     rd_dat_vld_sel = 2'b00;
reg     [RD_DAT_VLD_RND_W-1: 0]     rd_dat_vld_rnd;
wire                                rd_dat_en;
wire    [          AXI_SW-1: 0]     rd_dat_stb;
reg                                 rd_dat_start; 
reg                                 rd_dat_start_rnd;
wire    [               2-1: 0]     rd_rsp_typ     = 2'b00;
reg     [          AXI_LW-1: 0]     rd_cnt;
reg     [          AXI_LW-1: 0]     rd_len;  


always @(posedge axi_clk_i)
begin
    if (!axi_rstn_i) 
    begin
        wr_data <= 1'b0;
    end
    else if (wr_adr_en && !wr_data)
    begin
        wr_data <= 1'b1;
    end
    else if (wr_dat_en && axi_wlast_i && wr_data)
    begin
        wr_data <= 1'b0;
    end
end

always @(posedge axi_clk_i)
begin
    if (!axi_rstn_i) 
    begin
        rd_data <= 1'b0;
    end
    else if (rd_adr_en && !rd_dat_en)
    begin
        rd_data <= 1'b1;
    end
    else if (rd_dat_en && axi_rlast_o && rd_data)
    begin
        rd_data <= 1'b0;
    end
end

//------------------------------------------------
//  axi write address channel 
//------------------------------------------------ 

assign wr_adr_en = axi_awvalid_i && axi_awready_o;

always @(posedge axi_clk_i)
begin
    wr_adr_rdy_rnd <= $random(SEED);
end

always @(*)
begin
    case (wr_adr_rdy_sel)
        3'b000  : axi_awready_o = (wr_data)? 1'b0 : 1'b0;
        3'b001  : axi_awready_o = (wr_data)? 1'b0 : 1'b1;
        3'b010  : axi_awready_o = (wr_data)? 1'b0 : (&wr_adr_rdy_rnd); 
        3'b011  : axi_awready_o = (wr_data)? 1'b0 : axi_awvalid_i && (&wr_adr_rdy_rnd);
        3'b100  : axi_awready_o = (wr_data)? 1'b0 : axi_wvalid_i  && (&wr_adr_rdy_rnd);
        3'b101  : axi_awready_o = (wr_data)? 1'b0 : axi_awvalid_i && axi_wvalid_i && (&wr_adr_rdy_rnd);
        default : axi_awready_o = 1'b0;
    endcase
end

always @(posedge axi_clk_i)
begin
    if (wr_adr_en)
    begin
        wr_len      <= axi_awlen_i;
    end
end


always @(posedge axi_clk_i)
begin
    if (wr_adr_en) 
    begin
        wr_adr <= axi_awaddr_i[RAM_D - 1 + 3 : 3];
    end
    else if (wr_dat_en)
    begin
        wr_adr <= wr_adr + 1;
    end
end

//------------------------------------------------
//  axi write data channel 
//------------------------------------------------ 

assign wr_dat_en = axi_wvalid_i && axi_wready_o;

always @(posedge axi_clk_i)
begin
    wr_dat_rdy_rnd <= $random(SEED);
end

always @(*)
begin
    case (wr_dat_rdy_sel)
        3'b000  : axi_wready_o = (!wr_data)? 1'b0 : 1'b0;
        3'b001  : axi_wready_o = (!wr_data)? 1'b0 : 1'b1;
        3'b010  : axi_wready_o = (!wr_data)? 1'b0 : (&wr_dat_rdy_rnd); 
        3'b011  : axi_wready_o = (!wr_data)? 1'b0 : (&wr_dat_rdy_rnd) && axi_awvalid_i;
        3'b100  : axi_wready_o = (!wr_data)? 1'b0 : (&wr_dat_rdy_rnd) && axi_wvalid_i;
        3'b101  : axi_wready_o = (!wr_data)? 1'b0 : (&wr_dat_rdy_rnd) && axi_awvalid_i && axi_wvalid_i;
        default : axi_wready_o = 1'b0;
    endcase
end



always @(*)
begin
    wr_dat_ram = ram[wr_adr];
end

assign wr_dat_stb  = {{8{axi_wstrb_i[7]}},{8{axi_wstrb_i[6]}},{8{axi_wstrb_i[5]}},{8{axi_wstrb_i[4]}},{8{axi_wstrb_i[3]}},{8{axi_wstrb_i[2]}},{8{axi_wstrb_i[1]}},{8{axi_wstrb_i[0]}}};


always @(posedge axi_clk_i)
begin
    if (wr_dat_en) 
    begin
        ram[wr_adr] <= (&axi_wstrb_i)? axi_wdata_i : ((axi_wdata_i & wr_dat_stb) | wr_dat_ram);
    end
end

assign samples[0] = ram [0][15 :0]; 
assign samples[1] = ram [0][31:16]; 
assign samples[2] = ram [0][47:32]; 
assign samples[3] = ram [0][63:48]; 

assign samples[4] = ram [1][15 :0]; 
assign samples[5] = ram [1][31:16]; 
assign samples[6] = ram [1][47:32]; 
assign samples[7] = ram [1][63:48]; 

assign samples[8] = ram [2][15 :0]; 
assign samples[9] = ram [2][31:16]; 
assign samples[10] = ram [2][47:32]; 
assign samples[11] = ram [2][63:48]; 
always @(posedge axi_clk_i)
begin
    if (!axi_rstn_i)
    begin
        wr_cnt <= 4'd0;
    end
    else if (wr_dat_en)
    begin
        if (axi_wlast_i)
        begin
            wr_cnt <= 4'd0;
        end
        else 
        begin
            wr_cnt <= wr_cnt + 1;
        end
    end
end



always @(posedge axi_clk_i)
begin
    wr_cnt_q <= wr_cnt;
end

always @(posedge axi_clk_i)
begin
    if (wr_cnt == 0)
    begin
        dbg_cnt <= 0;
    end
    else if (wr_cnt == wr_cnt_q)
    begin
        dbg_cnt <= dbg_cnt + 1;
    end
end

always @(axi_clk_i)
begin
    if (&dbg_cnt) $display ("Write length error @ time = %d",$time);
end

//------------------------------------------------
//  axi write response channel signals
//------------------------------------------------ 

assign wr_rsp_en = axi_bvalid_o && axi_bready_i;

always @(posedge axi_clk_i)
begin
    wr_rsp_vld_rnd <= $random(SEED);
end

always @(posedge axi_clk_i)
begin
    if (wr_adr_en)
    begin
        axi_bid_o <= axi_awid_i;
    end
end

always @(*)
begin
    case (wr_rsp_typ)
        2'b00: axi_bresp_o = OKAY; 
        2'b01: axi_bresp_o = EXOKAY;
        2'b10: axi_bresp_o = SLVERR;
        2'b11: axi_bresp_o = DECERR;
    endcase
end

always @(posedge axi_clk_i)
begin
    if (!axi_rstn_i)
    begin
        wr_rsp_start <= 1'b0;
    end
    else if (wr_dat_en && axi_wlast_i) 
    begin
        wr_rsp_start <= 1'b1;
    end
    else if (wr_rsp_en)
    begin
        wr_rsp_start <= 1'b0;
    end
end

always @(posedge axi_clk_i)
begin
    if (!axi_rstn_i)
    begin
        wr_rsp_start_rnd <= 1'b0;
    end
    else if (wr_rsp_en)
    begin
        wr_rsp_start_rnd <= 1'b0;
    end
    else if (wr_rsp_start && (&wr_rsp_vld_rnd)) 
    begin
        wr_rsp_start_rnd <= 1'b1;
    end
end

always @(*)
begin
    case (wr_rsp_vld_sel)
        2'b00   : axi_bvalid_o = wr_rsp_start; 
        2'b01   : axi_bvalid_o = wr_rsp_start_rnd;
        default : axi_bvalid_o = 1'b0;
    endcase
end

//------------------------------------------------
//  axi read address channel signals
//------------------------------------------------ 

assign rd_adr_en = axi_arvalid_i && axi_arready_o;

always @(posedge axi_clk_i)
begin
    rd_adr_rdy_rnd <= $random(SEED);
end

always @(*)
begin
    case (rd_adr_rdy_sel)
        2'b00   : axi_arready_o = (rd_data)? 1'b0 : 1'b0;
        2'b01   : axi_arready_o = (rd_data)? 1'b0 : 1'b1;
        2'b10   : axi_arready_o = (rd_data)? 1'b0 : (&rd_adr_rdy_rnd);
        2'b11   : axi_arready_o = (rd_data)? 1'b0 : (&rd_adr_rdy_rnd) && axi_arvalid_i;
        default : axi_arready_o = (rd_data)? 1'b0 : 1'b0;
    endcase
end

//------------------------------------------------
//  axi read data channel signals
//------------------------------------------------ 

assign rd_dat_en = axi_rvalid_o && axi_rready_i;

always @(posedge axi_clk_i)
begin
    if (rd_adr_en) axi_rid_o <= axi_arid_i; 
end

always @(posedge axi_clk_i)
begin
    if (rd_adr_en)
    begin
        rd_len      <= axi_arlen_i;
    end
end


always @(posedge axi_clk_i)
begin
    if (rd_adr_en) 
    begin
        rd_adr <= axi_araddr_i[RAM_D - 1 + 3 : 3];
    end
    else if (rd_dat_en)
    begin
        rd_adr <= rd_adr + 1;
    end
end

/*
always @(*)
begin

    axi_rdata_o = ram[rd_adr];
end
*/

reg [16-1:0] rd_pnt;
always @(posedge axi_clk_i)
begin
    if (rd_adr_en) 
    begin
        rd_pnt <= axi_araddr_i[17 - 1 : 1];
    end
    else if (rd_dat_en)
    begin
        rd_pnt <= rd_pnt + 4;
    end
end

wire test_gpio = (AXI_ID == 1);
wire test_dac1 = (AXI_ID == 2);
wire test_dac2 = (AXI_ID == 3);

// adapted to 64 bits, streaming from mem file in testcases
wire [16-1:0] dats11_raw = `MEM_DAC_LOC.mem_dac1[rd_pnt+0];
wire [16-1:0] dats12_raw = `MEM_DAC_LOC.mem_dac1[rd_pnt+1];
wire [16-1:0] dats13_raw = `MEM_DAC_LOC.mem_dac1[rd_pnt+2];
wire [16-1:0] dats14_raw = `MEM_DAC_LOC.mem_dac1[rd_pnt+3];

wire [16-1:0] dats21_raw = `MEM_DAC_LOC.mem_dac2[rd_pnt+0];
wire [16-1:0] dats22_raw = `MEM_DAC_LOC.mem_dac2[rd_pnt+1];
wire [16-1:0] dats23_raw = `MEM_DAC_LOC.mem_dac2[rd_pnt+2];
wire [16-1:0] dats24_raw = `MEM_DAC_LOC.mem_dac2[rd_pnt+3];

wire [16-1:0] dats31_raw = `MEM_DAC_LOC.mem_gpio[rd_pnt+0];
wire [16-1:0] dats32_raw = `MEM_DAC_LOC.mem_gpio[rd_pnt+1];
wire [16-1:0] dats33_raw = `MEM_DAC_LOC.mem_gpio[rd_pnt+2];
wire [16-1:0] dats34_raw = `MEM_DAC_LOC.mem_gpio[rd_pnt+3];

wire [16-1:0] dats11_flip = {dats11_raw[7:0], dats11_raw[15:8]};
wire [16-1:0] dats12_flip = {dats12_raw[7:0], dats12_raw[15:8]};
wire [16-1:0] dats13_flip = {dats13_raw[7:0], dats13_raw[15:8]};
wire [16-1:0] dats14_flip = {dats14_raw[7:0], dats14_raw[15:8]};

wire [16-1:0] dats21_flip = {dats21_raw[7:0], dats21_raw[15:8]};
wire [16-1:0] dats22_flip = {dats22_raw[7:0], dats22_raw[15:8]};
wire [16-1:0] dats23_flip = {dats23_raw[7:0], dats23_raw[15:8]};
wire [16-1:0] dats24_flip = {dats24_raw[7:0], dats24_raw[15:8]};

wire [16-1:0] dats31_flip = {dats31_raw[7:0], dats31_raw[15:8]};
wire [16-1:0] dats32_flip = {dats32_raw[7:0], dats32_raw[15:8]};
wire [16-1:0] dats33_flip = {dats33_raw[7:0], dats33_raw[15:8]};
wire [16-1:0] dats34_flip = {dats34_raw[7:0], dats34_raw[15:8]};

wire [4*16-1:0] ch1_4samp = {dats14_flip, dats13_flip, dats12_flip, dats11_flip};
wire [4*16-1:0] ch2_4samp = {dats24_flip, dats23_flip, dats22_flip, dats21_flip};
wire [4*16-1:0] ch3_4samp = {dats34_flip, dats33_flip, dats32_flip, dats31_flip};

//wire [4*16-1:0] ch1_4samp = {dats14_raw,  dats13_raw,  dats12_raw,  dats11_raw };
//wire [4*16-1:0] ch2_4samp = {dats24_raw,  dats23_raw,  dats22_raw,  dats21_raw };
//wire [4*16-1:0] ch3_4samp = {dats34_raw,  dats33_raw,  dats32_raw,  dats31_raw };

wire [ 2-1:0] strm_dac_en = top_tb.strm_dac_en;

always @(*)
begin
  if (test_dac1)
    axi_rdata_o = ch1_4samp;
  else if (test_dac2)
    axi_rdata_o = ch2_4samp;
  else if (test_gpio)
    axi_rdata_o = ch3_4samp;
end


always @(*)
begin
    case (rd_rsp_typ)
        2'b00: axi_rresp_o = OKAY; 
        2'b01: axi_rresp_o = EXOKAY;
        2'b10: axi_rresp_o = SLVERR;
        2'b11: axi_rresp_o = DECERR;
    endcase
end


always @(posedge axi_clk_i)
begin
    if (!axi_rstn_i)
    begin
        rd_cnt <= 'd0;
    end
    else if (rd_dat_en)
    begin
        if (axi_rlast_o) rd_cnt <= 'd0;
        else              rd_cnt <= rd_cnt + 1;
    end
end

assign axi_rlast_o = axi_rvalid_o && (rd_cnt == rd_len);

always @(posedge axi_clk_i)
begin
    if (!axi_rstn_i) 
    begin
        rd_dat_start <= 1'b0;
    end
    else if (rd_adr_en)
    begin
        rd_dat_start <= 1'b1;
    end
    else if (rd_dat_en && axi_rlast_o)
    begin
        rd_dat_start <= 1'b0;
    end
end

always @(posedge axi_clk_i)
begin
    rd_dat_vld_rnd <= $random(SEED);
end

always @(posedge axi_clk_i)
begin
    if (!axi_rstn_i) 
    begin
        rd_dat_start_rnd <= 1'b0;
    end
    else if (rd_dat_en)
    begin
        rd_dat_start_rnd <= 1'b0;
    end
    else if (rd_dat_start && (&rd_dat_vld_rnd))
    begin
        rd_dat_start_rnd <= 1'b1;
    end
end

always @(*)
begin
    case (rd_dat_vld_sel)
        2'b00   : axi_rvalid_o = rd_dat_start; 
        2'b01   : axi_rvalid_o = rd_dat_start_rnd;
        default : axi_rvalid_o = 1'b0;
    endcase
end


always @(posedge axi_clk_i)
begin
    if (wr_data && axi_wvalid_i && (wr_cnt > wr_len))
    begin
        $display ("ERROR : TO MANY WRITE DATA @ TIME = %t",$time);
    end
    if (rd_data && axi_rvalid_o && (rd_cnt > rd_len))
    begin
        $display ("ERROR : TO MANY READ DATA @ TIME = %t",$time);
    end
    if (wr_data && axi_wlast_i && (wr_cnt != wr_len))
    begin
        $display ("ERROR : WRITE LAST BURST SIGNAL NOT @ TIME = %t",$time);
    end
    if (rd_data && axi_rlast_o && (rd_cnt != rd_len))
    begin
        $display ("ERROR : READ LAST BURST SIGNAL NOT @ TIME = %t",$time);
    end
    if (wr_data && axi_wvalid_i && (wr_cnt == wr_len) && !axi_wlast_i)
    begin
        $display ("ERROR : MISSING WRITE LAST SIGNAL @ TIME = %t",$time);
    end
    if (rd_data && axi_rvalid_o && (rd_cnt == rd_len) && !axi_rlast_o)
    begin
        $display ("ERROR : MISSING READ LAST SIGNAL @ TIME = %t",$time);
    end
end

endmodule 
