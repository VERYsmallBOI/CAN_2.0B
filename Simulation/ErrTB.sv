`timescale 1ns / 1ps

module tb_ErrorHandler_Recovery();

    parameter CLK_PERIOD = 10;
    parameter BIT_TIME = 6;
    parameter RECOVERY_SEQUENCES = 11; // Shortened for simulation (11 sequences of 11 bits)

    reg         req_Error_RX;
    reg         req_Error_TX;
    reg  [3:0]  TXSTATES;
    reg  [3:0]  RXSTATES;
    reg         Tq;
    reg         rst;
    reg         srst;
    reg         TXen;
    reg         RXen;
    reg         imTX;
    reg         donefromtx;
    reg         donefromrx;
    reg         Sampled_din;

    wire        TXpin;
    wire [8:0]  TEC;
    wire [8:0]  REC;
    wire        ErrState;
    wire        OvlState;

    ErrorHandler dut (
        .req_Error_RX  (req_Error_RX),
        .req_Error_TX  (req_Error_TX),
        .TXSTATES      (TXSTATES),
        .RXSTATES      (RXSTATES),
        .TXpin         (TXpin),
        .Tq            (Tq),
        .rst           (rst),
        .srst          (srst),
        .TEC           (TEC),
        .REC           (REC),
        .TXen          (TXen),
        .imTX          (imTX),
        .donefromtx    (donefromtx),
        .donefromrx    (donefromrx),
        .Sampled_din   (Sampled_din),
        .ErrState      (ErrState),
        .OvlState      (OvlState)
    );

    always #(CLK_PERIOD/2) Tq = ~Tq;

    reg [2:0] bit_cnt;

    always @(posedge Tq or negedge rst) begin
        if (!rst) begin
            bit_cnt <= 0;
            TXen <= 0;
            RXen <= 0;
        end else begin
            if (bit_cnt == 5) begin
                bit_cnt <= 0;
            end else begin
                bit_cnt <= bit_cnt + 1;
            end
            TXen <= (bit_cnt == 0);
            RXen <= (bit_cnt == 3);
        end
    end

    // Default feedback from TXpin (bus idle during recovery)
    always @(posedge Tq or negedge rst) begin
        if (!rst) begin
            Sampled_din <= 1'b1;
        end else begin
            if (RXen) begin
                Sampled_din <= TXpin; // Normal feedback
            end
        end
    end

    // -----------------------------------------------------------------
    // RANDOM SIGNAL GENERATORS (to test that recovery ignores them)
    // -----------------------------------------------------------------
    reg [3:0] random_counter;

    always @(posedge Tq or negedge rst) begin
        if (!rst) begin
            random_counter <= 0;
            TXSTATES <= 4'd0;
            RXSTATES <= 4'd0;
            req_Error_TX <= 0;
            req_Error_RX <= 0;
            donefromtx <= 0;
            donefromrx <= 0;
            imTX <= 1;
        end else begin
            random_counter <= random_counter + 1;

            // Randomize TXSTATES and RXSTATES (any value between 0-15)
            TXSTATES <= random_counter[3:0];
            RXSTATES <= ~random_counter[3:0];

            // Randomly assert req_Errors (should be ignored during recovery)
            req_Error_TX <= (random_counter[0] & random_counter[1]);
            req_Error_RX <= (random_counter[2] & random_counter[3]);

            // Randomly assert done signals (should be ignored during recovery)
            donefromtx <= random_counter[0];
            donefromrx <= random_counter[1];

            // Toggle imTX randomly
            imTX <= random_counter[2];
        end
    end

    initial begin
        $monitor("Time=%t, bit_cnt=%d, TXen=%b, RXen=%b, State=%d, Cnt=%d, TEC=%d, REC=%d, TXpin=%b, Sampled_din=%b, ErrState=%b, OvlState=%b, Reck=%d",
                 $time, bit_cnt, TXen, RXen, dut.State, dut.Cnt, TEC, REC, TXpin, Sampled_din, ErrState, OvlState, dut.Reck);
    end

    initial begin
        rst = 0;
        srst = 0;
        Tq = 0;
        req_Error_TX = 0;
        req_Error_RX = 0;
        TXSTATES = 4'd0;
        RXSTATES = 4'd0;
        imTX = 1;
        donefromtx = 0;
        donefromrx = 0;
        Sampled_din = 1;

        #20 rst = 1;
        #10 srst = 1;

        // -------------------------------------------------------------
        // Force TEC=256 (Bus-Off) and immediately release
        // -------------------------------------------------------------
        force dut.TEC = 256;
        @(posedge Tq);
        release dut.TEC;

        // Wait for recovery to complete
        // Recovery requires (RECOVERY_SEQUENCES * 11) bits.
        // Each bit = 6 Tq cycles, so total Tq cycles = RECOVERY_SEQUENCES * 11 * 6.
        // Add extra margin for safety.
        repeat (RECOVERY_SEQUENCES * 11 * 6 + 150) @(posedge Tq);

        // After recovery, TEC and REC should be 0
        // Done signals should be processed normally after recovery
        $display("=== Recovery Test Complete ===");
        $display("TEC = %d (Expected: 0)", TEC);
        $display("REC = %d (Expected: 0)", REC);
        $display("State = %d (Expected: 0 = NOERROR)", dut.State);

        $finish;
    end

endmodule