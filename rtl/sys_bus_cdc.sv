////////////////////////////////////////////////////////////////////////////////
// Module: System bus clock domain cross
// assumes single reads and writes
////////////////////////////////////////////////////////////////////////////////

module sys_bus_cdc2 #(

)(
  input        pll_locked_i,
  sys_bus_if.s bus_s,   // from master
  sys_bus_if.m bus_m    // to   slaves
);

/*
    Controler domain registers
*/
reg ctrl_do         ;
reg ctrl_ack        ;

(* ASYNC_REG = "TRUE" *)
reg [2:0] ctrl_done_csff  ;
reg ctrl_we         ;
reg ctrl_re         ;

(* keep = "TRUE" *) wire ctrl_we_iw = bus_s.wen ;
(* keep = "TRUE" *) wire ctrl_re_iw = bus_s.ren ;



/*
    Register domain registers
*/
(* ASYNC_REG = "TRUE" *)
reg [1:0] reg_do_csff ;
(* ASYNC_REG = "TRUE" *)
reg reg_do      ;
reg reg_done    ;
wire reg_we;
wire reg_re;


(* ASYNC_REG = "TRUE" *)
reg [1:0] reg_we_csff ;
(* ASYNC_REG = "TRUE" *)
reg [1:0] reg_re_csff ;

wire    reg_write_synced ;
wire    reg_read_synced ;
reg     reg_write ;
reg     reg_read  ;
wire    reg_ack_sync = (reg_write || reg_read) && bus_m.ack ;

/*
    Controler domain logic
*/
always @ (posedge bus_s.clk)
begin
    if (bus_s.rstn == 1'b0)
    begin
        ctrl_do         <= 1'b0 ;
        ctrl_done_csff  <= 3'h0 ;
    end else
    begin
      if ((ctrl_do == ctrl_done_csff[2]) && (ctrl_we_iw || ctrl_re_iw))
         ctrl_do <= !ctrl_do ;

      ctrl_done_csff  <= {ctrl_done_csff[1:0], reg_done} ;
    end
end
assign ctrl_ack    = ctrl_done_csff[1] != ctrl_done_csff[2] ;

assign bus_s.ack   = pll_locked_i ? ctrl_ack                 : 1'b1;
assign bus_s.err   = pll_locked_i ? 1'b0                     : 1'b1;
assign bus_s.rdata = pll_locked_i ? bus_m.rdata              : 32'hDEADBEEF;

// latch control
always @ (posedge bus_s.clk)
begin
  if (bus_s.rstn == 1'b0)
  begin
    ctrl_we <= 1'b0 ;
    ctrl_re <= 1'b0 ;
  end else begin
    if (ctrl_we_iw) begin
      ctrl_we <= 1'b1 ;
      ctrl_re <= 1'b0 ;
    end else if (ctrl_re_iw) begin
      ctrl_we <= 1'b0 ;
      ctrl_re <= 1'b1 ;
    end
  end
end

/*
    Register domain logic
*/
always @ (posedge bus_m.clk)
begin
  if (bus_m.rstn == 1'b0)
  begin
    reg_do_csff <= 2'b0 ;
    reg_do      <= 1'b0 ;
    reg_done    <= 1'b0 ;
    reg_we_csff <= 2'h0 ;
    reg_re_csff <= 2'h0 ;
  end else begin
    reg_do_csff <= {reg_do_csff[0], ctrl_do} ;
    reg_do      <=  reg_do_csff[1];
    if (reg_ack_sync)
      reg_done <= reg_do ;

    reg_we_csff <= {reg_we_csff[0], ctrl_we} ;
    reg_re_csff <= {reg_re_csff[0], ctrl_re} ;
   end
end




always @ (posedge bus_m.clk)
begin
  if (bus_m.rstn == 1'b0)
  begin
    reg_write <= 1'b0 ;
    reg_read  <= 1'b0 ;
  end else begin
    reg_write <= reg_write ? !bus_m.ack : reg_write_synced ;
    reg_read  <= reg_read  ? !bus_m.ack : reg_read_synced ;
  end
end

always @ (posedge bus_m.clk)
begin
   if (reg_write_synced || reg_read_synced)
   begin
      bus_m.addr  <= bus_s.addr;
      bus_m.wdata <= bus_s.wdata;
   end
end

assign reg_write_synced = (reg_do != reg_done) && reg_we_csff[1] ;
assign reg_read_synced  = (reg_do != reg_done) && reg_re_csff[1] ;

assign bus_m.wen   = reg_write ;
assign bus_m.ren   = reg_read ;

endmodule: sys_bus_cdc2
