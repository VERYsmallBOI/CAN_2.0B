module APBCDC (
    // Clock & System Resets
    input  wire        PCLK,
    input  wire        PRESETn,
    input  wire        Tq,
    input  wire        CAN_RST,
    output reg         SRST,

    // APB Bus Interface
    input  wire        PSEL,
    input  wire        PENABLE,
    input  wire        PWRITE,
    input  wire [5:0]  PADDR,
    input  wire [31:0] PWDATA,
    output wire        PREADY,
    output wire        PSLVERR,
    output wire [31:0] PRDATA,

    // Timing & Mode Configuration
    output wire [2:0]  SJW,
    output wire [3:0]  TPROP,
    output wire [3:0]  TSEG1,
    output wire [3:0]  TSEG2,
    output wire [4:0]  BRP,
    output wire [2:0]  Mode,         // {Loopback, Listen_Only, Soft_Reset}

    // Transmit Interface
    output reg        TRANSMIT,
    input  wire [3:0]  TXSTATES,
    output wire        RTR_TX,
    output wire        IDE_TX,
    output wire [3:0]  D_Len_TX,
    output wire [28:0] ID_TX,
    output wire [63:0] FULLDATA_TX,

    // Receive & Filter Interface
    input  wire        done_RX,
    input  wire        IDE_rec,
    input  wire        RTR_rec,
    input  wire [3:0]  D_Len_rec,
    input  wire [63:0] TOFILTERd,
    input  wire [28:0] TOFILTERI,
    input  wire [8:0]  TEC,
    input  wire [8:0]  REC,
    input wire done_TX//from TXMachine
);
    localparam TXIDLE=4'd0,
    TXINTERMISSION=4'd10,
    TXSUSPEND=4'd11,
    TXERROR=4'd12;

    // Internal Registers
    reg [4:0]  PWADDR_can;
    reg [7:0]  REGBANK_can [23:0];
    reg [1:0]  Cnt_srst;
    reg [1:0]  Cnt_srstr;
    reg        SRSTr;
    reg done_TXr;
    // Internal Wires
    wire        empty_fifo,fifo_full;
    wire        rd_cmd;
    wire [98:0] FIFO_READ;
    wire [98:0] wdata;
//wdata  to fifo building
assign wdata={IDE_rec,RTR_rec,TOFILTERI,TOFILTERd,D_Len_rec};//{IDE, RTR, ID[28:0],DATA[63:0], D_LEN[3:0]};

// MODE / TIMING @ offset 0
assign BRP   = {REGBANK_can[1][3:0], REGBANK_can[0][7]};
assign Mode = REGBANK_can[0][2:0];

// TXCTRL @ offset 8
assign RTR_TX = REGBANK_can[8][5];
assign IDE_TX = REGBANK_can[8][4];
assign D_Len_TX = REGBANK_can[8][3:0];

// TXREQ @ offset 20
assign SJW   = REGBANK_can[3][2:0];
assign TPROP = REGBANK_can[2][7:4];
assign TSEG2 = REGBANK_can[2][3:0];
assign TSEG1 = REGBANK_can[1][7:4];

assign ID_TX = {
    REGBANK_can[7][4:0],
    REGBANK_can[6],
    REGBANK_can[5],
    REGBANK_can[4]
};

assign FULLDATA_TX = {
    REGBANK_can[15],
    REGBANK_can[14],
    REGBANK_can[13],
    REGBANK_can[12],
    REGBANK_can[19],
    REGBANK_can[18],
    REGBANK_can[17],
    REGBANK_can[16]
};

//wr_cmd and full logic
reg done_RX_R,wcmd;
always@(posedge Tq or negedge CAN_RST)begin
if(~CAN_RST)begin
    wcmd<=0;
    done_RX_R<=0;
end
else begin //one pulse and no glitch
// Keep generating write requests until FIFO confirms successful write.
    wcmd<=~done_RX_R&&done_RX;//keep giving until it takes
    done_RX_R<=(done_RX)?(done_RX_R||(~fifo_full)):0;//lock when write is done
end
end

wire [31:0]TXBUFFER;
reg [31:0]TXBUFFER_can;



FIFO FIFO1 (
    .wclk  (Tq),
    .rclk  (PCLK),
    .wrst  (CAN_RST),
    .rrst  (PRESETn),
    .empty (empty_fifo),
    .wdata (wdata),
    .rdata (FIFO_READ),
    .rcmd  (rd_cmd),
    .wcmd  (wcmd),
    .full (fifo_full)
);

wire [4:0]PWADDR;
wire change,change_can;
wire [31:8]STATUS_F;
wire done_HS;
reg done_HS_CAN;

