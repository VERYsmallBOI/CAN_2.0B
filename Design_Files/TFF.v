module TFF(D,rst,clk,q);
input D,rst,clk;
wire q1;
output q;
dff d1(D,rst,clk,q1);
dff d2(q1,rst,clk,q);

endmodule

module dff(D,rst,clk,q);
input D,rst,clk;
output reg q;


always@(posedge clk,negedge rst)begin

    if(!rst)begin
        q<=0;
    end
    else q<=D;

end

endmodule



module TFF0(D,rst,clk,q);
input D,rst,clk;
wire q1;
output q;
dff0 d1(D,rst,clk,q1);
dff0 d2(q1,rst,clk,q);

endmodule

module dff0(D,rst,clk,q);
input D,rst,clk;
output reg q;


always@(posedge clk,negedge rst)begin

    if(!rst)begin
        q<=1;
    end
    else q<=D;

end

endmodule