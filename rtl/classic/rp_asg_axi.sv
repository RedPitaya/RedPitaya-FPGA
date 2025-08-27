/*
ASG with an interface to RAM.
Only supports reading data from RAM linearly in chunks.
Enables slowing down data generation by holding each sample for N cycles.
No interpolation is performed between samples. 
Integrates also into burst mode of the generator.
 */

module rp_asg_axi #(
  parameter RSZ=16
)(
   // DAC
   output reg  [ 14-1: 0] dac_o           ,  //!< dac data output
   input                  dac_clk_i       ,  //!< dac clock
   input                  dac_rstn_i      ,  //!< dac reset - active low
   // trigger
   input                  trig_i          ,  //!< software trigger
   // buffer ctrl
   axi_sys_if.s           axi_sys         ,

   // configuration
   input                  set_rst_i       ,  //!< set FSM to reset
   input                  set_axi_en_i    ,  //!< enable AXI buffer read
   input      [  32-1: 0] set_axi_start_i ,  //!< AXI start address
   input      [  32-1: 0] set_axi_stop_i  ,  //!< AXI stop address
   input      [  32-1: 0] set_axi_dec_i   ,  //!< AXI decimation
   input      [  16-1: 0] set_cyc_cnt_i   ,  //!< limit number of writes
   input      [  16-1: 0] cyc_cnt_i       ,  //!< cycle count for dac_do reset
   output     [  16-1: 0] axi_state_o     ,  //!< AXI state
   output                 axi_last_o      ,  //!< AXI final sample

   output reg [  32-1: 0] err_cnt_o       ,  //!< number of missed samples
   output reg [  32-1: 0] transf_cnt_o       //!< number of successful AXI transfers

);

//---------------------------------------------------------------------------------
//

localparam DW = 64;
localparam AW = 32;
localparam LW =  4;

localparam SL =  5;


logic [  AW-1: 0] dac_pnt;
logic [  AW-1: 0] dac_npnt;
logic [  AW-1: 0] buf_final;

logic             buf_ovr_limit;
logic             buf_ovr_limit_r;

logic [  SL-1: 0] axi_en_sr    ;
logic             dac_do       ;
logic [  SL-1: 0] dac_do_sr    ;

logic [   AW-1:0] dac_rd_size;
logic [    3-1:0] dac_rd_rsize;
logic             dac_rd_clr;

logic [  128-1:0] req_fifo_in; 
logic             req_fifo_wr;
logic             req_fifo_full;
logic [   SL-1:0] rf_full_sr;

logic [  128-1:0] req_fifo_out;
logic [  128-1:0] req_fifo_out_r;

logic             req_fifo_rd;
logic [   SL-1:0] rf_rd_sr;

logic             req_fifo_empty;
logic             req_fifo_empty_r;

logic             new_req;
logic [   SL-1:0] new_req_sr;

logic             new_req_r;

logic [   DW-1:0] dat_fifo_idata; 
logic [   AW-1:0] dat_fifo_iaddr; 
logic [AW+DW-1:0] dat_fifo_in; 
logic             dat_fifo_wr;
logic             dat_fifo_wr_r;
logic             dat_fifo_full;
logic [AW+DW-1:0] dat_fifo_out;
logic [   AW-1:0] dat_fifo_addr;
logic             dat_fifo_rden;
logic             df_wr_rdy;

logic             dat_fifo_rd;
logic             dat_fifo_empty;
logic             df_empty_r;
logic             df_nempty_init;
logic [   SL-1:0] df_rden_sr;
logic             df_first_valid;
logic [   SL-1:0] df_fv_sr;
logic             dac_rden;

logic             last_val;
logic             last_val_r;

logic [    8-1:0] dat_fifo_lvl; 


logic [   AW-1:0] ctrl_addr; 
logic [   AW-1:0] ctrl_size; 
logic [    3-1:0] ctrl_rsize; 
logic             ctrl_busy; 
logic             stat_busy; 
logic             stat_busy_r; 

logic [   16-1:0] dec_cnt; 
logic             dec_val; 
logic [   SL-1:0] dec_val_sr; 
logic [    2-1:0] fifo_rd_rp; 
logic [    2-1:0] fifo_rd_rp_r1; 
logic [    2-1:0] fifo_rd_rp_r2; 

logic [   16-1:0] r_cycles; 
logic             trig_r; 
logic [    5-1:0] rst_busy = 'h0; 
logic             rst_r;
logic             rst_on_pulse;
logic             fifo_rst;


localparam AXI_BURST_LEN    = 16;
localparam FIFO_RESERVE     = AXI_BURST_LEN*15;

