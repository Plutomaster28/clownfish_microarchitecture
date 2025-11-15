// OpenRAM SRAM model
// Words: 128, Word size: 64, Write size: 8
/// sta-blackbox

module sram_l1_dcache_way(
`ifdef USE_POWER_PINS
    vdd,
    gnd,
`endif
    clk0,
    csb0,
    web0,
    wmask0,
    addr0,
    din0,
    dout0
);

  parameter NUM_WMASKS = 8;
  parameter DATA_WIDTH = 64;
  parameter ADDR_WIDTH = 7;
  parameter RAM_DEPTH  = 128;

`ifdef USE_POWER_PINS
    inout vdd;
    inout gnd;
`endif
  input  clk0;
  input  csb0;
  input  web0;
  input  [NUM_WMASKS-1:0] wmask0;
  input  [ADDR_WIDTH-1:0] addr0;
  input  [DATA_WIDTH-1:0] din0;
  output reg [DATA_WIDTH-1:0] dout0;

  reg [DATA_WIDTH-1:0] mem [0:RAM_DEPTH-1];
  reg                  csb0_reg;
  reg                  web0_reg;
  reg [NUM_WMASKS-1:0] wmask0_reg;
  reg [ADDR_WIDTH-1:0] addr0_reg;
  reg [DATA_WIDTH-1:0] din0_reg;

  integer wmask_idx;

  always @(posedge clk0) begin
    csb0_reg   <= csb0;
    web0_reg   <= web0;
    wmask0_reg <= wmask0;
    addr0_reg  <= addr0;
    din0_reg   <= din0;

    if (!csb0_reg) begin
      if (!web0_reg) begin
        for (wmask_idx = 0; wmask_idx < NUM_WMASKS; wmask_idx = wmask_idx + 1) begin
          if (wmask0_reg[wmask_idx]) begin
            mem[addr0_reg][(wmask_idx*8)+:8] <= din0_reg[(wmask_idx*8)+:8];
          end
        end
        dout0 <= 64'hx;
      end else begin
        dout0 <= mem[addr0_reg];
      end
    end
  end

endmodule
