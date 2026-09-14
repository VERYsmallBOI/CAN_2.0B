`timescale 1ns / 1ps

module tb_MAINFSM_2NODE;

    // ================================================================
    // Shared Signals
    // ================================================================
    reg         PCLK;
    reg         CAN_CLK;
    reg         PRESETn;
    reg         CAN_RST;

    // APB signals
    reg         PSEL1, PSEL2;
    reg         PENABLE;
    reg         PWRITE;
    reg  [5:0]  PADDR;
    reg  [31:0] PWDATA;

    wire        PREADY1, PREADY2;
    wire        PSLVERR1, PSLVERR2;
    wire [31:0] PRDATA1, PRDATA2;

    // CAN bus — wired AND
    wire TX1, TX2;
    wire RX;

    assign RX = TX1 & TX2;

    wire done_RXs1, done_TXs1;
    wire done_RXs2, done_TXs2;


    // ================================================================
    // DUT 1
    // ================================================================
    MAINFSM dut1 (
        .CAN_CLK  (CAN_CLK),
        .CAN_RST  (CAN_RST),
        .RX       (RX),
        .TX       (TX1),

        .PCLK     (PCLK),
        .PRESETn  (PRESETn),
        .PSEL     (PSEL1),
        .PENABLE  (PENABLE),
        .PWRITE   (PWRITE),
        .PADDR    (PADDR),
        .PWDATA   (PWDATA),
        .PREADY   (PREADY1),
        .PSLVERR  (PSLVERR1),
        .PRDATA   (PRDATA1),

        .done_RXs (done_RXs1),
        .done_TXs (done_TXs1)
    );


    // ================================================================
    // DUT 2
    // ================================================================
    MAINFSM dut2 (
        .CAN_CLK  (CAN_CLK),
        .CAN_RST  (CAN_RST),
        .RX       (RX),
        .TX       (TX2),

        .PCLK     (PCLK),
        .PRESETn  (PRESETn),
        .PSEL     (PSEL2),
        .PENABLE  (PENABLE),
        .PWRITE   (PWRITE),
        .PADDR    (PADDR),
        .PWDATA   (PWDATA),
        .PREADY   (PREADY2),
        .PSLVERR  (PSLVERR2),
        .PRDATA   (PRDATA2),

        .done_RXs (done_RXs2),
        .done_TXs (done_TXs2)
    );


    // ================================================================
    // Clocks
    // ================================================================
    initial begin
        PCLK = 1'b0;
    end

    always #5 PCLK = ~PCLK;


    initial begin
        CAN_CLK = 1'b0;

        #3;

        forever #10 CAN_CLK = ~CAN_CLK;
    end


    // ================================================================
    // Reset
    // ================================================================
    initial begin
        PRESETn = 1'b0;
        CAN_RST = 1'b0;

        #200;

        PRESETn = 1'b1;
        CAN_RST = 1'b1;
    end


    // ================================================================
    // Common APB bus initialization
    // ================================================================
    initial begin
        PSEL1   = 1'b0;
        PSEL2   = 1'b0;
        PENABLE = 1'b0;
        PWRITE  = 1'b0;
        PADDR   = 6'd0;
        PWDATA  = 32'd0;
    end


    // ================================================================
    // APB WRITE — BOTH NODES
    //
    // APB:
    //
    //       SETUP              ACCESS
    //        |                   |
    // PSEL   ────────────────────┐
    //                            |
    // PENABLE       ─────────────┐
    //                            |
    // PREADY                    ↑
    //
    // Signals are driven on negedge so DUT samples them cleanly
    // on posedge.
    // ================================================================
    task apb_write_both;
        input [5:0]  addr;
        input [31:0] data;

        begin

            // --------------------------------------------------------
            // SETUP phase
            // --------------------------------------------------------
            @(negedge PCLK);

            PSEL1   = 1'b1;
            PSEL2   = 1'b1;
            PENABLE = 1'b0;
            PWRITE  = 1'b1;
            PADDR   = addr;
            PWDATA  = data;


            // --------------------------------------------------------
            // ACCESS phase
            // --------------------------------------------------------
            @(negedge PCLK);

            PENABLE = 1'b1;


            // --------------------------------------------------------
            // Wait until BOTH slaves are ready
            // --------------------------------------------------------
            while (!(PREADY1 && PREADY2))
                @(negedge PCLK);


            // --------------------------------------------------------
            // Transfer is complete.
            //
            // Remove APB signals before the next posedge so the DUT
            // does not interpret the completed access as a new one.
            // --------------------------------------------------------
            @(negedge PCLK);

            PSEL1   = 1'b0;
            PSEL2   = 1'b0;
            PENABLE = 1'b0;
            PWRITE  = 1'b0;
            PADDR   = 6'd0;
            PWDATA  = 32'd0;


            $display("[%0t] APB WR BOTH : addr=%0d data=0x%08h",
                     $time, addr, data);

        end
    endtask


    // ================================================================
    // APB WRITE — NODE 1 ONLY
    // ================================================================
    task apb_write_node1;
        input [5:0]  addr;
        input [31:0] data;

        begin

            // --------------------------------------------------------
            // SETUP
            // --------------------------------------------------------
            @(negedge PCLK);

            PSEL1   = 1'b1;
            PSEL2   = 1'b0;
            PENABLE = 1'b0;
            PWRITE  = 1'b1;
            PADDR   = addr;
            PWDATA  = data;


            // --------------------------------------------------------
            // ACCESS
            // --------------------------------------------------------
            @(negedge PCLK);

            PENABLE = 1'b1;


            // --------------------------------------------------------
            // Wait for Node 1
            // --------------------------------------------------------
            while (!PREADY1)
                @(negedge PCLK);


            // --------------------------------------------------------
            // End transfer
            // --------------------------------------------------------
            @(negedge PCLK);

            PSEL1   = 1'b0;
            PSEL2   = 1'b0;
            PENABLE = 1'b0;
            PWRITE  = 1'b0;
            PADDR   = 6'd0;
            PWDATA  = 32'd0;


            $display("[%0t] APB WR NODE1: addr=%0d data=0x%08h",
                     $time, addr, data);

        end
    endtask


    // ================================================================
    // APB READ — BOTH NODES
    // ================================================================
    task apb_read_both;
        input [5:0] addr;

        reg [31:0] rdata1;
        reg [31:0] rdata2;

        begin

            // --------------------------------------------------------
            // SETUP
            // --------------------------------------------------------
            @(negedge PCLK);

            PSEL1   = 1'b1;
            PSEL2   = 1'b1;
            PENABLE = 1'b0;
            PWRITE  = 1'b0;
            PADDR   = addr;
            PWDATA  = 32'd0;


            // --------------------------------------------------------
            // ACCESS
            // --------------------------------------------------------
            @(negedge PCLK);

            PENABLE = 1'b1;


            // --------------------------------------------------------
            // Wait for BOTH nodes
            // --------------------------------------------------------
            while (!(PREADY1 && PREADY2))
                @(negedge PCLK);


            // --------------------------------------------------------
            // Capture read data while transfer is complete
            // --------------------------------------------------------
            rdata1 = PRDATA1;
            rdata2 = PRDATA2;


            // --------------------------------------------------------
            // End transfer
            // --------------------------------------------------------
            @(negedge PCLK);

            PSEL1   = 1'b0;
            PSEL2   = 1'b0;
            PENABLE = 1'b0;
            PWRITE  = 1'b0;
            PADDR   = 6'd0;
            PWDATA  = 32'd0;


            $display("[%0t] APB RD BOTH : addr=%0d (0x%02h) : Node1=0x%08h Node2=0x%08h",
                     $time,
                     addr,
                     addr,
                     rdata1,
                     rdata2);

        end
    endtask


    // ================================================================
    // APB READ — NODE 1 ONLY
    // ================================================================
    task apb_read_node1;
        input [5:0] addr;

        reg [31:0] rdata1;

        begin

            // --------------------------------------------------------
            // SETUP
            // --------------------------------------------------------
            @(negedge PCLK);

            PSEL1   = 1'b1;
            PSEL2   = 1'b0;
            PENABLE = 1'b0;
            PWRITE  = 1'b0;
            PADDR   = addr;
            PWDATA  = 32'd0;


            // --------------------------------------------------------
            // ACCESS
            // --------------------------------------------------------
            @(negedge PCLK);

            PENABLE = 1'b1;


            // --------------------------------------------------------
            // Wait for Node 1
            // --------------------------------------------------------
            while (!PREADY1)
                @(negedge PCLK);


            // --------------------------------------------------------
            // Capture data
            // --------------------------------------------------------
            rdata1 = PRDATA1;


            // --------------------------------------------------------
            // End transfer
            // --------------------------------------------------------
            @(negedge PCLK);

            PSEL1   = 1'b0;
            PSEL2   = 1'b0;
            PENABLE = 1'b0;
            PWRITE  = 1'b0;
            PADDR   = 6'd0;
            PWDATA  = 32'd0;


            $display("[%0t] APB RD NODE1: addr=%0d (0x%02h) :   Node1=0x%08h",
                     $time,
                     addr,
                     addr,
                     rdata1);

        end
    endtask


    // ================================================================
    // CAN STATE MONITOR
    // ================================================================
    reg [3:0] p_TXST1;
    reg [3:0] p_RXST1;
    reg [3:0] p_TXST2;
    reg [3:0] p_RXST2;

    reg       p_TX1;
    reg       p_TX2;
    reg       p_RX;

    reg       p_dTx1;
    reg       p_dRx1;
    reg       p_dTx2;
    reg       p_dRx2;


    initial begin

        p_TXST1 = 4'hF;
        p_RXST1 = 4'hF;

        p_TXST2 = 4'hF;
        p_RXST2 = 4'hF;

        p_TX1 = 1'bx;
        p_TX2 = 1'bx;
        p_RX  = 1'bx;

        p_dTx1 = 1'bx;
        p_dRx1 = 1'bx;

        p_dTx2 = 1'bx;
        p_dRx2 = 1'bx;

    end


    always @(posedge CAN_CLK) begin

        if (dut1.TXSTATES !== p_TXST1 ||
            dut1.RXSTATES !== p_RXST1 ||
            dut2.TXSTATES !== p_TXST2 ||
            dut2.RXSTATES !== p_RXST2 ||
            TX1          !== p_TX1   ||
            TX2          !== p_TX2   ||
            RX           !== p_RX    ||
            done_TXs1    !== p_dTx1  ||
            done_RXs1    !== p_dRx1  ||
            done_TXs2    !== p_dTx2  ||
            done_RXs2    !== p_dRx2) begin

            $display(
                "[%0t] N1:TXST=%0d RXST=%0d | N2:TXST=%0d RXST=%0d | TX1=%b TX2=%b RX=%b | dTx1=%b dRx1=%b dTx2=%b dRx2=%b",

                $time,

                dut1.TXSTATES,
                dut1.RXSTATES,

                dut2.TXSTATES,
                dut2.RXSTATES,

                TX1,
                TX2,
                RX,

                done_TXs1,
                done_RXs1,

                done_TXs2,
                done_RXs2
            );

            p_TXST1 <= dut1.TXSTATES;
            p_RXST1 <= dut1.RXSTATES;

            p_TXST2 <= dut2.TXSTATES;
            p_RXST2 <= dut2.RXSTATES;

            p_TX1 <= TX1;
            p_TX2 <= TX2;
            p_RX  <= RX;

            p_dTx1 <= done_TXs1;
            p_dRx1 <= done_RXs1;

            p_dTx2 <= done_TXs2;
            p_dRx2 <= done_RXs2;

        end

    end


    // ================================================================
    // Tq tick counter
    // ================================================================
    integer tq_count;

    initial tq_count = 0;

    always @(posedge dut1.Tq)
        tq_count = tq_count + 1;


    // ================================================================
    // MAIN STIMULUS
    // ================================================================
    initial begin

        // ------------------------------------------------------------
        // Wait for reset release
        // ------------------------------------------------------------
        wait(PRESETn == 1'b1 && CAN_RST == 1'b1);

        repeat (20)
            @(posedge PCLK);


        // ============================================================
        // HEADER
        // ============================================================
        $display("");
        $display("=================================================");
        $display("  2-Node CAN Test");
        $display("  Node1 transmits, Node2 receives");
        $display("=================================================");


        // ============================================================
        // STEP 1
        // Timing configuration @ 0
        // ============================================================
        $display("");
        $display("--- STEP 1: timing config @ 0 (both) ---");

        apb_write_both(
            6'd0,
            (3'b010 << 24) |    // SJW   = 2
            (4'h1   << 20) |   // TPROP = 1
            (4'h2   << 16) |   // TSEG2 = 2
            (4'h1   << 12) |   // TSEG1 = 1
            (5'h01  <<  7) |   // BRP   = 1
            (3'b000)            // Normal mode
        );

        repeat (2000)
            @(posedge PCLK);


        // ============================================================
        // STEP 2
        // TXDATAL @ 16
        // ============================================================
        $display("");
        $display("--- STEP 2: TXDATAL @ 16 (both) ---");

        apb_write_both(
            6'd16,
            32'h4B43_5546
        );

        repeat (2000)
            @(posedge PCLK);


        // ============================================================
        // STEP 3
        // TXID @ 4
        // ============================================================
        $display("");
        $display("--- STEP 3: TXID @ 4 (both) ---");

        apb_write_both(
            6'd4,
            {3'b000, 29'b10101010001100101010101000011}
        );

        repeat (2000)
            @(posedge PCLK);


        // ============================================================
        // STEP 4
        // TXCTRL @ 8
        // ============================================================
        $display("");
        $display("--- STEP 4: TXCTRL @ 8 (both) ---");

        apb_write_both(
            6'd8,
            32'h0000_0014
        );

        repeat (2000)
            @(posedge PCLK);


        // ============================================================
        // STEP 5
        // TXREQ @ 20 — NODE 1 ONLY
        // ============================================================
        $display("");
        $display("--- STEP 5: TXREQ @ 20 (Node1 ONLY) ---");

        apb_write_node1(
            6'd20,
            32'h0000_0001
        );


        $display("");
        $display("[%0t] TXREQ sent to Node1. Waiting for frame + ACK...",
                 $time);


        // ------------------------------------------------------------
        // Allow CAN transaction to complete
        // ------------------------------------------------------------
        repeat (2000)
            @(posedge CAN_CLK);


        // ============================================================
        // FINAL STATE DUMP
        // ============================================================
        $display("");
        $display("=================================================");
        $display("  [%0t] Final State Dump", $time);
        $display("=================================================");


        // ------------------------------------------------------------
        // Node 1
        // ------------------------------------------------------------
        $display("  --- Node 1 (transmitter) ---");

        $display("    TXSTATES     = %0d", dut1.TXSTATES);
        $display("    RXSTATES     = %0d", dut1.RXSTATES);

        $display("    TX pin (TX1) = %b", TX1);

        $display("    done_TXs1    = %b", done_TXs1);
        $display("    done_RXs1    = %b", done_RXs1);

        $display("    TEC          = 0x%h", dut1.TEC);
        $display("    REC          = 0x%h", dut1.REC);

        $display("    imTX         = %b", dut1.imTX);

        $display("    req_Error_TX = %b", dut1.req_Error_TX);
        $display("    req_Error_RX = %b", dut1.req_Error_RX);


        // ------------------------------------------------------------
        // Node 2
        // ------------------------------------------------------------
        $display("");
        $display("  --- Node 2 (receiver) ---");

        $display("    TXSTATES     = %0d", dut2.TXSTATES);
        $display("    RXSTATES     = %0d", dut2.RXSTATES);

        $display("    TX pin (TX2) = %b", TX2);

        $display("    done_TXs2    = %b", done_TXs2);
        $display("    done_RXs2    = %b", done_RXs2);

        $display("    TEC          = 0x%h", dut2.TEC);
        $display("    REC          = 0x%h", dut2.REC);

        $display("    imTX         = %b", dut2.imTX);

        $display("    req_Error_TX = %b", dut2.req_Error_TX);
        $display("    req_Error_RX = %b", dut2.req_Error_RX);

        $display("    TOFILTERd    = 0x%h", dut2.TOFILTERd);
        $display("    TOFILTERI    = 0x%h", dut2.TOFILTERI);

        $display("    D_Len_rec    = %0d", dut2.D_Len_rec);
        $display("    IDE_rec      = %b", dut2.IDE_rec);
        $display("    RTR_rec      = %b", dut2.RTR_rec);


        // ------------------------------------------------------------
        // Shared CAN bus
        // ------------------------------------------------------------
        $display("");
        $display("  --- Shared Bus ---");

        $display("    TX1      = %b", TX1);
        $display("    TX2      = %b", TX2);
        $display("    RX       = %b", RX);
        $display("    Tq ticks = %0d", tq_count);

        $display("=================================================");


        // ============================================================
        // APB REGISTER READS
        // ============================================================
        $display("");
        $display("=================================================");
        $display("  APB Register Reads: addr 40, 28, 32");
        $display("=================================================");


        apb_read_both(6'd40);

        repeat (10)
            @(posedge PCLK);


        apb_read_both(6'd28);

        repeat (10)
            @(posedge PCLK);


        apb_read_both(6'd32);

        repeat (10)
            @(posedge PCLK);


        // ============================================================
        // RXFIFO_POP @ 24
        // ============================================================
        $display("");
        $display("=================================================");
        $display("  APB Write: RXFIFO_POP @ 24");
        $display("  PWDATA = 0x00000001");
        $display("=================================================");


        apb_write_both(
            6'd24,
            32'h0000_0001
        );

        repeat (10)
            @(posedge PCLK);


        // ============================================================
        // Reset monitor previous values
        // ============================================================
        $display("");
        $display("--- Resetting monitor prev regs ---");

        p_TXST1 = 4'hF;
        p_RXST1 = 4'hF;

        p_TXST2 = 4'hF;
        p_RXST2 = 4'hF;

        p_TX1 = 1'bx;
        p_TX2 = 1'bx;
        p_RX  = 1'bx;

        p_dTx1 = 1'bx;
        p_dRx1 = 1'bx;

        p_dTx2 = 1'bx;
        p_dRx2 = 1'bx;


        // ------------------------------------------------------------
        // Allow state changes after POP
        // ------------------------------------------------------------
        repeat (200)
            @(posedge CAN_CLK);


        // ============================================================
        // APB READ @ 28 AFTER POP
        // ============================================================
        $display("");
        $display("=================================================");
        $display("  APB Read @ 28 after RXFIFO_POP");
        $display("=================================================");

        apb_read_both(6'd28);

        repeat (200)
            @(posedge PCLK);


        // ============================================================
        // FINAL APB SNAPSHOT
        // ============================================================
        $display("");
        $display("=================================================");
        $display("  APB Signal Snapshot");
        $display("=================================================");

        $display("  PSEL1    = %b", PSEL1);
        $display("  PSEL2    = %b", PSEL2);
        $display("  PENABLE  = %b", PENABLE);
        $display("  PWRITE   = %b", PWRITE);

        $display("  PADDR    = 0x%02h (%0d)", PADDR, PADDR);
        $display("  PWDATA   = 0x%08h", PWDATA);

        $display("  PREADY1  = %b", PREADY1);
        $display("  PREADY2  = %b", PREADY2);

        $display("  PSLVERR1 = %b", PSLVERR1);
        $display("  PSLVERR2 = %b", PSLVERR2);

        $display("  PRDATA1  = 0x%08h", PRDATA1);
        $display("  PRDATA2  = 0x%08h", PRDATA2);

        $display("=================================================");


        // ============================================================
        // END SIMULATION
        // ============================================================
        $finish;

    end

endmodule

