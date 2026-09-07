//edge case coding for recovery sequence
//will also handle Overload as mostly same with Error
module ErrorHandler(req_Error_RX,req_Error_TX,TXSTATES,RXSTATES,TXpin,Tq,rst,srst,TEC,REC,TXen,imTX,donefromtx,donefromrx,Sampled_din,ErrState,OvlState);
//give precedence to Transmitter's req cos error while Transmiting is that TEC not rec
input req_Error_TX,req_Error_RX,Tq,rst,srst,TXen,donefromtx,donefromrx,imTX,Sampled_din;
output reg TXpin;
reg TXpinr;
output reg [8:0]TEC,REC;
reg [8:0]TECr,RECr;
input [3:0]TXSTATES,RXSTATES;
output ErrState,OvlState;
reg [3:0]Cnt,Cntr;
reg lastvalue;
reg donefromrxr,donefromtxr;
reg [2:0]State,Stater;
reg [8:0]TECin,TECinr,RECin,RECinr;
localparam  NOERROR= 3'b0,
            DL=3'd3,
            CHECK=3'd2,
            SEND=3'd1,
            RECOVERY=3'd4,
            OVFL=3'd5,
            OVDL=3'd6;
//exception : if lone node coding
reg ack_error,nozero,ack_errorr,nozeror;
localparam TXACKSL=4'd7,INTERMISSION12=4'd10;
//for the unlimieted 0s as flag condition reset to 6
assign ErrState=(State==DL || State==CHECK || State==SEND);
assign OvlState=(State==OVFL||State==OVDL);
reg [6:0]Reck,Reckr;
always @(posedge Tq or negedge rst) begin
    if (!rst) begin
        // Reset conditions
        TXpin<=1;
        lastvalue<=1;
        Cnt<=0;
        REC<=0;
        TEC<=0;//Master reset condition
        donefromrxr<=0;
        State<=NOERROR;
        donefromtxr<=0;
        ack_error<=0;
        nozero<=1;
        TECin<=0;
        RECin<=0;
        Reck<=0;
    end
    else if (!srst) begin
        // Synchronous reset conditions
        TXpin<=1;
        lastvalue<=1;
        REC<=REC;
        TEC<=TEC;
        donefromrxr<=0;
        donefromtxr<=0;
        ack_error<=0;
        nozero<=1;
        RECin<=REC;
        TECin<=TEC;
        State<=0;
    end
    else begin
        if (TXen) begin
            lastvalue<=Sampled_din;
            Cnt<=Cntr;
            State<=(TEC>=256 && State!=RECOVERY)?RECOVERY:Stater;
            TXpin<=TXpinr;
            REC<=(RECOVERY==State && Stater!=NOERROR)?256:RECr;
            TEC<=(RECOVERY==State && Stater!=NOERROR)?256:TECr;
            donefromrxr<=donefromrx;
            donefromtxr<=donefromtx;
            ack_error<=ack_errorr;
            nozero<=nozeror;
            TECin<=TECinr;
            RECin<=RECinr;
            Reck<=Reckr;
        end
    end
end

always@(*)begin
    if(((req_Error_TX)&&(TXSTATES==TXACKSL))&&(State==NOERROR))begin
        ack_errorr=1;
    end
    else if(State==SEND||State==CHECK)
        ack_errorr=ack_error;
    else ack_errorr=0;

    if(State==SEND)
        nozeror=nozero&&Sampled_din;
    else nozeror=1;
end
//at end when transistioninn to DL check for that no other nodes in bus exception for ack
always@(*)begin
    TECinr=TECin;
    RECinr=RECin;
    Reckr=0;
case(State)
NOERROR:begin
        if((req_Error_TX || req_Error_RX)&&(~ErrState))//new request
        begin
            Stater=(TEC>=256)?RECOVERY:SEND; //if bus off no need to acknowledge that errors given
            TXpinr=((TEC>127)||(REC>127))?1:0;
            RECinr=REC;
            TECinr=TEC;
            Cntr=0;
        end
        else if(((RXSTATES==INTERMISSION12))&&(Sampled_din==0))begin
            Stater=OVFL;
            TXpinr=0;
            Cntr=0;
        end
        else begin
            Stater=NOERROR;
            TXpinr=1;
            Cntr=0;
        end
end
SEND:begin
    if((TECin>127)||(RECin>127))begin
        TXpinr=1;
        if(Cnt==5)
            begin
                if(Sampled_din==lastvalue)begin
                    Stater=CHECK;
                    Cntr=0;
                end
                else begin
                    Stater=SEND;
                    Cntr=0; 
                end
            end
            else if(Cnt==0)
            begin
                Cntr=Cnt+1;
                Stater=SEND;
            end
        else begin
            Cntr=(Sampled_din==lastvalue)?Cnt+1:1;
            Stater=SEND;
        end
    end
    else begin//active error case
        TXpinr=(Cnt!=5)?0:1;
        Cntr=(Cnt!=5)?Cnt+1:0;
        Stater=(Cnt!=5)?SEND:CHECK;
    end

end
CHECK:begin//independent of TEC and REC updates
    TXpinr=1;
    if(Sampled_din==1)begin
        Stater=DL;
        Cntr=0;
    end
    else begin
        Stater=CHECK;
        Cntr=(Cnt==7)?0:Cnt+1;//check for 8 14 22 trigger (0 at 7th is running is 8th bit)
    end