localparam AXI_BURST_BYTES  = AXI_BURST_LEN*DW/8;
localparam NUM_SAMPS        = DW/16;

assign dac_rd_size  = AXI_BURST_LEN-1;
assign dac_rd_rsize =  3'h3;

//---------------------------------------------------------------------------------
//
//  request FIFO logic

assign axi_state_o  =  {dat_fifo_lvl,
                        rst_busy,dac_rd_clr,dat_fifo_empty,(|rf_full_sr),
                        dac_rden,dat_fifo_rden,df_fv_sr[0],dac_do};

assign rst_on_pulse = set_rst_i && !rst_r;
assign dac_rd_clr   = rst_on_pulse || (!axi_en_sr[0] && set_axi_en_i) || (!dat_fifo_rden && df_rden_sr[0]);

always @(posedge dac_clk_i) // shift registers
begin
  rst_r <= set_rst_i;
  if (dac_rd_clr)
    rst_busy <= 'h1;
  else if (rst_busy >= 1)
    rst_busy <= rst_busy + 1;
end

always @(posedge dac_clk_i) // shift registers
begin
  dac_do_sr  <= {dac_do_sr[SL-2:0] , dac_do       };
  df_rden_sr <= {df_rden_sr[SL-2:0], dat_fifo_rden};
  axi_en_sr  <= {axi_en_sr[SL-2:0] , set_axi_en_i };
  dec_val_sr <= {dec_val_sr[SL-2:0], dec_val      };
  rf_full_sr <= {rf_full_sr[SL-2:0], req_fifo_full};
  new_req_sr <= {new_req_sr[SL-2:0], new_req      };
  df_fv_sr   <= {df_fv_sr[SL-2:0],   df_first_valid};

  stat_busy_r <= stat_busy;
end

assign df_wr_rdy   = !dat_fifo_full && !dat_fifo_wr && !dat_fifo_wr_r; // block multiple consecutive writes due to delayed "full" feedback from FIFO

always @(posedge axi_sys.clk)
begin
  rf_rd_sr    <= {rf_rd_sr[SL-2:0]  , req_fifo_rd };
  dat_fifo_wr_r <= dat_fifo_wr;
  req_fifo_empty_r <= req_fifo_empty;
  req_fifo_rd <= !req_fifo_empty_r && !ctrl_busy && !(|rf_rd_sr) && !req_fifo_rd;
end

assign new_req = dac_do && (!(|rf_full_sr)) && (!(new_req_sr[3:0])) && !(dac_rd_clr || |rst_busy) ; // new address burst request
assign buf_ovr_limit = dac_npnt >= set_axi_stop_i;                                        // buffer wrap

always @(posedge dac_clk_i)
begin
  buf_final     <= set_axi_stop_i-DW/8;
  new_req_r     <= new_req;
  if (req_fifo_wr)
    buf_ovr_limit_r <= buf_ovr_limit;

  dac_npnt <= dac_pnt + AXI_BURST_BYTES; // next address
  if (dac_rd_clr) begin // address decision logic
    dac_pnt <= set_axi_start_i;
  end else begin 
    if(new_req) begin
      if (buf_ovr_limit || (dac_do && ~dac_do_sr[0])) begin
        dac_pnt <= set_axi_start_i;
      end else begin
        dac_pnt <= dac_npnt;
      end
    end
  end
end

