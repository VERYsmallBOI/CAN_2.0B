`timescale 1ns / 1ps

module tb_Rengine();

    // Testbench signals
    reg         RXBUS;
    reg         TXVALUE;
    reg  [1:0]  STATE;
    reg  [3:0]  TPROP;
    reg  [3:0]  TSEG1;
    reg  [3:0]  TSEG2;
    reg         Tq;
    reg         rst;
    
    wire [4:0]  CNT1;
    wire [3:0]  CNT2;
    wire        RXOUT;
    wire        TXen;

    // Instantiate the Device Under Test (DUT)
    Rengine dut (
        .RXBUS(RXBUS),
        .STATE(STATE),
        .TXVALUE(TXVALUE),
        .CNT1(CNT1),
        .CNT2(CNT2),
        .TPROP(TPROP),
        .TSEG1(TSEG1),
        .TSEG2(TSEG2),
        .Tq(Tq),
        .rst(rst),
        .RXOUT(RXOUT),
        .TXen(TXen)
    );

    // Clock generation: 10 ns period (100 MHz Tq)
    always #5 Tq = ~Tq;

    // VCD dump for waveform viewing
    initial begin
        $dumpfile("Rengine_tb.vcd");
        $dumpvars(0, tb_Rengine);
    end

    // Test control
    initial begin
        // Initialize all signals
        Tq = 0;
        rst = 0;
        RXBUS = 1;          // Bus idle (Recessive)
        TXVALUE = 1;        // Default: not transmitting
        STATE = 2'b00;      // IDLE
        TPROP = 4'd2;       // Prop_Seg = 2 TQ
        TSEG1 = 4'd3;       // Phase_Seg1 = 3 TQ
        TSEG2 = 4'd3;       // Phase_Seg2 = 3 TQ
        
        // Wait for reset deassertion
        #20 rst = 1;
        #10;
        
        // -----------------------------------------------------------------
        // TEST CASE 1: IDLE state, no 1->0 edge (bus stays idle)
        // -----------------------------------------------------------------
        $display("\n=== TEST CASE 1: IDLE, No Edge ===");
        STATE = 2'b00;      // IDLE
        RXBUS = 1;          // Bus stays Recessive
        TXVALUE = 1;
        #100;               // Run for 10 bit times
        
        // -----------------------------------------------------------------
        // TEST CASE 2: IDLE state, Hard Sync on SOF (1->0 edge)
        // -----------------------------------------------------------------
        $display("\n=== TEST CASE 2: IDLE, Hard Sync (SOF detected) ===");
        STATE = 2'b00;      // IDLE
        RXBUS = 1;          // Start Recessive
        #20;                // Wait 2 Tq
        RXBUS = 0;          // 1->0 edge (SOF)
        TXVALUE = 0;        // Transmitter starts sending SOF (Dominant) - CORRECT
        #100;               // Run for 5 bit times
        RXBUS = 1;          // Bus goes back to Recessive
        #50;
        
        // -----------------------------------------------------------------
        // TEST CASE 3: NOT IDLE, Hard Sync on SOF (should NOT happen)
        // -----------------------------------------------------------------
        $display("\n=== TEST CASE 3: NOT IDLE, Edge arrives (should be ignored for Hard Sync) ===");
        STATE = 2'b01;      // Some other state (e.g., SOF or ARB)
        RXBUS = 1;          // Start Recessive
        #20;
        RXBUS = 0;          // 1->0 edge arrives during a frame
        TXVALUE = 0;        // Node is transmitting Dominant
        #100;               // Run for a while
        RXBUS = 1;
        #50;
        
        // -----------------------------------------------------------------
        // TEST CASE 4: Resync in Phase1 (Positive Phase Error, TXVALUE=1)
        // -----------------------------------------------------------------
        $display("\n=== TEST CASE 4: Resync in Phase1 (Positive Phase Error, TXVALUE=1) ===");
        STATE = 2'b01;      // Not IDLE
        TXVALUE = 1;        // <-- FIXED: Transmitting Recessive (resync allowed)
        RXBUS = 1;          // Bus is Recessive
        
        // Reset the engine to get a clean state
        #10 rst = 0;
        #20 rst = 1;
        #50;
        
        // Start a Hard Sync first to set known counters
        RXBUS = 1;
        #20;
        RXBUS = 0;          // SOF edge -> Hard Sync
        TXVALUE = 0;        // Transmitting Dominant during SOF (but this is fine)
        
        // After Hard Sync, we are in a frame. Switch to Recessive TX.
        #100;               // Wait until we are in the middle of a bit
        TXVALUE = 1;        // <-- FIXED: Now transmitting Recessive (resync allowed)
        
        // Force an early 1->0 edge (positive phase error)
        #30;                // Wait 3 Tq after bit start (while CNT1 > 0)
        RXBUS = 0;          // 1->0 edge arrives early (TXVALUE=1, so resync should happen)
        #100;               // Run to see the phase adjustment (CNT1 lengthened)
        RXBUS = 1;
        #50;
        
        // -----------------------------------------------------------------
        // TEST CASE 5: Resync in Phase2 (Negative Phase Error, TXVALUE=1)
        // -----------------------------------------------------------------
        $display("\n=== TEST CASE 5: Resync in Phase2 (Negative Phase Error, TXVALUE=1) ===");
        // Reset engine to clean state
        rst = 0;
        #20 rst = 1;
        #50;
        
        // Start with Hard Sync
        RXBUS = 1;
        #20;
        RXBUS = 0;          // SOF edge
        TXVALUE = 0;
        #100;               // Let a few bits pass
        
        TXVALUE = 1;        // <-- FIXED: Transmitting Recessive (resync allowed)
        
        // Force a late 1->0 edge (after sample point, when CNT1==0, CNT2>0)
        #30;                // Wait until after sample point
        RXBUS = 0;          // 1->0 edge arrives late (TXVALUE=1, so resync should happen)
        #100;               // Run to see phase adjustment (CNT2 shortened)
        RXBUS = 1;
        #50;
        
        // -----------------------------------------------------------------
        // TEST CASE 6: TXVALUE=0 with Positive Phase Error (should be ignored)
        // -----------------------------------------------------------------
        $display("\n=== TEST CASE 6: TXVALUE=0, Positive Phase Error (resync ignored) ===");
        rst = 0;
        #20 rst = 1;
        #50;
        
        RXBUS = 1;
        #20;
        RXBUS = 0;          // SOF edge
        TXVALUE = 0;        // Transmitting Dominant (this is correct for this test)
        #100;
        
        // Force early 1->0 edge
        #30;                // Early edge
        RXBUS = 0;          // 1->0 edge arrives early, but TXVALUE=0 so resync should be IGNORED
        #100;               // No phase adjustment should occur
        RXBUS = 1;
        #50;
        
        // -----------------------------------------------------------------
        // TEST CASE 7: Varying TPROP and TSEG values
        // -----------------------------------------------------------------
        $display("\n=== TEST CASE 7: Varying Timing Parameters ===");
        rst = 0;
        #20 rst = 1;
        #50;
        
        // Case 7a: Small values
        TPROP = 4'd1;
        TSEG1 = 4'd1;
        TSEG2 = 4'd1;
        $display("--- Testing TPROP=1, TSEG1=1, TSEG2=1 ---");
        RXBUS = 1;
        #20;
        RXBUS = 0;          // SOF edge
        TXVALUE = 1;
        #100;
        RXBUS = 1;
        #50;
        
        // Case 7b: Large values
        TPROP = 4'd8;
        TSEG1 = 4'd8;
        TSEG2 = 4'd8;
        $display("--- Testing TPROP=8, TSEG1=8, TSEG2=8 ---");
        RXBUS = 1;
        #20;
        RXBUS = 0;          // SOF edge
        TXVALUE = 1;
        #200;               // Longer run time for larger bit time
        RXBUS = 1;
        #50;
        
        // -----------------------------------------------------------------
        // TEST CASE 8: IDLE with 1->0->1 glitch (should be ignored)
        // -----------------------------------------------------------------
        $display("\n=== TEST CASE 8: IDLE, Glitch (1->0->1) should be ignored ===");
        STATE = 2'b00;      // IDLE
        RXBUS = 1;          // Start Recessive
        TXVALUE = 1;
        #20;
        RXBUS = 0;          // 1->0 edge (this should start Hard Sync)
        #10;                // Short glitch
        RXBUS = 1;          // 0->1 edge (should not trigger anything)
        #50;                // Wait for a bit
        RXBUS = 0;          // Second 1->0 edge (valid SOF)
        #50;
        
        // -----------------------------------------------------------------
        // TEST CASE 9: Continuous bit stream (realistic scenario)
        // -----------------------------------------------------------------
        $display("\n=== TEST CASE 9: Continuous Bit Stream ===");
        STATE = 2'b01;      // Not IDLE
        TPROP = 4'd2;
        TSEG1 = 4'd3;
        TSEG2 = 4'd3;
        TXVALUE = 0;        // Transmitting Dominant (SOF)
        RXBUS = 1;
        #20;
        RXBUS = 0;          // SOF
        #40;
        RXBUS = 1;          // Bit 1: Recessive
        #40;
        RXBUS = 0;          // Bit 2: Dominant
        #40;
        RXBUS = 1;          // Bit 3: Recessive
        #40;
        RXBUS = 1;          // Bit 4: Recessive (no edge)
        #40;
        RXBUS = 0;          // Bit 5: Dominant (edge occurs in Phase1 or Phase2)
        #80;
        RXBUS = 1;          // Bit 6: Recessive
        
        // -----------------------------------------------------------------
        // End of simulation
        // -----------------------------------------------------------------
        #100;
        $display("\n=== Simulation Complete ===");
        $finish;
    end

    // Monitor key signals
    initial begin
        $monitor("Time=%t, CNT1=%d, CNT2=%d, RXOUT=%b, TXen=%b, STATE=%d, RXBUS=%b, TXVALUE=%b",
                 $time, CNT1, CNT2, RXOUT, TXen, STATE, RXBUS, TXVALUE);
    end

endmodule