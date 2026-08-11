module CRC (
    NXTBIT,
    srst,//sync RESET for multiple transmissions.
    clk,
    rst,
    CRC_RG
);
    input wire NXTBIT, srst, clk, rst;
    output reg [14:0] CRC_RG;
    reg CRC_NXT;

    always @(posedge clk, negedge rst) begin
        if (!rst) begin
            CRC_RG  <= 0;
            CRC_NXT <= 0;
        end else begin
            if (srst) begin
                CRC_NXT      <= NXTBIT ^ CRC_RG[14];
                CRC_RG[14:1] <= CRC_RG[13:0];
                CRC_RG[0]    <= 1'b0;
                if (CRC_NXT) begin
                    CRC_RG <= CRC_RG[14:0] ^ (15'h4599);
                end else begin
                    CRC_RG <= CRC_RG;
                end
            end else begin
                CRC_NXT <= 0;
                CRC_RG  <= 0;
            end
        end
    end

endmodule