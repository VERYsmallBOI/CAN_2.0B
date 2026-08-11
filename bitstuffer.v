module bitstuffer(din,clk,rst,srst,bitout,count);
input [127:0]din;//CRC appended
input clk,rst;
input srst;//soft reset
output reg bitout;
output reg [6:0]count;
reg [4:0]serial;
reg noshift,allequal;

always@(posedge clk,negedge rst)
begin
if(!rst)begin
serial<=5'b00001;//SOF is always 0
end
else begin
if(!srst) begin
serial<=5'b00001;
end
else begin
    if(!noshift && allequal) begin
        serial<=serial;
    end
    else begin
serial[4:1]<=serial[3:0];
serial[0]<=din[count];
    end
end
end

end

always@(posedge clk,negedge rst)
begin
if(!rst)begin
    allequal<=1'b0;
end
else begin
if(!srst) begin
    allequal<=1'b0;
end
else begin
    allequal<= &serial || ~(|serial); //all 1 and all 0
end
end
end

always@(posedge clk,negedge rst)
begin
if(!rst)begin
    noshift<=1'b0;
end
else begin
if(!srst) begin
    noshift<=1'b0;
end
else begin
    if(allequal)
    noshift<=1'b1;
end
end
end

always@(posedge clk,negedge rst)
begin
if(!rst)
begin
    bitout<=1'b1;
end
else begin
    if(!srst)begin
        bitout<=1'b1;
    end
    else begin
        if(!noshift && allequal)
        begin
            bitout<=!serial[0];
        end
        else begin
            bitout<=din[count];
        end
    end
end

end

always@(posedge clk,negedge rst)
begin
if(!rst)
begin
    count<=7'b0;
end
else begin
    if(!srst)begin
        count<=7'b0;
    end
    else begin
        if(!noshift && allequal)
        begin
            count<=count;
        end
        else begin
            count<=count + 1'b1;
        end
    end
end

end

endmodule