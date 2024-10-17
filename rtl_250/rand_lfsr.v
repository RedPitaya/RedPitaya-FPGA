////////////////////////////////////////////////////////////////////////////////
// Module: Pseudo-random number generator
// Authors: Jure Trnovec
// Linear-feedback shift register
// Based on Xilinx XAPP052 and wiki/Linear-feedback_shift_register
////////////////////////////////////////////////////////////////////////////////

module rand_lfsr #(
    parameter DW = 14
  )(
    input            clk_i,
    input            rstn_i,
    input            init_i,
    input  [32-1: 0] seed_i,

    output [DW-1: 0] dat_o
  );
  
  ////////////////////////////////////////////////////////////////////////////////
  // local signals
  ////////////////////////////////////////////////////////////////////////////////
  
  genvar GV;
  localparam N_LFSR = 64;
  localparam N1     = 60-1; 
  localparam N2     = 61-1; 
  localparam N3     = 63-1; 
  localparam N4     = 64-1; 

reg [ 6-1:0] reset = 6'h0;
reg          init_r;
always @(posedge clk_i) begin
  if (rstn_i==1'b0) begin
    init_r <= 1'b0;
    reset  <= 6'h0;
  end else begin
    init_r <= init_i;
    if ((reset > 0 && reset < 32) || init_i || init_r)
      reset <= reset +1;
    else
      reset <= 'h0;
  end
end


  generate
  for (GV=0; GV < DW; GV=GV+1) begin:lfsrs
    reg [N_LFSR-1:0] lfsr_reg;
    wire             fb_xnor;

    assign fb_xnor   = lfsr_reg[N1] ~^ lfsr_reg[N2] ~^ lfsr_reg[N3] ~^ lfsr_reg[N4];
    assign dat_o[GV] = lfsr_reg[N_LFSR-1];

    always @(posedge clk_i)
    if (|reset || rstn_i == 1'b0) begin
      lfsr_reg <= seed_i << GV;
    end else begin
      lfsr_reg <= {lfsr_reg[N_LFSR-2:0],fb_xnor};
    end

  end
  endgenerate

endmodule
  