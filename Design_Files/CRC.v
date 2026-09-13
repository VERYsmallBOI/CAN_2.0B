module CRC (
    NXTBIT,
    srst,//sync RESET for multiple transmissions.
    clk,
    rst,
    CRC_RG,
    Pause
);
    input wire NXTBIT, srst, clk, rst, Pause;
    output reg [14:0] CRC_RG;
    reg CRC_NXT;
    reg [14:0] CRC_RG1,CRC_RG2;
    always @(posedge clk, negedge rst) begin
        if (!rst) begin
            CRC_RG  <= 0;
        end else begin
            if (!srst) begin
                CRC_RG  <= 0;
            end else begin
                if(Pause)begin
                    CRC_RG <= CRC_RG;
                end else begin
                CRC_RG <= CRC_RG2;
                end                    
            end
        end
    end
    always@(*)begin
        CRC_NXT      = NXTBIT ^ CRC_RG[14];
        CRC_RG1[14:1] = CRC_RG[13:0];
        CRC_RG1[0]    = 1'b0;
        if(CRC_NXT)
            CRC_RG2   = (CRC_RG1[14:0] ^ (15'h4599));
        else 
            CRC_RG2   = CRC_RG1;
    end

endmodule