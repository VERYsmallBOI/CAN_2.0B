module Prescaler(can_clk, BRP, Tq, rst);
  input wire can_clk, rst;
  input wire [4:0] BRP;
  output reg Tq;

  reg [4:0] count, ncount;

  always @(posedge can_clk, negedge rst) begin
    if (!rst) begin
      Tq <= 0;
    end else begin
      if (count == BRP) begin
        Tq <= ~Tq;
      end else begin
        Tq <= Tq;
      end
    end
  end

  always @(posedge can_clk, negedge rst) begin
    if (!rst) begin
      count <= 0;
    end else begin
      count <= ncount;
    end
  end

  always @(*) begin
    if (BRP > count) begin
      ncount = count + 1;
    end else begin
      ncount = 0;
    end
  end
endmodule