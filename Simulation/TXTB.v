`timescale 1ns / 1ns

module tb_TXMachine;

    // Parameters
    localparam CLK_PERIOD = 10; // 10 ns clock period

    // Inputs
    reg         rst;
    reg         srst;
    reg         Tq;
    wire        Sampled_din;   // now a wire, continuously assigned
    reg         Transmit;
    reg  [3:0]  RXSTATES;
    reg         TXen;
    reg  [28:0] ID;
    reg         IDE;
    reg         RTR;
    reg  [63:0] data;
    reg  [3:0]  D_Len;
    reg  [7:0]  REC;
    reg  [7:0]  TEC;
    reg         ErrState;

    // Outputs
    wire        Ready;
    wire        TX;
    wire        req_Error;

    // Instantiate the DUT
    TXMachine dut (
        .rst(rst),
        .srst(srst),
        .Tq(Tq),
        .Sampled_din(Sampled_din),
        .Transmit(Transmit),
        .RXSTATES(RXSTATES),
        .TXen(TXen),
        .ID(ID),
        .IDE(IDE),
        .RTR(RTR),
        .data(data),
        .D_Len(D_Len),
        .Ready(Ready),
        .REC(REC),
        .TEC(TEC),
        .ErrState(ErrState),
        .TX(TX),
        .req_Error(req_Error)
    );

    // Clock generation
    always # (CLK_PERIOD/2) Tq = ~Tq;

    // Sampled_din follows TX (no bit errors) -> continuous assignment
    assign Sampled_din = TX;

    // Stimulus
    initial begin
        // Initialize inputs
        rst = 0;
        srst = 0;       // active low, start with reset asserted
        Tq = 0;
        Transmit = 0;
        RXSTATES = 4'd10; // INTERMISSION (initial value)
        TXen = 0;
        ID = 29'b10101010101111111010101010101; // alternating 1/0 starting with 1
        IDE = 1;
        RTR = 0;
        // ASCII "FUCKOFF!" -> bytes: 46 55 43 4B 4F 46 46 21
        data = 64'h4655434B4F464621;
        D_Len = 4'd8;   // 8 bytes
        REC = 8'd150;
        TEC = 8'd0;
        ErrState = 1'b0;

        // Apply reset
        # (CLK_PERIOD * 2);
        rst = 1;
        # (CLK_PERIOD * 2);
        srst = 1;       // release synchronous reset

        // Enable TXen (stay high for the whole transmission)


        // Wait for 2 TXen cycles (i.e., 2 rising edges of Tq) with RXSTATES=10
        repeat (2) @(posedge Tq);
        // Now change RXSTATES to IDLE
        RXSTATES = 4'd0; // IDLE

        // Wait one more cycle, then assert Transmit to start frame
        @(posedge Tq);
        Transmit = 1;

        // Keep Transmit high until Ready goes high, then deassert after a few cycles
        # (CLK_PERIOD * 5);
        Transmit = 0;

        // Wait a bit more then finish simulation
        # (CLK_PERIOD * 280);
        $finish;
    end

    // Optional: Monitor state and signals for debugging
    always @(posedge Tq) begin
        $display("Time=%t, TXSTATES=%d, Cnt=%d, TX=%b, Ready=%b, req_Error=%b",
                 $time, dut.TXSTATES, dut.Cnt, TX, Ready, req_Error);
    end
            always@(posedge Tq)
        begin
            TXen = ~TXen;
        end

endmodule