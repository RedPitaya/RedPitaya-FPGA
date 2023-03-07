
/*
* Copyright (c) 2015 Instrumentation Technologies
* All Rights Reserved.
*
* $Id: $
*/

/*
    submodule for configuration modules.
    Synchronizes control-flow from "controler" to
    "register" clock domain.
*/

module sync_rw_single
#(
   parameter   REG_RST_ACT_LVL     = 0    ,
   parameter   CTRL_RST_ACT_LVL    = 0
)
(
   input   ctrl_clk_i  ,
   input   ctrl_rst_i  ,

   input   reg_clk_i   ,
   input   reg_rst_i   ,

   input   ctrl_we_i   ,
   input   ctrl_re_i   ,
   output  ctrl_ack_o  ,

   output  reg_we_o    ,
   output  reg_re_o    ,
   input   reg_ack_i
);

/*
    Controler domain registers
*/
reg ctrl_do         ;
reg ctrl_acked      ;
reg ctrl_done       ;
reg ctrl_done_csff  ;
reg ctrl_we         ;
reg ctrl_re         ;

/*
    Register domain registers
*/
reg reg_do_csff ;
reg reg_do      ;
reg reg_done    ;




/*
    Controler domain logic
*/
always @ (posedge ctrl_clk_i)
begin
   if (ctrl_rst_i == CTRL_RST_ACT_LVL)
   begin
      ctrl_do         <= 1'b0 ;
      ctrl_acked      <= 1'b0 ;
      ctrl_done       <= 1'b0 ;
      ctrl_done_csff  <= 1'b0 ;
   end else
   begin
      if ((ctrl_do == ctrl_acked) && (ctrl_we_i || ctrl_re_i))
         ctrl_do <= !ctrl_do ;

      ctrl_done_csff  <= reg_done         ;
      ctrl_done       <= ctrl_done_csff   ;
      ctrl_acked      <= ctrl_done        ;
   end
end

assign  ctrl_ack_o = ctrl_done != ctrl_acked ;


// latch control
always @ (posedge ctrl_clk_i)
begin
   if (ctrl_rst_i == CTRL_RST_ACT_LVL)
   begin
      ctrl_we <= 1'b0 ;
      ctrl_re <= 1'b0 ;
   end else
   begin
      if (ctrl_we_i) begin
         ctrl_we <= 1'b1 ;
         ctrl_re <= 1'b0 ;
      end
      else if (ctrl_re_i) begin
         ctrl_we <= 1'b0 ;
         ctrl_re <= 1'b1 ;
      end
   end
end


/*
    Register domain logic
*/
always @ (posedge reg_clk_i)
begin
   if (reg_rst_i == REG_RST_ACT_LVL)
   begin
      reg_do_csff <= 1'b0 ;
      reg_do      <= 1'b0 ;
      reg_done    <= 1'b0 ;
   end else
   begin
      reg_do_csff <= ctrl_do      ;
      reg_do      <= reg_do_csff  ;
      if (reg_ack_i)
         reg_done <= reg_do ;
   end
end

assign reg_we_o = (reg_do != reg_done) && ctrl_we ;
assign reg_re_o = (reg_do != reg_done) && ctrl_re ;


endmodule

