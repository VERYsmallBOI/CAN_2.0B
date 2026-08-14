module bitstuffer(din, clk, rst, srst, bitout, pause);

input din;             // Current input data bit
input clk, rst;
input srst;            // Soft reset

output reg bitout;
reg [2:0] dcounter;
reg [4:0] serial;

output wire pause;  // Pause signal to hold new data from master


always @(posedge clk, negedge rst) begin
    if (!rst) begin
        bitout <= 1'b1;
    end
    else begin
        if (!srst) begin
            bitout <= 1'b1;
        end
        else begin
            if (pause) begin
                bitout <= !serial[0];
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
            if (pause) begin
                serial <= {serial[3:0], ~serial[0]};
            end
            else begin
                serial[4:1] <= serial[3:0];
                serial[0]   <= din;
            end
        end
    end
end


assign pause = &serial || ~(|serial);


endmodule
// reg din_r;
// always@(posedge clk,negedge rst)begin
// if(!rst)begin
// din_r<=1'b1;
// end

// else begin
// if(!srt)begin
// din_r<=1'b1  ;
// end
// else begin
// din_r<=din;
// end

// end
// end
// always@(posedge clk,negedge rst)
// begin
// if(!rst)begin
//     pause<=1'b0;
// end
// else begin
// if(!srst) begin
//     pause<=1'b0;
// end
// else begin
//     pause<= &serial || ~(|serial); //all 1 and all 0
// end
// end
// end

// always@(posedge clk,negedge rst)begin
// if(!rst)begin
// dcounter<=0;
// end
// else begin
// if(!srt)begin
// dcounter<=0;
// end
// else begin
//     if(dcounter==5)begin
//         dcounter=1;
//         old-
//     end else begin
//     if(din[counter+1]==din[counter])
// dcounter<=dcounter+1;
// else dcounter<=0;
// end
// end
// end



// end



// always@(posedge clk,negedge rst)
// begin
// if(!rst)begin
//     noshift<=1'b0;
// end
// else begin
// if(!srst) begin
//     noshift<=1'b0;
// end
// else begin
//     if(pause)
//     noshift<=1'b1;
//     else noshift<=1'b0;
// end
// end
// end




// always@(posedge clk,negedge rst)
// begin
// if(!rst)
// begin
//     count<=7'b0;
// end
// else begin
//     if(!srst)begin
//         count<=7'b0;
//     end
//     else begin
//         if(!noshift && pause)
//         begin
//             count<=count;
//         end
//         else begin
//             count<=count + 1'b1;
//         end
//     end
// end

// end
