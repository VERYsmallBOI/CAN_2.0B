//code for all errors except ack and biterror
//all overload frames
//gets TEC from TXMachine and Sends REC to it
//pad and check for intermission bfr going to idle
//IMPORTANT:Frames in the Extended Format include the DATA LENGTH CODE and two reserved bits r1 and r0. 
//The reserved bits have to be sent ’dominant’, but receivers accept ’dominant’ and ’recessive’ bits in all combinations

//pending ack giver for correct frames
//edge condition chdck if CRC and BS operate at their pause edges correctly
//just use shift register here itslef as BS
//current problem:-> Sampling at Rengine can be usign stale value when copamreed here
//Bus overtake shoudl work on TXen
// sampling(dont register it-breaks timing)/state transisition shoudl work on RXen

module RXMachine(Tq, rst, srst, TOFILTERd, TOFILTERI, RXBUS, D_Len, req_Error, IDE, AckTakeOver, RXen, TXen, RTR, ErrState, OvlState, RXSTATES, done, imTX);
input Tq,rst,RXBUS,srst,RXen,TXen,imTX;
output reg [63:0]TOFILTERd;//to data filetered
output reg [28:0]TOFILTERI;//to id filter
output reg req_Error;
wire pause_to_crc;
input ErrState;//from error handler 
input OvlState;//from overlaoad handler
output reg AckTakeOver;//let acktakeover be a identification for a finished transmission
output reg [3:0]RXSTATES;
reg [3:0]RXSTATESr;
//reg 
reg [5:0] Cnt,Cntr;
reg sample;
wire bitisbs,allequal,usebs;
output reg done;
reg req_Errorr;
localparam  IDLE           = 4'd0,
            SOF            = 4'd1,
            ARB            = 4'd2,
            CTRL           = 4'd3,
            DATA           = 4'd4,
            CRC_SEQ        = 4'd5,
            CRC_DL         = 4'd6,
            ACKSL          = 4'd7,
            ACK_DL         = 4'd8,
            EOF            = 4'd9,
            INTERMISSION12 = 4'd10,
            INTERMISSION3  = 4'd11,
            OVERLOAD       = 4'd12,
            ERROR          = 4'd13;//No need for SUSPEND
wire [14:0]out_CRC; 
output reg RTR;//filled by Bit evaluator
output reg IDE;//filled by bit evaluator
output reg [3:0]D_Len;
wire srst_crc;
reg [5:0]bs;
assign pause_to_crc=(bitisbs)||(~RXen)||(~usebs);
always@(posedge Tq,negedge rst)begin
    if(!rst)begin
    RXSTATES<=IDLE;
    Cnt<=0;
    end
    else if(!srst)begin
        RXSTATES<=IDLE;
        Cnt<=0;
    end
    else begin
        if(RXen)begin
        RXSTATES<=(req_Error||ErrState)?ERROR:(OvlState?OVERLOAD:RXSTATESr);
        Cnt<=Cntr;
        end
    end
end
always @(posedge Tq or negedge rst) begin
    if (!rst) begin
        // Reset conditions
        AckTakeOver<=1;
    end
    else if (!srst) begin
        // Synchronous reset conditions
        AckTakeOver<=1;
    end
    else begin
        if (TXen) begin
            // RX enabled conditions
            if(RXSTATES==ACKSL)begin//RX will be 1 state behind
                AckTakeOver<=(req_Error)||(imTX);
            end
            else AckTakeOver<=1;
        end
    end
end

always@(posedge Tq or negedge rst)begin
if(!rst)begin
    done<=0;
end
else if(!srst)begin
done<=0;
end
else if((~req_Errorr)&&(RXSTATES==EOF)&&(Cnt==0)&&(~imTX))
    done<=1;
    else if(RXSTATES>=SOF && RXSTATES<=ACKSL) begin
        done<=0;
    end
    else done<=done;

end


