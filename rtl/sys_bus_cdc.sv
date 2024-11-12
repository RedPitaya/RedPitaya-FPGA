////////////////////////////////////////////////////////////////////////////////
// Module: System bus clock domain cross
// assumes single reads and writes
////////////////////////////////////////////////////////////////////////////////

module sys_bus_cdc #(

)(
  input        pll_locked_i,
  sys_bus_if.s bus_s,   // from master
  sys_bus_if.m bus_m    // to   slaves
);

/*
    Controler domain registers
*/
reg ctrl_do         ;
reg ctrl_acked      ;

(* ASYNC_REG = "TRUE" *)
reg ctrl_done_csff  ;
(* ASYNC_REG = "TRUE" *)
reg ctrl_done       ;
reg ctrl_do_write   ;
reg ctrl_do_read    ;




/*
    Register domain registers
*/
(* ASYNC_REG = "TRUE" *)
reg reg_do_csff ;
(* ASYNC_REG = "TRUE" *)
reg reg_do      ;
reg reg_do_r    ;
reg reg_done    ;
wire reg_we;
wire reg_re;

(* ASYNC_REG = "TRUE" *)
reg reg_do_write_csff;
(* ASYNC_REG = "TRUE" *)
reg reg_do_write;
reg reg_do_write_r, reg_do_write_r2;

(* ASYNC_REG = "TRUE" *)
reg reg_do_read_csff;
(* ASYNC_REG = "TRUE" *)
reg reg_do_read;
reg reg_do_read_r, reg_do_read_r2;
reg [32-1:0] reg_rdata    ;

/*
    Controler domain logic
*/
always @ (posedge bus_s.clk)
begin
    if (bus_s.rstn == 1'b0)
    begin
        ctrl_do         <= 1'b0 ;
        ctrl_do_write   <= 1'b0 ;
        ctrl_do_read    <= 1'b0 ;

        ctrl_acked      <= 1'b0 ;
        ctrl_done       <= 1'b0 ;
        ctrl_done_csff  <= 1'b0 ;
    end else
    begin
        if (bus_s.wen || bus_s.ren)
            ctrl_do <= 1'b1 ;
        else if (bus_s.ack)
            ctrl_do <= 1'b0;

        if (bus_s.wen)
            ctrl_do_write <= 1'b1 ;
        else if (bus_s.ack)
            ctrl_do_write <= 1'b0;

        if (bus_s.ren)
            ctrl_do_read <= 1'b1 ;
        else if (bus_s.ack)
            ctrl_do_read <= 1'b0;

        ctrl_done_csff  <= reg_done         ;
        ctrl_done       <= ctrl_done_csff   ;
        ctrl_acked      <= ctrl_done        ;
    end
end

assign bus_s.ack   = pll_locked_i ? ctrl_done && !ctrl_acked : 1'b1;
assign bus_s.err   = pll_locked_i ? 1'b0                     : 1'b1;
assign bus_s.rdata = pll_locked_i ? reg_rdata                : 32'hDEADBEEF;

reg     adc_ack_sync;
reg     adc_ack_r0 ;
reg     adc_ack_r1 ;
reg     adc_ack_r2 ;


/*
    Register domain logic
*/
always @ (posedge bus_m.clk)
begin
    if (bus_m.rstn == 1'b0)
    begin
        reg_do_csff <= 1'b0 ;
        reg_do      <= 1'b0 ;
        reg_done    <= 1'b0 ;
    end else
    begin
        adc_ack_sync <= bus_m.ack;
        adc_ack_r0   <= adc_ack_sync;
        adc_ack_r1 <= adc_ack_r0;
        adc_ack_r2 <= adc_ack_r1;

        reg_do_csff <= ctrl_do      ;
        reg_do      <= reg_do_csff  ;
        reg_do_r    <= reg_do;

        reg_do_write_csff <= ctrl_do_write      ;
        reg_do_write      <= reg_do_write_csff  ;
        reg_do_write_r    <= reg_do_write  ;
        reg_do_write_r2   <= reg_do_write_r  ;

        reg_do_read_csff  <= ctrl_do_read      ;
        reg_do_read       <= reg_do_read_csff  ;
        reg_do_read_r     <= reg_do_read  ;
        reg_do_read_r2    <= reg_do_read_r  ;

        if (adc_ack_sync)
            reg_done <= reg_do ;
        else if (adc_ack_r2)
            reg_done <= 1'b0;

        if (bus_m.ack)
            reg_rdata <= bus_m.rdata ;
    end
end

always @ (posedge bus_m.clk)
begin
    if (bus_m.rstn == 1'b0)
    begin
        bus_m.wen <= 1'b0 ;
        bus_m.ren <= 1'b0 ;
    end else
    begin
        bus_m.wen <= reg_do_write_r && ~reg_do_write_r2 ;
        bus_m.ren <= reg_do_read_r  && ~reg_do_read_r2 ;
    end
end

always @ (posedge bus_m.clk)
begin
    if ((reg_do_write && ~reg_do_write_r) || (reg_do_read && ~reg_do_read_r))
    begin
        bus_m.addr  <= bus_s.addr  ;
        bus_m.wdata <= bus_s.wdata ;
    end
end

endmodule: sys_bus_cdc