APBDock APD1 (
    .PCLK       (PCLK),
    .PRESETn    (PRESETn),
    .PSEL       (PSEL),
    .PENABLE    (PENABLE),
    .PWRITE     (PWRITE),
    .PADDR      (PADDR),
    .PREADY     (PREADY),
    .PSLVERR    (PSLVERR),
    .PRDATA     (PRDATA),
    .PWDATA     (PWDATA),
    .empty_fifo (empty_fifo),
    .TXBUFFER   (TXBUFFER),
    .change     (change),
    .done_HS    (done_HS),
    .STATUS_F   (STATUS_F),
    .FIFO_READ  (FIFO_READ),
    .rd_cmd     (rd_cmd),
    .PWADDR     (PWADDR)
);



//HS CONSTRUCITON-pending
//TFF array for PWADDR and TXBUFFER synced by change(req) and gets done_HS

TFF change_tff(.D(change),.rst(CAN_RST),.clk(Tq),.q(change_can));
TFF done_tff(.D(done_HS_CAN),.rst(PRESETn),.clk(PCLK),.q(done_HS));


always@(posedge Tq or negedge CAN_RST)begin
if(~CAN_RST)begin
   done_HS_CAN<=0;
   done_TXr<=0;
   TRANSMIT<=0;
   // TXREQ is 0 all the way
// TXDATAL and DATAH is 0

// TXCTRL
// RTR is 1 IDE is 1
// DLC is 0
// TXID is 29 alternating 10s startinf and ending with 1
// TROP is 4 TSEG1 is 4 TSEG2 is 4 BRP is 8 all the LOOP back =1
//SJW is 4
REGBANK_can[0]  <= 8'h00;
REGBANK_can[1]  <= 8'h44;
REGBANK_can[2]  <= 8'h44;
REGBANK_can[3]  <= 8'h04;

REGBANK_can[4]  <= 8'h55;
REGBANK_can[5]  <= 8'h55;
REGBANK_can[6]  <= 8'h55;
REGBANK_can[7]  <= 8'h15;

REGBANK_can[8]  <= 8'h30;
REGBANK_can[9]  <= 8'h00;
REGBANK_can[10] <= 8'h00;
REGBANK_can[11] <= 8'h00;

REGBANK_can[12] <= 8'h00;
REGBANK_can[13] <= 8'h00;
REGBANK_can[14] <= 8'h00;
REGBANK_can[15] <= 8'h00;

REGBANK_can[16] <= 8'h00;
REGBANK_can[17] <= 8'h00;
REGBANK_can[18] <= 8'h00;
REGBANK_can[19] <= 8'h00;

REGBANK_can[20] <= 8'h00;
REGBANK_can[21] <= 8'h00;
REGBANK_can[22] <= 8'h00;
REGBANK_can[23] <= 8'h00;
PWADDR_can<=0;
Cnt_srst<=0;
TXBUFFER_can<=0;
SRST<=1;
end
else begin
    done_TXr<=done_TX;
    Cnt_srst<=Cnt_srstr;
    SRST<=SRSTr;

    if((~TRANSMIT||PWADDR_can<4)&&(change_can||done_HS_CAN))begin 

    if(change_can&&done_HS_CAN==0)begin
        PWADDR_can<=PWADDR;
        TXBUFFER_can<=TXBUFFER;
        done_HS_CAN<=1'b1;
    end