always@(*)begin //naturally the sampling will become based on RXen cos capture is based on it
    //if() check if there is an overriding condition present
    if(bitisbs)begin
        RXSTATESr=RXSTATES;
        Cntr=Cnt;
    end
    else begin
    case (RXSTATES)
    IDLE:begin
        Cntr=0;
        if(RXBUS==0)
            RXSTATESr=SOF;
    else RXSTATESr=IDLE;
    end

    SOF: begin
        Cntr=31;
        RXSTATESr=ARB;
    end

    ARB: begin
        if(Cnt!=0)begin
        if(Cnt==20 && RXBUS==0)begin// wil check for IDE directly 1->SRR 0-> RTR so checks 12th bit unsampled bfr going now its neccesary i take action at same bit
                Cntr=5;
                RXSTATESr=CTRL;
            end
            else begin
                Cntr=Cnt-1;
                RXSTATESr=ARB;
            end
        end
        
        else begin
            RXSTATESr=CTRL;
            Cntr=5;
        end
    end

    CTRL: begin
        if(Cnt==0)begin
            Cntr=(RTR||(D_Len==0))?14:(({D_Len[2:0],RXBUS}<<3) -1);
            RXSTATESr=(RTR||(D_Len==0))?CRC_SEQ:DATA;
        end
        else begin
            Cntr=Cnt-1;
            RXSTATESr=RXSTATES;
        end
    end 

    DATA: begin
        if(Cnt!=0)begin
            Cntr=Cnt-1;
            RXSTATESr=RXSTATES;
        end
        else begin
            Cntr=14;
            RXSTATESr=CRC_SEQ;
        end
    end

    CRC_SEQ: begin
        if(Cnt!=0)begin
            Cntr=Cnt-1;
            RXSTATESr=RXSTATES;
        end
        else begin
            Cntr=0;
            RXSTATESr=CRC_DL;
        end
    end

    CRC_DL: begin
        Cntr=0;
        RXSTATESr=ACKSL;
        
    end

    ACKSL: begin
        Cntr=0;
        RXSTATESr=ACK_DL;
    end

    ACK_DL: begin
        Cntr=6;
        RXSTATESr=EOF;
    end

    EOF: begin
        if(Cnt!=0)begin
            Cntr=Cnt-1;
            RXSTATESr=RXSTATES;
        end
        else begin
            Cntr=1;
            RXSTATESr=INTERMISSION12;
        end
    end

    INTERMISSION12: begin
        if(Cnt!=0)begin
            Cntr=Cnt-1;
            RXSTATESr=RXSTATES;
        end
        else begin
            Cntr=0;
            RXSTATESr=INTERMISSION3;
        end
    end
    INTERMISSION3: begin
        Cntr=0;
        RXSTATESr=(RXBUS==0)?SOF:IDLE;
    end

    OVERLOAD: begin
        if(OvlState)begin
            RXSTATESr=OVERLOAD;
            Cntr=0;
        end
        else begin
            RXSTATESr=INTERMISSION12;
            Cntr=1;
        end
    end
    ERROR: begin
        if (ErrState) begin//can have a problem check once
            RXSTATESr = ERROR;
            Cntr      = 0;
        end
        else begin
            RXSTATESr = INTERMISSION12;
            Cntr      = 1;
        end

    end

    default: begin
        RXSTATESr=IDLE;
        Cntr=0;
    end
endcase
    end
end
//CRC
    CRC rxcrc(
        .NXTBIT(RXBUS),//current value is needed to be decoded ig
        .srst(srst_crc),
        .clk(Tq),
        .rst(rst),
        .CRC_RG(out_CRC),
        .Pause(pause_to_crc));


assign srst_crc=srst&&(RXSTATES != IDLE) && (RXSTATES != INTERMISSION3) && (RXSTATES!=EOF);//rst it to 0 for when it is out of the frame bs parts

