//NOTES
//RXBUS is input from 2FF
//Gives out CNT1 and CNT2 for TRANSMITTER SYNCRONIZATION
//SEG values and prop are from apb directly
module Rengine(RXBUS, STATE, TXVALUE, CNT1, CNT2, TPROP, TSEG1, TSEG2, Tq, rst, SJW);
  //localparam IDLE = ; pending
  input RXBUS, TXVALUE, Tq, rst;
  input [2:0] TPROP, TSEG1, TSEG2;
  input [1:0] STATE; //SOF considereation

  output reg [3:0] CNT1,CNT1r;
  output reg [2:0] CNT2,CNT2r;
  output RXOUT;
  wire [3:0]PHASE1;
  reg [2:0] SJW; //1 to 4 (if PHASE SEG 1 is lower use it)
  reg RXBUS_d;
  wire change;
  wire [2:0]e1,e2,diff;
  
  always @(posedge Tq, negedge rst) begin
    if (!rst)
      RXBUS_d <= 0;
    else 
      RXBUS_d <= RXBUS;
  end

  always@(*)begin
    if(TSEG1[2])
    begin
        SJW=4;
    end
    else begin
    SJW=TSEG1;
    end
  end

  assign PHASE1=TPROP + TSEG1;
  assign change = (RXBUS_d) && !(RXBUS);
  assign diff=(PHASE1-CNT1);
  assign e1=(SJW>diff)?diff:SJW;
  assign e2=(SJW>CNT2)?CNT2:SJW;

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
          if (CNT1 == 0 && CNT2 == 0) begin //at end
            CNT1r = PHASE1 ;
            CNT2r = TSEG2 - 1;
          end
          else begin
            if (CNT1 > 0) begin //CNT2 is defo not ==0
              CNT1r = CNT1+(e1);
              CNT2r = CNT2;
            end
            else begin //CNT2>0
                CNT1r = 0;
                CNT2r = CNT2-e2; 
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

endmodule