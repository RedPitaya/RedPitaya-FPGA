`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/18/2025 01:51:40 PM
// Design Name: 
// Module Name: tb_red_pitaya_scope
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module tb_red_pitaya_scope;
 reg clk, set, reset, ena;
    wire q, q_n;
    
localparam ADW = 16;
localparam MNA = 2;
localparam type SBA_T = logic signed [ADW-1:0];  // acquire
SBA_T [MNA-1:0]          adc_dat;

logic [31:0] rnddata ;
// system bus
//sys_bus_if   ps_sys      (.clk (fclk[0]), .rstn (frstn[0]));
sys_bus_if   sys [8-1:0] (.clk (clk), .rstn (reset));
 
axi_sys_if axi0_sys (.clk(clk    ), .rstn(reset    ));
axi_sys_if axi1_sys (.clk(clk    ), .rstn(reset   ));
    
red_pitaya_scope i_scope (
  // ADC
  .adc_a_i       (adc_dat[0]  ),  // CH 1
  .adc_b_i       (adc_dat[1]  ),  // CH 2
  .adc_clk_i     (clk     ),  // clock
  .adc_rstn_i    (reset    ),  // reset - active low
  .trig_ext_i    (trig_ext    ),  // external trigger
  .trig_asg_i    (trig_asg_out),  // ASG trigger
  .trig_ext_asg_o(trig_ext_asg01),
  .trig_ext_asg_i(trig_ext_asg01),
  .daisy_trig_o  (scope_trigo ),
  // AXI0 master                 // AXI1 master
  .axi0_waddr_o  (axi0_sys.waddr ),  .axi1_waddr_o  (axi1_sys.waddr ),
  .axi0_wdata_o  (axi0_sys.wdata ),  .axi1_wdata_o  (axi1_sys.wdata ),
  .axi0_wsel_o   (axi0_sys.wsel  ),  .axi1_wsel_o   (axi1_sys.wsel  ),
  .axi0_wvalid_o (axi0_sys.wvalid),  .axi1_wvalid_o (axi1_sys.wvalid),
  .axi0_wlen_o   (axi0_sys.wlen  ),  .axi1_wlen_o   (axi1_sys.wlen  ),
  .axi0_wfixed_o (axi0_sys.wfixed),  .axi1_wfixed_o (axi1_sys.wfixed),
  .axi0_werr_i   (axi0_sys.werr  ),  .axi1_werr_i   (axi1_sys.werr  ),
  .axi0_wrdy_i   (axi0_sys.wrdy  ),  .axi1_wrdy_i   (axi1_sys.wrdy  ),
  // System bus
  .sys_addr      (sys[1].addr ),
  .sys_wdata     (sys[1].wdata),
  .sys_wen       (sys[1].wen  ),
  .sys_ren       (sys[1].ren  ),
  .sys_rdata     (sys[1].rdata),
  .sys_err       (sys[1].err  ),
  .sys_ack       (sys[1].ack  )
);

initial begin 
    $dumpfile("testtest.vcd");
    $dumpvars(0,tb_red_pitaya_scope);
    reset = 0;
    #13;
    reset = 1;
    sys[1].addr = 4'h3;
    #20000;
    //$stop;
    $finish;
end

    /*
     * Generate a 100Mhz (10ns) clock 
     */
    always begin
        clk = 1; #2;
        clk = 0; #2;
    end
    
    /*
     * ena signal behavior 
     */
    always begin 
        sys[1].wen = 0;
        ena = 1; #100;
        sys[1].wen = 1;
        ena = 0; #100;
    end   

    always begin
        rnddata = $random; #2000;
        adc_dat[0] = rnddata[15:0];
    end
    
    
endmodule
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
