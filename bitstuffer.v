module bitstuffer (
    input  wire din,       // Current input data bit
    input  wire clk,
    input  wire rst,
    input  wire srst,      // Soft reset
    input  wire pause_in,
    output reg  bitout,
    output wire pause_out  // Pause signal to hold new data from master
);
    reg [4:0] serial;

    always @(posedge clk, negedge rst) begin
        if (!rst) begin
            bitout <= 1'b1;
        end
        else begin
            if (!srst) begin
                bitout <= 1'b1;
            end
            else begin
                if (pause_out) begin
                    bitout <= ~serial[0];
                end
                else begin
                    bitout <= din;
                end
            end
        end
    end

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