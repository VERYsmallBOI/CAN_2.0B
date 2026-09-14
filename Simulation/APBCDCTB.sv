`timescale 1ns/1ps

module tb_APBCDC_mode;

  reg PCLK, Tq, PRESETn, CAN_RST;
  wire SRST;

  reg         PSEL, PENABLE, PWRITE;
  reg  [5:0]  PADDR;
  reg  [31:0] PWDATA;
  wire        PREADY, PSLVERR;
  wire [31:0] PRDATA;

  wire [2:0]  SJW, Mode;
  wire [3:0]  TPROP, TSEG1, TSEG2;
  wire [4:0]  BRP;

  wire        TRANSMIT, RTR_TX, IDE_TX;
  wire [3:0]  D_Len_TX;
  wire [28:0] ID_TX;
  wire [63:0] FULLDATA_TX;
  reg  [3:0]  TXSTATES;
  reg         done_TX;

  reg         done_RX, IDE_rec, RTR_rec;
  reg  [3:0]  D_Len_rec;
  reg  [63:0] TOFILTERd;
  reg  [28:0] TOFILTERI;
  reg  [8:0]  TEC, REC;

  // --------------------------------------------------------------
  initial begin PCLK = 0; forever #5  PCLK = ~PCLK; end
  initial begin Tq   = 0; #3; forever #50 Tq = ~Tq; end

  // --------------------------------------------------------------
  APBCDC dut (
    .PCLK (PCLK), .PRESETn (PRESETn), .Tq (Tq), .CAN_RST (CAN_RST), .SRST (SRST),
    .PSEL (PSEL), .PENABLE (PENABLE), .PWRITE (PWRITE), .PADDR (PADDR),
    .PWDATA (PWDATA), .PREADY (PREADY), .PSLVERR (PSLVERR), .PRDATA (PRDATA),
    .SJW (SJW), .TPROP (TPROP), .TSEG1 (TSEG1), .TSEG2 (TSEG2), .BRP (BRP), .Mode (Mode),
    .TRANSMIT (TRANSMIT), .TXSTATES (TXSTATES),
    .RTR_TX (RTR_TX), .IDE_TX (IDE_TX), .D_Len_TX (D_Len_TX),
    .ID_TX (ID_TX), .FULLDATA_TX (FULLDATA_TX),
    .done_RX (done_RX), .IDE_rec (IDE_rec), .RTR_rec (RTR_rec), .D_Len_rec (D_Len_rec),
    .TOFILTERd (TOFILTERd), .TOFILTERI (TOFILTERI),
    .TEC (TEC), .REC (REC), .done_TX (done_TX)
  );

  // --------------------------------------------------------------
  task apb_write(input [5:0] addr, input [31:0] data, output integer waiter);
    begin
      waiter = 0;
      @(posedge PCLK);
      PSEL <= 1; PENABLE <= 0; PWRITE <= 1;
      PADDR <= addr; PWDATA <= data;
      @(posedge PCLK);
      PENABLE <= 1;
      while (!PREADY && waiter < 100) begin
        @(posedge PCLK);
        waiter = waiter + 1;
      end
      @(posedge PCLK);
      PSEL <= 0; PENABLE <= 0; PWRITE <= 0; PADDR <= 0; PWDATA <= 0;
    end
  endtask

  integer wcnt;

  // --------------------------------------------------------------
  // SRST pulse watcher (Tq domain)
  // --------------------------------------------------------------
  reg srst_prev;
  initial srst_prev = 0;

  always @(posedge Tq) begin
    if (SRST !== srst_prev)
      $display("[%0t] Tq↑  SRST %s  (Cnt_srst=%0d)",
               $time, SRST ? "→ 1" : "→ 0", dut.Cnt_srst);
    srst_prev <= SRST;
  end

  // --------------------------------------------------------------
  initial begin
    PRESETn = 0;  CAN_RST = 0;
    PSEL = 0;  PENABLE = 0;  PWRITE = 0;  PADDR = 0;  PWDATA = 0;
    TXSTATES = 4'd0;  done_TX = 0;
    done_RX = 0;  IDE_rec = 0;  RTR_rec = 0;  D_Len_rec = 0;
    TOFILTERd = 0;  TOFILTERI = 0;
    TEC = 0;  REC = 0;

    #20;
    PRESETn = 1;  CAN_RST = 1;
    #500;

    // ============================================================
    // Baseline — RESET default values
    // ============================================================
    $display("\n===== BEFORE WRITE =====");
    $display("[%0t] Mode=%b  BRP=%b  SRST=%b  REGBANK_can[0]=0x%02h",
             $time, Mode, BRP, SRST, dut.REGBANK_can[0]);
    $display("        (reset default REGBANK_can[0]=0x04 → Mode=100, BRP[0]=0)");

    // ============================================================
    // Write @ 0 = 0x85
    //   0x85 = 1000_0101
    //     bit[7]   = 1  → BRP[0]=1
    //     bit[2]   = 1  → Mode[2]  = Soft_Reset  = 1
    //     bit[1]   = 0  → Mode[1]  = Listen_Only = 0
    //     bit[0]   = 1  → Mode[0]  = Loopback    = 1
    //   Expected: Mode = 3'b101, BRP[0]=1, SRST pulse
    // ============================================================
    $display("\n===== APB WRITE @ 0 = 0x85 =====");
    apb_write(6'd0, 32'h0000_0085, wcnt);
    $display("[%0t] WR @ 0 done (waitered %0d cyc)  PREADY=%b PSLVERR=%b",
             $time, wcnt, PREADY, PSLVERR);

    // Give the handshake time to commit
    #500;

    $display("\n===== AFTER WRITE =====");
    $display("[%0t] Mode=%b  BRP=%b  SRST=%b  REGBANK_can[0]=0x%02h",
             $time, Mode, BRP, SRST, dut.REGBANK_can[0]);
    $display("        Expected: Mode=101  BRP[0]=1  REGBANK_can[0]=0x85");

    // ============================================================
    // Second write — clear Mode, keep BRP[0]=1
    //   0x80 → Mode=000, BRP[0]=1
    // ============================================================
    $display("\n===== APB WRITE @ 0 = 0x80 (Mode→000) =====");
    apb_write(6'd0, 32'h0000_0080, wcnt);
    #500;
    $display("[%0t] Mode=%b  BRP=%b  REGBANK_can[0]=0x%02h  (want Mode=000, BRP[0]=1)",
             $time, Mode, BRP, dut.REGBANK_can[0]);

    // ============================================================
    // Third write — with TXSTATES busy, should be REJECTED
    // ============================================================
    $display("\n===== TXSTATES→5, write @ 0 should be DROPPED =====");
    @(posedge Tq);
    TXSTATES = 4'd5;
    #1000;

    apb_write(6'd0, 32'h0000_00FF, wcnt);
    #1500;
    $display("[%0t] TXSTATES=%0d  Mode=%b  BRP=%b  REGBANK_can[0]=0x%02h  (want unchanged: Mode=000, [0]=0x80)",
             $time, TXSTATES, Mode, BRP, dut.REGBANK_can[0]);

    #500;
    $finish;
  end

  // --------------------------------------------------------------
  always @(posedge PCLK) begin
    if (PSEL && PENABLE && PREADY)
      $display("[%0t] APB %s @ %0d  PRDATA=0x%08h  PSLVERR=%b",
               $time, PWRITE ? "WR" : "RD", PADDR, PRDATA, PSLVERR);
  end

  // Log only when the handshake is active
  always @(posedge Tq) begin
    if (CAN_RST && (dut.change_can || dut.PWADDR_can != 0))
      $display("[%0t] Tq↑  PWADDR_can=%0d  change_can=%b  done_HS_CAN=%b  REGBANK_can[0]=0x%02h",
               $time, dut.PWADDR_can, dut.change_can, dut.done_HS_CAN, dut.REGBANK_can[0]);
  end

endmodule