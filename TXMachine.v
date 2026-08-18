//changes btw states bit stufffing application
//change RXSTATES bits and PARAMETER EQUIVALENTS
//TX writing logic pending done
//CRC logic pending conecction done
//error logic requesting pending and if given by handler handling is pending

module TXMachine(rst, srst, Tq, Sampled_din, Transmit, RXSTATES, TXen, ID, IDE, RTR, data, D_Len, REC, TEC, ErrState, Ready, TX, req_Error);
    // Clocks & Resets
    input        rst;
    input        srst;
    input        Tq;
    input        Sampled_din; //will be used for ACK and bit error

    // Control & State Inputs
    input        Transmit;    // Master request for data transmission
    input  [3:0] RXSTATES;     // Receiver state (e.g., IDLE)
    input        TXen;        //from Rengine for control to work

    // Data & Frame Inputs
    input  [28:0] ID;         // Identifier (MSB filled) 
    input        IDE;         // Identifier Extension bit
    input        RTR;         // Remote Transmission Request
    input  [63:0] data;       // Data payload
    input  [3:0] D_Len;       //0 to 8

    // Error Counter Inputs/Outputs
    input wire [7:0] REC;     // Receive Error Counter (0 to 255)
    input wire [7:0] TEC;     // Transmit Error Counter
    input        ErrState;    //from errorhandler

    // Module Outputs
    output reg   Ready;       // Indicates controller is idle/ready
    output reg   TX;          // Serial transmit line
    wire         pause_to_crc;
    output reg      req_Error;

    // Parameters
    //Interframe(+suspend) remote data all-transmit-time-error(just bit error and ACK eror)(there is a diff cos of TEC and REC)
    parameter IDLE         = 0,
              SOF          = 1,
              ARB          = 2,
              CTRL         = 3,
              DATA         = 4,
              CRC_SEQ      = 5,
              CRC_DL       = 6,
              ACKSL        = 7,
              ACK_DL       = 8,
              EOF          = 9,
              INTERMISSION = 10,
              SUSPEND      = 11,
              ERROR        = 12;

    parameter RXIDLE = 0; //NEDED to change after writing RXMachine

    // Internal Registers
    reg [3:0]  TXSTATES,TXSTATESr;   // FSM state register (12 states)
    reg [63:0] Cnt, Cntr;

    // Internal Wires / Registers
    wire       pause_from_bs;

    reg        pause_to_bs; //goes to BS
    reg        Readyr;
    reg        bfrTX;
    wire       BSTX;
    wire [14:0] out_CRC;

    assign pause_to_crc = pause_to_bs & pause_from_bs & (TXSTATES == 5); //bitstuffer pause states + CRC_SEQ

    // Submodule
    bitstuffer TransBS(
        .din(bfrTX),
        .clk(Tq),
        .rst(rst),
        .srst(srst),
        .bitout(BSTX),
        .pause_out(pause_from_bs),
        .pause_in(pause_to_bs)
    );

    //when bit stuffer stops CRC should also stop when bit stuffing happens too.
    CRC txcrc(
        .NXTBIT(bfrTX),
        .srst(srst),
        .clk(Tq),
        .rst(rst),
        .CRC_RG(out_CRC),
        .Pause(pause_to_crc)
    );

    // State / Register Update Logic
    always @(posedge Tq or negedge rst) begin
        if (!rst) begin
            TXSTATES <= IDLE;
            Cnt      <= 0;
            Ready    <= 1;
        end
        else begin   
            if (!srst) begin
                TXSTATES <= IDLE;
                Cnt      <= 0;
                Ready    <= 1;
            end
            else begin
                if (TXen) begin
                    TXSTATES <= (ErrState|req_Error)?ERROR:TXSTATESr;
                    Cnt      <= Cntr;
                    Ready    <= Readyr;
                end
            end
        end
    end

    // Next State Logic
    always @(*) begin //have to add pause logic from BS (but not crc )
        if (TXSTATES == IDLE && RXSTATES == RXIDLE) begin
            if (Transmit == 1) begin
                TXSTATESr = SOF;
                Cntr      = 0;
                Readyr    = 0;
            end
            else begin 
                TXSTATESr = IDLE;
                Cntr      = 0;
                Readyr    = 1;
            end
        end
        else begin //path for error pending 
            if (TXSTATES != IDLE) begin
                Readyr = 0;
                if (pause_from_bs && ~pause_to_bs) begin //only consider pause from bs at to_pause 1
                    //stay at current cnt and state
                    Cntr      = Cnt;
                    TXSTATESr = TXSTATES;
                end
                else begin
                    case (TXSTATES)
                        SOF: begin
                            TXSTATESr = ARB;
                            Cntr      = IDE ? 31 : 11;
                        end

                        ARB: 
                            begin
                                if (Sampled_din == TX) begin //also do it for others to give out bit error
                                    Cntr      = Cnt?Cnt - 1:5;
                                    TXSTATESr = Cnt?TXSTATES:CTRL;
                                end
                                else begin //lost
                                    Cntr      = 0;
                                    TXSTATESr = IDLE;
                                    Readyr    = 1;
                                end
                            end
                        

                        CTRL: begin
                            if (Cnt) begin
                                Cntr      = Cnt - 1;
                                TXSTATESr = TXSTATES;
                            end
                            else begin
                                Cntr      = RTR ? 14 : (D_Len * 8) - 1; //*8 is for bytes to bits
                                TXSTATESr = RTR ? CRC_SEQ : DATA;
                            end
                        end

                        DATA: begin
                            if (Cnt) begin
                                Cntr      = Cnt - 1;
                                TXSTATESr = TXSTATES;
                            end
                            else begin
                                Cntr      = 14;
                                TXSTATESr = CRC_SEQ;
                            end
                        end

                        CRC_SEQ: begin
                            if (Cnt) begin
                                Cntr      = Cnt - 1;
                                TXSTATESr = TXSTATES;
                            end
                            else begin
                                Cntr      = 0;
                                TXSTATESr = CRC_DL;
                            end
                        end

                        CRC_DL: begin
                            Cntr      = 0;
                            TXSTATESr = ACKSL;
                        end

                        ACKSL: begin
                            Cntr      = 0;
                            TXSTATESr = ACK_DL;
                        end

                        ACK_DL: begin //7 R bits
                            Cntr      = 6;
                            TXSTATESr = EOF;
                        end

                        EOF: begin
                            if (Cnt) begin
                                Cntr      = Cnt - 1;
                                TXSTATESr = TXSTATES;
                            end
                            else begin
                                Cntr      = 2;
                                TXSTATESr = INTERMISSION;
                            end
                        end

                        INTERMISSION: 
                        begin
                                if (Sampled_din == TX) begin //also do it for others to give out bit error
                                    Cntr      = Cnt?Cnt - 1:7;
                                    TXSTATESr = Cnt?TXSTATES:SUSPEND;
                                end
                                else begin //lost
                                    Cntr      = 0;
                                    TXSTATESr = IDLE;
                                    Readyr    = 1;
                                end
                            end

                        SUSPEND: begin
                                if (Sampled_din == TX) begin //also do it for others to give out bit error
                                    Cntr      = Cnt?Cnt - 1:0;
                                    TXSTATESr = Cnt?TXSTATES:IDLE;
                                end
                                else begin //lost
                                    Cntr      = 0;
                                    TXSTATESr = IDLE;
                                    Readyr    = 1;
                                end
                            end

                        ERROR: begin
                            if (ErrState) begin
                                TXSTATESr = ERROR;
                                Cntr      = 0;
                            end
                            else begin
                                TXSTATESr = INTERMISSION;
                                Cntr      = 2;
                            end
                        end

                        default: begin
                            TXSTATESr = IDLE;
                            Cntr      = 0;
                        end
                    endcase
                end
            end
            else begin //for RXSTATES!=IDLE but TXSTATES is IDLE so others are sending
                TXSTATESr = IDLE;
                Cntr      = 0;
            end
        end
    end

    // Pause Logic
    always @(*) begin
        //the below means 6(CRC_DL) to 11(SUSPEND) and IDLE and overall TXen not on
        if (!TXen || (TXSTATES[3] || (TXSTATES[2] && TXSTATES[1]) || ~|TXSTATES)) begin
            pause_to_bs = 1;
        end
        else begin
            pause_to_bs = 0;
        end
    end

    // TX bit generation (combinational)
    always @(*) begin
        if (TXSTATES == SOF) begin
            bfrTX = 0;
        end
        else if (TXSTATES == ARB) begin
            if (IDE) begin
                if (Cnt != 0)
                    bfrTX = ID[Cnt + 17];
                else
                    bfrTX = RTR;
            end
            else begin
                if (Cnt > 20)
                    bfrTX = ID[Cnt - 3]; //31-21 to 28-18 first 11 bits
                else if (Cnt == 20)
                    bfrTX = 1; //SRR
                else if (Cnt == 19)
                    bfrTX = IDE;
                else if (Cnt != 0)
                    bfrTX = ID[Cnt - 1]; //last bits 18 
                else
                    bfrTX = RTR;
            end
        end
        else if (TXSTATES == CTRL) begin
            if (Cnt == 5 || Cnt == 4)
                bfrTX = 0;
            else
                bfrTX = D_Len[Cnt];
        end
        else if (TXSTATES == DATA) begin
            bfrTX = data[Cnt];
        end
        else if (TXSTATES == CRC_SEQ) begin
            bfrTX = out_CRC[Cnt];
        end
        else begin //CRC_DL ACKSL ACK_DL EOF INTERMISSION SUSPEND ERROR(override by handler) IDLE too
            bfrTX = 1;
        end
    end

    // Serial output mux
    always @(*) begin
        if (TXSTATES > CRC_SEQ) begin
            TX = bfrTX;
        end
        else if (IDLE < TXSTATES && TXSTATES < CRC_DL) begin //IDLE<TXSTATES && TXSTATES<CRC_DL
            TX = BSTX;
        end
        else begin
            TX = 1; //IDLE and others
        end
    end

    //ERROR CHECKER
    always @(*) begin
        if(TXSTATES<=EOF || TXSTATES!=IDLE)begin //should be active on all the frame bits 
        if(Sampled_din != TX && TXSTATES!=ARB && TXSTATES!=ACKSL) begin
            req_Error=1;
        end
        else if(Sampled_din==1 && TX==1 && TXSTATES==ACKSL)begin
            req_Error=1;
        end
        else req_Error=0;

    end
    
    else req_Error=0;
    end
    ///if at interframe space bit error prolly others won

endmodule