else if(change_can==0 && done_HS_CAN==1)   begin//deassert
    //no overflow ever cos the PWADDR_can ever be 
            done_HS_CAN<=1'b0;
            REGBANK_can[5'(PWADDR_can)]<=TXBUFFER_can[7:0];
            REGBANK_can[5'(PWADDR_can+1)]<=TXBUFFER_can[15:8];
            REGBANK_can[5'(PWADDR_can+2)]<=TXBUFFER_can[23:16];
            REGBANK_can[5'(PWADDR_can+3)]<=TXBUFFER_can[31:24];
        end
    end
else begin
    REGBANK_can[20]<=8'b0;
end
    if(REGBANK_can[20]==8'b1)begin
        TRANSMIT<=1;
    end
    else if(done_TXr==0 && done_TX==1) begin
        TRANSMIT<=0;
    end
end
end

always@(*)begin
if(~change_can && done_HS_CAN && PWADDR_can<4 )begin //all timing and mode regs
SRSTr=0;
Cnt_srstr=2;
end
else begin
if(Cnt_srst!=0)
begin
    Cnt_srstr=Cnt_srst-1;
    SRSTr=0;
end
else begin
    SRSTr=1;
    Cnt_srstr=0;
end
end
end



//STATUS_F construction
reg BUSOFF,BUSOFFr,ERRORP,ERRORPr,TX_IDLE,TX_IDLEr;
wire [8:0]TECs,RECs,TECg,RECg,RECb,TECb;
wire BUSOFFs,ERRORPs,TX_IDLEs;

always@(*)begin
    BUSOFFr=TEC>255;
    ERRORPr=(REC>127)||(TEC>127);
    TX_IDLEr=(TXSTATES==0);//IDLE=0
end
always@(posedge Tq or negedge CAN_RST)
begin
if(~CAN_RST)begin
    BUSOFF<=0;
    ERRORP<=0;
    TX_IDLE<=0;  
end
else begin
    BUSOFF<=BUSOFFr;
    ERRORP<=ERRORPr;
    TX_IDLE<=TX_IDLEr;
    end
end


TFF BUSOFF_tff(.D(BUSOFF),.clk(PCLK),.rst(PRESETn),.q(BUSOFFs));
TFF ERRORP_tff(.D(ERRORP),.clk(PCLK),.rst(PRESETn),.q(ERRORPs));
TFF TXIDLE_tff(.D(TX_IDLE),.clk(PCLK),.rst(PRESETn),.q(TX_IDLEs));

//b2g TEC and REC bfr sneding
// TEC (Total Error Count) 
b2g9 TEC_b2g (.in1(TEC), .out1(TECg));

// REC (Receive Error Count) 
b2g9 REC_b2g_0 (.in1(REC), .out1(RECg));

//TEC and REC sync
TFF TECtff0(.D(TECg[0]), .rst(PRESETn), .clk(PCLK), .q(TECs[0]));
TFF TECtff1(.D(TECg[1]), .rst(PRESETn), .clk(PCLK), .q(TECs[1]));
TFF TECtff2(.D(TECg[2]), .rst(PRESETn), .clk(PCLK), .q(TECs[2]));
TFF TECtff3(.D(TECg[3]), .rst(PRESETn), .clk(PCLK), .q(TECs[3]));
TFF TECtff4(.D(TECg[4]), .rst(PRESETn), .clk(PCLK), .q(TECs[4]));
TFF TECtff5(.D(TECg[5]), .rst(PRESETn), .clk(PCLK), .q(TECs[5]));
TFF TECtff6(.D(TECg[6]), .rst(PRESETn), .clk(PCLK), .q(TECs[6]));
TFF TECtff7(.D(TECg[7]), .rst(PRESETn), .clk(PCLK), .q(TECs[7]));
TFF TECtff8(.D(TECg[8]), .rst(PRESETn), .clk(PCLK), .q(TECs[8]));

TFF RECtff0(.D(RECg[0]), .rst(PRESETn), .clk(PCLK), .q(RECs[0]));
TFF RECtff1(.D(RECg[1]), .rst(PRESETn), .clk(PCLK), .q(RECs[1]));
TFF RECtff2(.D(RECg[2]), .rst(PRESETn), .clk(PCLK), .q(RECs[2]));
TFF RECtff3(.D(RECg[3]), .rst(PRESETn), .clk(PCLK), .q(RECs[3]));
TFF RECtff4(.D(RECg[4]), .rst(PRESETn), .clk(PCLK), .q(RECs[4]));
TFF RECtff5(.D(RECg[5]), .rst(PRESETn), .clk(PCLK), .q(RECs[5]));
TFF RECtff6(.D(RECg[6]), .rst(PRESETn), .clk(PCLK), .q(RECs[6]));
TFF RECtff7(.D(RECg[7]), .rst(PRESETn), .clk(PCLK), .q(RECs[7]));
TFF RECtff8(.D(RECg[8]), .rst(PRESETn), .clk(PCLK), .q(RECs[8]));


// REC (0 to 8)
g2b9 REC_g2b9 (.in1(RECs), .out1(RECb));

// TEC (0 to 8)
g2b9 TEC_g2b9_0 (.in1(TECs), .out1(TECb));

//  //\ /\\
//  \\/ \//

//always@(*)begin
  assign  STATUS_F={BUSOFFs,ERRORPs,empty_fifo,TX_IDLEs,2'b0,RECb,TECb};
//end


endmodule

module b2g9(in1,out1);
input [8:0]in1;
output reg [8:0]out1;

always@(*)begin
out1=in1^{1'b0,in1[8:1]};
end
endmodule

module g2b9 (
    input  [8:0] in1,  // 9-bit Gray code input
    output [8:0] out1  // 9-bit Binary output
);

    // Using bitwise vector right-shift with XOR reduction
    assign out1[8] = in1[8];
    assign out1[7] = in1[8] ^ in1[7];
    assign out1[6] = in1[8] ^ in1[7] ^ in1[6];
    assign out1[5] = in1[8] ^ in1[7] ^ in1[6] ^ in1[5];
    assign out1[4] = in1[8] ^ in1[7] ^ in1[6] ^ in1[5] ^ in1[4];
    assign out1[3] = in1[8] ^ in1[7] ^ in1[6] ^ in1[5] ^ in1[4] ^ in1[3];
    assign out1[2] = in1[8] ^ in1[7] ^ in1[6] ^ in1[5] ^ in1[4] ^ in1[3] ^ in1[2];
    assign out1[1] = in1[8] ^ in1[7] ^ in1[6] ^ in1[5] ^ in1[4] ^ in1[3] ^ in1[2] ^ in1[1];
    assign out1[0] = ^in1; // XOR reduction of all bits for LSB

endmodule