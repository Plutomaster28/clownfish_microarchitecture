// OpenRAM SRAM model
// Words: 64, Word size: 64
/// sta-blackbox

module sram_tlb(
`ifdef USE_POWER_PINS
    vdd,
    gnd,
`endif
    clk0,
    csb0,
    web0,
    addr0,
    din0,
    dout0,
    clk1,
    csb1,
    addr1,
    dout1
);

  parameter DATA_WIDTH = 64;
  parameter ADDR_WIDTH = 6;
  parameter RAM_DEPTH  = 64;

`ifdef USE_POWER_PINS
    inout vdd;
    inout gnd;
`endif
  input  clk0;
  input  csb0;
  input  web0;
  input  [ADDR_WIDTH-1:0] addr0;
  input  [DATA_WIDTH-1:0] din0;
  output reg [DATA_WIDTH-1:0] dout0;
  
  input  clk1;
  input  csb1;
  input  [ADDR_WIDTH-1:0] addr1;
  output reg [DATA_WIDTH-1:0] dout1;

  reg [DATA_WIDTH-1:0] mem [0:RAM_DEPTH-1];
  reg                  csb0_reg;
  reg                  web0_reg;
  reg [ADDR_WIDTH-1:0] addr0_reg;
  reg [DATA_WIDTH-1:0] din0_reg;
  reg                  csb1_reg;
  reg [ADDR_WIDTH-1:0] addr1_reg;

  // Port 0: posedge clk0 for input capture
  always @(posedge clk0) begin
    csb0_reg   <= csb0;
    web0_reg   <= web0;
    addr0_reg  <= addr0;
    din0_reg   <= din0;
    
    if (!csb0_reg) begin
      if (!web0_reg) begin
        dout0 <= 64'hx;
      end else begin
        dout0 <= mem[addr0_reg];
      end
    end
  end

  // Port 1: posedge clk1 for input capture
  always @(posedge clk1) begin
    csb1_reg  <= csb1;
    addr1_reg <= addr1;
    
    if (!csb1_reg) begin
      dout1 <= mem[addr1_reg];
    end
  end

  // Port 0: negedge clk0 for memory write
  always @(negedge clk0) begin
    if (!csb0_reg && !web0_reg) begin
      mem[addr0_reg] <= din0_reg;
    end
  end

endmodule
