interface axi_sys_if #(
  int unsigned AW = 32,    // address width
  int unsigned DW = 64,    // data width
  int unsigned SW = DW/8,  // select width
  int unsigned LW = 4      // length width
)(
  // global signals
  input logic clk,
  input logic rstn
);

logic [ AW-1: 0] waddr  ;
logic [ DW-1: 0] wdata  ;
logic [ SW-1: 0] wsel   ;
logic [  3-1: 0] wsize  ;
logic            wvalid ;
logic [ LW-1: 0] wlen   ;
logic            wfixed ;
logic            werr   ;
logic            wrdy   ;

logic [ AW-1: 0] raddr  ;
logic [ DW-1: 0] rdata  ;
logic [ SW-1: 0] rsel   ;
logic [  3-1: 0] rsize  ;
logic            rvalid ;
logic [ LW-1: 0] rlen   ;
logic            rfixed ;
logic            rerr   ;
logic            rrdym  ;
logic            rrdys  ;
logic            rardy  ;


// local signals for transfer conditions
logic AWtransfer;
logic  Wtransfer;
logic  Btransfer;
logic ARtransfer;
logic  Rtransfer;

// transfer conditions
assign AWtransfer = wvalid & wrdy;
assign  Wtransfer = wvalid & wrdy;
assign ARtransfer = rvalid & rardy;
assign  Rtransfer = rrdys  & rrdym;


modport m (
  input  clk     ,
  input  rstn    ,

  input  waddr   ,
  input  wdata   ,
  input  wsel    ,
  input  wvalid  ,
  input  wlen    ,
  input  wsize   ,
  input  wfixed  ,
  output werr    ,
  output wrdy    ,

  input  AWtransfer,
  input  Wtransfer ,
  input  ARtransfer,
  input  Rtransfer ,

  input  raddr   ,
  input  rsel    ,
  input  rvalid  ,
  input  rlen    ,
  input  rsize   ,
  input  rfixed  ,
  output rdata   ,
  output rerr    ,
  output rrdym   ,
  input  rrdys   ,
  output rardy
);

modport s (
  input  clk     ,
  input  rstn    ,

  output waddr   ,
  output wdata   ,
  output wsel    ,
  output wvalid  ,
  output wlen    ,
  output wsize   ,
  output wfixed  ,
  input  werr    ,
  input  wrdy    ,

  input  AWtransfer,
  input  Wtransfer ,
  input  ARtransfer,
  input  Rtransfer ,
  
  output raddr   ,
  output rsel    ,
  output rvalid  ,
  output rlen    ,
  output rsize   ,
  output rfixed  ,
  input  rdata   ,
  input  rerr    ,
  input  rrdym   ,
  output rrdys   ,
  input  rardy
);

endinterface: axi_sys_if
