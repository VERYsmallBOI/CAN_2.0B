//changes btw states bit stufffing application
//change RXSTATES bits and PARAMETER EQUIVALENTS
//TX writing logic pending done
//CRC logic pending conecction done
//error logic requesting pending and if given by handler handling is pending
//overload override pending
module TXMachine(rst, srst, Tq, Sampled_din, Transmit, RXSTATES, TXen, ID, IDE, RTR, data, D_Len, Ready, REC, TEC, ErrState, TX, req_Error);
    // Clocks & Resets
    input        rst;
    input        srst;
    input        Tq;
    input        Sampled_din; //will be used for ACK and bit error get from RXMachine

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
    output   Ready;       // Indicates controller is idle/ready
    output reg   TX;          // Serial transmit line
    wire         pause_to_crc;
    output reg      req_Error;

    // Parameters
    //Interframe(+suspend) remote data all-transmit-time-error(just bit error and ACK eror)(there is a diff cos of TEC and REC)
    localparam IDLE         = 4'd0,
            SOF          = 4'd1,
            ARB          = 4'd2,
            CTRL         = 4'd3,
            DATA         = 4'd4,
            CRC_SEQ      = 4'd5,
            CRC_DL       = 4'd6,
            ACKSL        = 4'd7,
            ACK_DL       = 4'd8,
            EOF          = 4'd9,
            INTERMISSION = 4'd10,
            SUSPEND      = 4'd11,
            ERROR        = 4'd12;

    localparam RXIDLE = 0,
            RXINTERMISSION3=13;

    // Internal Registers
    reg [3:0]  TXSTATES,TXSTATESr;   // FSM state register (12 states)
    reg [5:0] Cnt, Cntr;

    // Internal Wires / Registers
    wire       pause_from_bs;

    reg        pause_to_bs; //goes to BS
    reg        bfrTX;
    wire       BSTX;
    wire [14:0] out_CRC;

    assign pause_to_crc = pause_to_bs | pause_from_bs | (TXSTATES == CRC_SEQ); //bitstuffer pause states + CRC_SEQ

    // Pause Logic
    always @(*) begin
        //the below means 6(CRC_DL) to 11(SUSPEND) and IDLE and overall TXen not on
        if (!TXen || (TXSTATES > IDLE && TXSTATES < CRC_DL)) begin
            pause_to_bs = 1;
        end
        else begin
            pause_to_bs = 0;
        end
    end

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
        end
        else begin   
            if (!srst) begin
                TXSTATES <= IDLE;
                Cnt      <= 0;
            end
            else begin
                if (TXen) begin
                    TXSTATES <= (ErrState|req_Error)?ERROR:TXSTATESr;
                    Cnt      <= Cntr;
                end
            end
        end
    end

    // Next State Logic
    always @(*) begin //have to add pause logic from BS (but not crc )
        if ((TXSTATES == IDLE) && (RXSTATES == RXIDLE||RXSTATES ==RXINTERMISSION3)) begin
            if (Transmit == 1) begin
                TXSTATESr = SOF;
                Cntr      = 0;
            end
            else begin 
                TXSTATESr = IDLE;
                Cntr      = 0;
            end
        end
        else begin //path for error pending 
            if (TXSTATES != IDLE) begin
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
                                    Cntr      = (Cnt!=0)?Cnt - 1:5;
                                    TXSTATESr = (Cnt!=0)?TXSTATES:CTRL;
                                end
                                else begin //lost
                                    Cntr      = 0;
                                    TXSTATESr = IDLE;
                                end
                            end
                        

                        CTRL: begin
                            if (Cnt!=0) begin
                                Cntr      = Cnt - 1;
                                TXSTATESr = TXSTATES;
                            end
                            else begin
                                if(RTR)begin
                                    Cntr=14;
                                    TXSTATESr=CRC_SEQ;
                                end
                                else begin
                                    if(D_Len==0)
                                    begin
                                        Cntr=14;
                                        TXSTATESr=CRC_SEQ;
                                    end
                                    else begin
                                         Cntr=(D_Len*8)-1;
                                         TXSTATESr=DATA;
                                    end
                                end 
                            end
                        end


                        DATA: begin
                            if (Cnt!=0) begin
                                Cntr      = Cnt - 1;
                                TXSTATESr = TXSTATES;
                            end
                            else begin
                                Cntr      = 14;
                                TXSTATESr = CRC_SEQ;
                            end
                        end

                        CRC_SEQ: begin
                            if (Cnt!=0) begin
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
                            if (Cnt!=0) begin
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
                                    if(Cnt==0)begin
                                        if(TEC>127 || REC>127 )begin
                                        TXSTATESr=SUSPEND;//8 R
                                        Cntr=7;
                                        end
                                        else begin
                                            TXSTATESr=(Transmit &&(RXSTATES == RXIDLE||RXSTATES ==RXINTERMISSION3) )?SOF:IDLE;
                                            Cntr=0;
                                        end
                                    end
                                    else begin
                                        TXSTATESr=INTERMISSION;
                                        Cntr=Cnt-1;
                                    end
                                end
                                else begin//Someother thing(overload error someother node took over) happened
                                    Cntr      = 0;
                                    TXSTATESr = IDLE;
                                end
                            end

                        SUSPEND: begin
                                if (Sampled_din == TX) begin //also do it for others to give out bit error
                                    Cntr      = (Cnt!=0)?Cnt - 1:0;
                                    TXSTATESr = (Cnt!=0)?TXSTATES:(Transmit && (RXSTATES == RXIDLE||RXSTATES ==RXINTERMISSION3))?SOF:IDLE;
                                end
                                else begin //lost
                                    Cntr      = 0;
                                    TXSTATESr = IDLE;
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



    // TX bit generation (combinational)
    always @(*) begin
        if (TXSTATES == SOF) begin
            bfrTX = 0;
        end
        else if (TXSTATES == ARB) begin
            
                if (Cnt > 5'd20)
                    bfrTX = ID[5'(Cnt - 3)]; //31-21 to 28-18 first 11 bits
                else if (Cnt == 5'd20)
                    bfrTX = 1; //SRR
                else if (Cnt == 19)
                    bfrTX = IDE;
                else if (Cnt != 0)
                    bfrTX = ID[5'(Cnt - 1)]; //last bits 18 
                else
                    bfrTX = RTR;
            
        end
        else if (TXSTATES == CTRL) begin
            if (Cnt == 5 || Cnt == 4)
                bfrTX = 0;
            else
                bfrTX = D_Len[2'(Cnt)];
        end
        else if (TXSTATES == DATA) begin
            bfrTX = data[Cnt];
        end
        else if (TXSTATES == CRC_SEQ) begin
            bfrTX = out_CRC[4'(Cnt)];
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
        if(TXSTATES<=EOF && TXSTATES!=IDLE)begin //should be active on all the frame bits 
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
assign Ready=(TXSTATES==IDLE);
endmodule