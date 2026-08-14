//NOTES
//RXBUS is input from 2FF
//Gives out CNT1 and CNT2 for TRANSMITTER SYNCRONIZATION
//SEG values and prop are from apb directly
module Rengine(RXBUS, STATE, TXVALUE, CNT1, CNT2, TPROP, TSEG1, TSEG2, Tq, rst, RXOUT);
  localparam IDLE = 0;// pending
  input RXBUS, TXVALUE, Tq, rst;
  input [3:0] TPROP, TSEG1, TSEG2;// 1 to 8
  input [1:0] STATE; //SOF considereation
  output reg [4:0] CNT1;//max is 15 anyway 8+8+1 
  reg [4:0] CNT1r; 
  output reg [3:0] CNT2; //it has to go from 7 to 0 anyway
  reg [3:0] CNT2r;
  output reg RXOUT;
  reg RXOUT1;
  wire [4:0]PHASE1;//3 to 17 but will hold 2 to 16
  wire [2:0] SJW; //1 to 4 (if PHASE SEG 1 is lower use it)
  reg RXBUS_d;
  wire change;
  wire [2:0]e1,e2;
  wire [4:0]diff;//will accomodate 16 but tho until 8 is also ok cos SJW is never more than 4
  
  always @(posedge Tq, negedge rst) begin
    if (!rst)
      RXBUS_d <= 0;
    else 
      RXBUS_d <= RXBUS;
  end

assign SJW=(4<TSEG1)?4:TSEG1[2:0];

  assign PHASE1=TPROP + TSEG1;//TSYNC extra 1 will be by 0 
  assign change = (RXBUS_d) && !(RXBUS); 
  assign diff=5'(PHASE1-CNT1);//dynamic but PHASE1 can 2 to 16 and CNT1 can be 16 to 0
  assign e1=({2'b0,SJW}>diff)?diff[2:0]:SJW; //dynamic e1 can be 4 to 0
  // dynamic e2 can be 4 to 0(edge case diff is 0 - at Tsync so wont need it anyway and literally no eror)
  assign e2=({1'b0,SJW}>CNT2)?CNT2[2:0]:SJW;

  always @(posedge Tq, negedge rst) begin
    if(!rst)begin
        CNT1<=0;
        CNT2<=0;
  end
  else begin
    CNT1<=CNT1r;
    CNT2<=CNT2r;
  end
  end
 always @(*) begin
    if (change) begin
      if (STATE == IDLE) begin
        CNT1r = PHASE1;
        CNT2r = TSEG2-1;
      end
      else begin
        if (TXVALUE == 1'b0) begin
          if (CNT1 != 0) begin
            CNT1r = CNT1 - 1;
            CNT2r = CNT2;
          end
          else begin
            if (CNT2 != 0)begin
              CNT2r = CNT2 - 1;
              CNT1r = 0;
            end
            else begin
              CNT1r = PHASE1;
              CNT2r = TSEG2 - 1;
            end
          end
        end
        else begin
          if ((CNT1 == 0) && (CNT2 == 0)) begin //at end cant anyway shrink anymore but end of CNT1 can be extended
            CNT1r = PHASE1 ;
            CNT2r = TSEG2 - 1;
          end
          else begin
            if (CNT1>0) begin //same condition as CNT1 is still runing ie bfr sample
              CNT1r = 5'(CNT1+e1);
              CNT2r = CNT2;
            end
            else begin  
                if(CNT2 == (TSEG2 -1))begin//do nothing just decrement
                CNT1r = CNT1;
                CNT2r = CNT2-1; 
                end
                else begin
                  //CNT2>0 decreases to get next sync
                    CNT1r=0;
                    CNT2r=CNT2-e2;
                end
            end
          end
        end
      end
    end
    else begin
          if (CNT1 != 0) begin
            CNT1r = CNT1 - 1;
            CNT2r = CNT2;
          end
          else begin
            if (CNT2 != 0)begin
              CNT2r = CNT2 - 1;
              CNT1r = 0;
            end
            else begin
              CNT1r = PHASE1;
              CNT2r = TSEG2 - 1;
            end
          end
        end
  end 

//RX pending
//what RX DOES with CNT made
always@(posedge Tq,negedge rst)begin
  if(!rst)
    RXOUT<=1'b1;

else RXOUT<=RXOUT1;
end

always@(*)begin
  if((CNT1==0) && (CNT2==(TSEG2-1)))
    RXOUT1=RXBUS;
  else RXOUT1=RXOUT;
end


endmodule