always @(posedge dac_clk_i) begin // enable writing the request buffer
  if (dac_rstn_i == 1'b0) begin
    r_cycles <=  16'h0 ;
    trig_r   <=   1'b0 ;
  end else begin
    trig_r <= trig_i;
    if (trig_i)
      r_cycles <= set_cyc_cnt_i ;
    else if (!trig_r && |r_cycles && buf_ovr_limit && req_fifo_wr)
      r_cycles <= r_cycles - 16'h1 ;
  end
end

always @(posedge dac_clk_i) begin // enable writing the request buffer
  if (dac_rstn_i == 1'b0) begin
    dac_do    <=  1'b0 ;
  end else begin
    if (set_axi_en_i && trig_i && !rst_on_pulse)
      dac_do <= 1'b1 ;
    else if (rst_on_pulse || ((r_cycles==16'h1) && buf_ovr_limit && req_fifo_wr))
      dac_do <= 1'b0 ;
  end
end

// request FIFO interface
assign req_fifo_wr  = dac_do && ~dac_do_sr[0] ? new_req_r : new_req;
assign req_fifo_in  = {32'h0,
                       29'h0,
                       dac_rd_rsize,
                       dac_rd_size,
                       dac_pnt};


// commands for AXI module
always @(posedge axi_sys.clk) begin
  if (rf_rd_sr[0]) begin
    req_fifo_out_r <= req_fifo_out;
  end
end

assign ctrl_addr   =  req_fifo_out_r[0*AW +: AW];
assign ctrl_size   =  req_fifo_out_r[1*AW +: AW];
assign ctrl_rsize  =  req_fifo_out_r[2*AW +:  3];

//---------------------------------------------------------------------------------
//
//  data FIFO logic - readout of data

always @(posedge dac_clk_i) begin // FIFO empty status - latched
  df_empty_r <= dat_fifo_empty;
  if (fifo_rst || ((cyc_cnt_i==16'h1) && axi_last_o)) begin
    df_nempty_init <= 1'b0;
  end else begin
    if (!dat_fifo_empty && df_empty_r)
      df_nempty_init <= !dat_fifo_empty;
  end
end

always @(posedge dac_clk_i) begin
  if (fifo_rst) begin
    df_first_valid <= 1'b0;
  end else begin
    if (dat_fifo_rden && dat_fifo_rd) // enable data to output register
      df_first_valid <= 1'b1;
    else if (rst_on_pulse || ((cyc_cnt_i==16'h1) && axi_last_o))
      df_first_valid <= 1'b0;
  end
end

always @(posedge dac_clk_i) begin
  if (fifo_rst) begin
    dac_rden <= 1'b0;
  end else begin
    if (trig_r) // just show that the receiver is enabled
      dac_rden <= 1'b1;
    else if (rst_on_pulse || ((cyc_cnt_i==16'h1) && axi_last_o))
      dac_rden <= 1'b0;
  end
end

always @(posedge dac_clk_i) begin // enable reading the data FIFO
  if (dac_rstn_i == 1'b0) begin
    dat_fifo_rden   <= 1'b0;
  end else begin

    if (!dat_fifo_empty && df_empty_r && !df_nempty_init) // first time the FIFO is not empty
      dat_fifo_rden <= 1'b1;
    else if (rst_on_pulse || ((cyc_cnt_i==16'h1) && axi_last_o))
      dat_fifo_rden <= 1'b0;
    
  end
end

reg [ 16-1:0] samp_buf [0:NUM_SAMPS-1]; // sample buffer


always @(posedge dac_clk_i) begin // reading data from 64 bit FIFO
  if (df_fv_sr[0]) // 1 clock delay due to inbuilt FIFO registers
    dac_o  <= samp_buf[fifo_rd_rp_r2][14-1:0];

  dat_fifo_addr <= dat_fifo_out[DW +: 32];

  last_val      <= (dat_fifo_addr == buf_final) && dat_fifo_rden && dec_val && fifo_rd_rp_r2 == 2'h3; // end of burst

  if (last_val)
    last_val_r    <= 1'b1;
  else if(dat_fifo_rd)
    last_val_r    <= 1'b0;

end


assign dat_fifo_rd  = dat_fifo_rden && !dat_fifo_empty && (&fifo_rd_rp && dec_val); // just before we read the next 4 samples
assign axi_last_o   = last_val && !last_val_r;

always @(posedge dac_clk_i) begin // free running output decimation (holds sample for N clock cycles)
  if (dac_rstn_i == 1'b0) begin
    dec_cnt <=  16'h0 ;
  end else begin
    if (dat_fifo_rden) begin
      if (dec_cnt < set_axi_dec_i)
        dec_cnt <= dec_cnt + 1;
      else 
        dec_cnt <= 16'h1;
    end
  end
end

assign dec_val = dec_cnt == set_axi_dec_i;

always @(posedge dac_clk_i) begin // free running read pointer (4 to 1 selector)
  if (dac_rstn_i == 1'b0) begin
    fifo_rd_rp    <=  2'h0 ;
  end else begin
      fifo_rd_rp_r1 <= fifo_rd_rp;
      fifo_rd_rp_r2 <= fifo_rd_rp_r1;
      if (dec_val) begin
        if (&fifo_rd_rp) begin
          if (!dat_fifo_empty)
            fifo_rd_rp <= fifo_rd_rp + 1;
        end else begin
          fifo_rd_rp <= fifo_rd_rp + 1;
        end
      end
  end
end


genvar GV;
generate
for (GV = 0; GV < NUM_SAMPS; GV = GV + 1) begin : read_decoder
  always @(posedge dac_clk_i) begin
    samp_buf[GV] <= dat_fifo_out[GV*16 +: 16];  
  end
end
endgenerate





//---------------------------------------------------------------------------------
//
//  diagnostic logic

logic [32-1: 0] sec_cnt;
logic [32-1: 0] err_cnt;
logic [32-1: 0] transf_cnt;


always @(posedge dac_clk_i) begin
  if (dac_rstn_i == 1'b0) begin
    sec_cnt      <= 32'h0;
    err_cnt      <= 32'h0;
    transf_cnt   <= 32'h0;
    err_cnt_o    <= 32'h0;
    transf_cnt_o <= 32'h0;
  end else begin
    if (sec_cnt  >= 32'd125000000)
      sec_cnt <= 32'h0;
    else
      sec_cnt <= sec_cnt + 1;

    if (sec_cnt == 32'd125000000) begin
      err_cnt_o    <= err_cnt;
      transf_cnt_o <= transf_cnt;
      transf_cnt   <= 32'h0;
      err_cnt      <= 32'h0;
    end else begin
      if (dat_fifo_rden && (&fifo_rd_rp && dec_val)) begin
        if (dat_fifo_empty)
          err_cnt      <= err_cnt    + 1; // how many errors per second
        else
          transf_cnt   <= transf_cnt + 1; // how many successfull transfers per second
      end
    end
  end
end



//---------------------------------------------------------------------------------
//
//  FIFO reset logic

always @(posedge dac_clk_i) begin
  fifo_rst <= dac_rstn_i==1'b0 || dac_rd_clr;
end

(* ASYNC_REG = "TRUE" *)
reg dac_rd_clr_r,dac_rd_clr_r2;
reg fifo_rst_axi;
always @(posedge axi_sys.clk) begin
  dac_rd_clr_r  <= dac_rd_clr;
  dac_rd_clr_r2 <= dac_rd_clr_r;
  fifo_rst_axi  <= axi_sys.rstn==1'b0 || dac_rd_clr_r;
end

//---------------------------------------------------------------------------------
//
//  request and data FIFO

  sync_fifo inst_sync_fifo
  ( 
    .wr_clk         (dac_clk_i        ),
    .rd_clk         (axi_sys.clk      ),
    .rst            (fifo_rst         ),
    .din            (req_fifo_in      ),
    .wr_en          (req_fifo_wr      ),
    .full           (req_fifo_full    ),
    .dout           (req_fifo_out     ),
    .rd_en          (req_fifo_rd      ),
    .empty          (req_fifo_empty   ),
    .wr_rst_busy    (                 ),
    .rd_rst_busy    (                 )
  );

assign dat_fifo_in = {dat_fifo_iaddr,dat_fifo_idata};
  asg_dat_fifo inst_asg_dat_fifo
  (
    .wr_clk         (axi_sys.clk      ),
    .rd_clk         (dac_clk_i        ),
    .rst            (fifo_rst_axi     ),
    .din            (dat_fifo_in      ),
    .wr_en          (dat_fifo_wr      ),
    .full           (dat_fifo_full    ),
    .dout           (dat_fifo_out     ),
    .rd_en          (dat_fifo_rd      ),
    .rd_data_count  (dat_fifo_lvl     ),
    .empty          (dat_fifo_empty   ),
    .wr_rst_busy    (                 ),
    .rd_rst_busy    (                 )
  );


//---------------------------------------------------------------------------------
//
//  interface to AXI

  axi_rd_burst #(
    .DW  (  DW  ) , // data width (8,16,...,1024)
    .AW  (  AW  ) , // address width
    .LW  (  LW  )   // address width of FIFO pointers
  )
  i_rdburst
  (

    // AXI master signals
    .axi_sys      (  axi_sys          ) ,

    // configuration signals
    .cfg_clk_i    (  dac_clk_i        ) , // config clock
    .cfg_rstn_i   (  dac_rstn_i       ) , // config reset

    .ctrl_addr_i  (  ctrl_addr        ) , // request start address
    .ctrl_size_i  (  ctrl_size[4-1:0] ) , // request size
    .ctrl_rsize_i (  ctrl_rsize       ) , // read size ( in bytes)
    .ctrl_val_i   (  rf_rd_sr[1]      ) , // request transfer

    // data
    .rd_data_o    (  dat_fifo_idata   ) , // read data
    .rd_addr_o    (  dat_fifo_iaddr   ) , // read data
    .rd_dval_o    (  dat_fifo_wr      ) , // read data valid
    .rd_drdy_i    (  df_wr_rdy        ) , // read data ready
    .ctrl_busy_o  (  ctrl_busy        ) , // busy @axi_clk
    .stat_busy_o  (  stat_busy        )   // status @cfg_clk
  );

endmodule