//BIT STUFFER
//dont have to pause (remember from Bitstuffer edge case)
//BS here will steam every value but considers at SOF to CRC_SEQ 
//as IDLE/OVerload dl/error dl/intermission has to be 1 and sof will break it
always@(posedge Tq or negedge rst)begin
if(!rst)begin
bs<=6'b00001;
end
else begin
    if(RXen)
    begin
        if((SOF<=RXSTATES)&&(RXSTATES<=CRC_SEQ))begin
        bs<={bs[4:0],RXBUS};
        end else if((RXSTATES == IDLE || RXSTATES == INTERMISSION3) && RXBUS == 0)//the if is supposed to account for the 0 change ig so change here
        begin
            bs<=6'b000010;
        end
        else bs<=6'b00001; 
    end
    else bs<=bs;
end
end

always@(posedge Tq or negedge rst)begin
if(!rst)begin
sample<=1'b1;
end
else begin
    if(RXen)
    begin
        sample<=RXBUS;
    end
    else sample<=sample;//will have one Bit time old value at eval so useless for 
end
end




assign usebs=(SOF<=RXSTATES)&&(RXSTATES<=CRC_SEQ);//same as CRC
assign allequal=&(bs[4:0]) || ~(|(bs[4:0]));//last five
//use the below when above is correct
assign bitisbs=usebs&allequal;



//bit stuffing ack form 
//error checks
//intentionally diff from transmitter for accomodating the fact that it happens later(error gen)
always@(*)begin//sampling is fine here cos RX can push timing here alone as ERROR handler will catch at next TX 
//but nowhere it should be done.
    if(IDLE!=RXSTATES&& RXSTATES<CRC_DL && (&(bs) || ~(|(bs))))
        req_Errorr=1;
    else if(RXSTATES==ACK_DL && (out_CRC!=0))//even if CRC_SEQ is not finished by bitstuffer interjecting the pause logic will work here
        req_Errorr=1;
    else if(RXSTATES==EOF && Cnt!=0 && RXBUS==0)
        req_Errorr=1;
    else if((RXSTATES==ACK_DL || RXSTATES==CRC_DL) && RXBUS==0)//except ACKSL //form error
        req_Errorr=1;
   else 
      req_Errorr=0;
end
always@(posedge Tq or negedge rst)begin
if(!rst)begin
    req_Error<=0;
end
else 
if(!srst)begin
    req_Error<=0;
end
else if(RXen)begin
 if(RXSTATES==IDLE || RXSTATES==SOF || RXSTATES==ERROR)begin
    req_Error<=0;
end
else req_Error<=req_Error||req_Errorr;
end
end
//at intermission is overload

// when using sampled values use whole thing sampled to avoid timing mismatch
always @(posedge Tq or negedge rst) begin//check for bs 
    if (!rst) begin
        TOFILTERd <= 0;
        TOFILTERI <= 0;
        RTR       <= 1; // cant actually say what is it with frame structure
        IDE       <= 0; // default is 0 and if 1 will get overwrtiten at 19 else will be 0
        D_Len     <= 0;
    end
    else if (!srst) begin
        TOFILTERd <= 0;
        TOFILTERI <= 0;
        RTR       <= 1;
        IDE       <= 0;
        D_Len     <= 0;
    end
    else begin
        if (RXen && ~bitisbs) begin//not stuffed and at RXen
            if (RXSTATES == DATA) begin
                TOFILTERd <= {TOFILTERd[62:0], RXBUS}; // sample will give prevoius value as (think sof whihc is slower actually)
            end
            else if (RXSTATES == ARB) begin
               if (Cnt == 20 || Cnt == 0) begin
                    RTR <= RXBUS;
                end
                else if (Cnt == 19) begin
                    IDE <= RXBUS;
                end
                else begin
                    TOFILTERI <= {TOFILTERI[27:0], RXBUS};//values at that point(State and CNt) will have that corresponding value in RXBUS
                end
            end
            else if (RXSTATES == CTRL) begin
                if(Cnt[2:0]!=4'd5 && Cnt[2:0]!=4'd4)
                    D_Len <= {D_Len[2:0],RXBUS};
            end
            else if(RXSTATES == IDLE || RXSTATES == SOF)begin
                        TOFILTERd <= 0;
                        TOFILTERI <= 0;
                        RTR       <= 1;
                        IDE       <= 0;
                        D_Len     <= 0;
            end
        end
    end
end


endmodule