end
DL:begin
    if(Sampled_din==0)begin
        if(Cnt==6)begin//has to be 7th bit here cos check gets min 1 bit
            Stater=OVFL;
            TXpinr=0;
            Cntr=0;
        end
        else begin
            Stater=(TEC>=256)?RECOVERY:SEND; //if bus off no need to acknowledge that errors given
            TXpinr=((TEC>127)||(REC>127))?1:0;
            RECinr=REC;
            TECinr=TEC;
            Cntr=0;
        end
    end
    else begin
        if(Cnt==6)begin
            Stater=NOERROR;
            TXpinr=1;
            Cntr=0;
    end
    else begin
            Stater=DL;
            TXpinr=1;
            Cntr=Cnt+1; 
        end
    end
end
OVDL:begin
    if(Sampled_din==0)begin
        if(Cnt==7)begin
            Stater=OVFL;
            TXpinr=0;
            Cntr=0;
        end
        else begin
            Stater=(TEC>=256)?RECOVERY:SEND; //if bus off no need to acknowledge that errors given
            TXpinr=((TEC>127)||(REC>127))?1:0;
            RECinr=REC;
            TECinr=TEC;
            Cntr=0;
        end
    end
    else begin
        if(Cnt==7)begin
            Stater=NOERROR;
            TXpinr=1;
            Cntr=0;
    end
    else begin
            Stater=OVDL;
            TXpinr=1;
            Cntr=Cnt+1; 
        end
    end
end

RECOVERY:begin
    TXpinr=1;
    if(Sampled_din==1)begin
        if((Cnt==10)&&(Reck==127))begin//back on TX //change back to 127 from 10
            Cntr=0;
            Stater=NOERROR;
            Reckr=0;
        end
        else if((Cnt==10)) begin
            Cntr=0;
            Stater=RECOVERY;
            Reckr=Reck+1;
        end
        else begin
            Cntr=Cnt+1;
            Stater=RECOVERY;
            Reckr=Reck;
        end
    end
    else begin
        Cntr=0;
        Reckr=Reck;
        Stater=RECOVERY;
    end

end
OVFL:begin
    if(Sampled_din==0&&Cnt!=5)
    begin
        TXpinr=0;
        Cntr=Cnt+1;
        Stater=OVFL;
    end
    else if(Sampled_din==1)begin
            Stater=(TEC>=256)?RECOVERY:SEND; //if bus off no need to acknowledge that errors given
            TXpinr=((TEC>127)||(REC>127))?1:0;
            Cntr=0;
            TECinr=TEC;
            RECinr=REC;
    end
    else begin
        TXpinr=1;
        Cntr=0;
        Stater=OVDL;
    end
end
default:begin
            Stater=NOERROR;
            TXpinr=1;
            Cntr=0;
end
endcase

end

//TEC update
always@(*)begin
    if(State==RECOVERY&&Stater==NOERROR)begin
        TECr=0;
    end
    else if(req_Error_TX==1 && (~ErrState) )begin //error start when there was no error seq sent now
        TECr=9'(TEC+8);
    end
    else if(State==CHECK && Cnt==7 && Sampled_din==0 && imTX)begin
        TECr=9'((TEC>=256)?(256):9'(TEC+8));
    end
    else if(State==SEND&&(TECin<128)&&(RECin<128)&&(Sampled_din==1)&&(imTX))begin
        TECr=9'((TEC>=256)?(256):9'(TEC+8));
    end
    else if(ack_error==1 && State==CHECK && Cnt==0 && nozero==1)
    begin
        TECr=9'(TEC-8);
    end
    else if(State==DL && Stater==SEND && imTX)//direct to next 
    begin
        TECr=9'((TEC>=256)?(256):9'(TEC+8));
    end
    else if(OVFL == State && Sampled_din==1 && imTX)
    begin
        TECr=9'((TEC>=256)?(256):9'(TEC+8));
    end
    else if(donefromtx&&~donefromtxr)//only first done
    begin
        TECr=(TEC!=0)?9'(TEC-1):TEC;
    end
    else TECr=TEC;
end

//REC update
always@(*)begin
    if(State==RECOVERY&&Stater==NOERROR)begin
        RECr=0;
    end
    else if(donefromrx&& ~donefromrxr)
    begin
        RECr=(REC>127)?120:(REC!=0?REC-1:0);  //chosen 120 as highest 0 btw 119 to 127
    end
    else if(req_Error_RX==1 && (~ErrState) && req_Error_TX!=1 )begin //give tx higher priority
        RECr=9'(REC+1);
    end
    else if(State==CHECK && Cnt==7 && Sampled_din==0 && ~imTX)begin
        RECr=9'((REC>256)?(256):9'(REC+8));
    end
    else if(State==SEND&&(TECin<128)&&(RECin<128)&&(Sampled_din==1)&&(~imTX))begin
        RECr=9'(REC+8);
    end
    else if(State==DL && Stater==SEND && ~imTX)//direct to next 
    begin
        RECr=9'(REC+1);
    end
    else if(OVFL == State && Sampled_din==1 && ~imTX)
    begin
        RECr=9'((REC>=256)?(256):9'(REC+8));
    end
    else RECr=REC;

end

endmodule
