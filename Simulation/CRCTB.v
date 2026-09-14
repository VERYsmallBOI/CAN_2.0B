module tb_CRC;

    // Testbench signals
    reg         NXTBIT;
    reg         srst;
    reg         clk;
    reg         rst;
    reg         Pause;
    wire [14:0] CRC_RG;

    reg  [102:0] data;   // 103‑bit data stream
    integer      i;

    // Instantiate the CRC module
    CRC uut (
        .NXTBIT (NXTBIT),
        .srst   (srst),
        .clk    (clk),
        .rst    (rst),
        .CRC_RG (CRC_RG),
        .Pause  (Pause)
    );

    // Clock: 10 ns period (50 MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    // Main test procedure
    initial begin
        // 1. Initialise all inputs
        rst    = 0;
        srst   = 0;
        Pause  = 0;
        NXTBIT = 0;

        // 2. Release asynchronous reset (rst is active low)
        #15 rst = 1;

        // 3. Release synchronous reset after one clock edge
        //    (srst is active low; it stays 0 for the first posedge, clearing CRC,
        //     then goes high to enable normal operation)
        @(posedge clk);
        srst = 1;

        // 4. Load the 103‑bit data stream (exactly as given)
        data = {
            1'b0,                                    // "0"
            11'b10101010101,                         // "10101010101"
            2'b11,                                   // "11"
            18'b101010101010101010,                  // "101010101010101010"
            1'b0,                                    // "0"
            6'b001000,                               // "001000"
            8'b01000110,                             // "01000110"
            8'b01010101,                             // "01010101"
            8'b01000011,                             // "01000011"
            8'b01001011,                             // "01001011"
            8'b01011001,                             // "01011001"
            8'b01001111,                             // "01001111"
            8'b01010101,                             // "01010101"
            8'b00100001                              // "00100001"
        };

        // 5. Feed the bits into NXTBIT (MSB first)
        for (i = 102; i >= 0; i = i - 1) begin
           
            $display("i=%d   NXTBIT=%b   CRC_RG=%h",i,NXTBIT,CRC_RG);
            NXTBIT = data[i];
             @(posedge clk);
            // Brief pause test in the middle of the transmission
        
        end


        // 7. Display the result
        $display("========================================");
        $display("Final CRC_RG = 0x%h (binary %b) %d", CRC_RG, CRC_RG,i);
        $display("========================================");
        $finish;
    end



endmodule