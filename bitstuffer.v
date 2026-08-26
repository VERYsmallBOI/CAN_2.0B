module bitstuffer (
    input  wire din,       // Current input data bit
    input  wire clk,
    input  wire rst,
    input  wire srst,      // Soft reset
    input  wire pause_in,
    output  bitout,
    output wire pause_out  // Pause signal to hold new data from master
);
    reg [4:0] serial;


    assign bitout=pause_out?~serial[0]:din;
    always @(posedge clk, negedge rst) begin
        if (!rst) begin
            serial <= 5'b00001;  // SOF is always 0
        end
        else begin
            if (!srst) begin
                serial <= 5'b00001;
            end
            else begin
                if (!pause_in) begin
                    if (pause_out) begin
                        serial <= {serial[3:0], ~serial[0]};
                    end
                    else begin
                        serial[4:1] <= serial[3:0];
                        serial[0]   <= din;
                    end
                end
            end
        end
    end

    assign pause_out = &serial || ~(|serial);

endmodule