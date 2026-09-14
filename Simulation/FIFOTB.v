`timescale 1ns/1ps

module FIFO_tb;
    reg  wclk, rclk, wrst, rrst, rcmd, wcmd;
    reg  [98:0] wdata;
    wire [98:0] rdata;
    wire doner, donew, empty;

    wire [4:0] rptr = dut.rptr;
    wire [4:0] wptr = dut.wptr;
    wire       full = dut.full;

    FIFO dut(
        .wclk(wclk), .rclk(rclk),
        .wrst(wrst), .rrst(rrst),
        .wdata(wdata), .rdata(rdata),
        .rcmd(rcmd), .wcmd(wcmd),
        .doner(doner), .donew(donew),
        .empty(empty)
    );

    // rclk : period 10ns, starts at t=0
    initial rclk = 0;
    always #5 rclk = ~rclk;

    // wclk : period 110ns, starts at t=3
    initial begin
        wclk = 0;
        #3;
        forever #55 wclk = ~wclk;
    end

    // ---- Monitor ----
    initial begin
        $monitor("T=%0t | empty=%b full=%b doner=%b donew=%b rcmd=%b wcmd=%b | rptr=%0d wptr=%0d | rdata=%h [b98=%b low4=%0d]",
                 $time, empty, full, doner, donew, rcmd, wcmd,
                 rptr, wptr, rdata, rdata[98], rdata[3:0]);
    end

    // ---- rdata change log ----
    reg [98:0] rdata_prev;
    initial rdata_prev = 0;
    always @(rdata) begin
        if (rdata !== rdata_prev) begin
            $display("        >>> rdata CHANGED @ T=%0t : value=%h | MSB=%b | low4=%0d",
                     $time, rdata, rdata[98], rdata[3:0]);
            rdata_prev = rdata;
        end
    end

    // ================= Stimulus =================
    initial begin
        wrst = 0; rrst = 0;
        wcmd = 0; rcmd = 0;
        wdata = 0;

        // Reset
        #50;
        wrst = 1; rrst = 1;
        $display("T=%0t | Reset released", $time);
        #100;

        // ---- 1 WRITE ----
        $display("\nT=%0t | === SINGLE WRITE : payload = {1'b1, 94'd0, 4'hA} ===", $time);
        @(negedge wclk);
        wdata = {1'b1, 94'd0, 4'hA};   // 99 bits exactly
        wcmd  = 1;
        @(negedge wclk);
        wcmd  = 0;
        $display("T=%0t | wrote one word, expect wptr=1", $time);
        #200;

        // ---- 1 READ ----
        $display("\nT=%0t | === SINGLE READ ===", $time);
        @(negedge rclk);
        rcmd = 1;
        @(posedge rclk);
        @(negedge rclk);
        rcmd = 0;
        $display("T=%0t | read one word, expect rptr=1 empty=1", $time);
        #200;

        $display("\nT=%0t | DONE", $time);
        $finish;
    end

    // Watchdog
    initial begin
        #20000;
        $display("T=%0t | WATCHDOG timeout", $time);
        $finish;
    end

    initial begin
        $dumpfile("fifo.vcd");
        $dumpvars(0, FIFO_tb);
    end

    // ================= SAFETY CHECKER =================
    localparam PTRMOD = 32;

    function integer count_of(input [4:0] w, input [4:0] r);
        count_of = (w - r + PTRMOD) % PTRMOD;
    endfunction

    reg [4:0] wptr_prev;
    initial wptr_prev = 0;
    always @(posedge wclk) begin
        if (wrst && (wptr !== wptr_prev)) begin
            if (count_of(wptr_prev, rptr) >= 16)
                $display("*** ILLEGAL WRITE @ T=%0t : pre-count=%0d ***",
                         $time, count_of(wptr_prev, rptr));
            else
                $display("     good write @ T=%0t : wptr %0d -> %0d",
                         $time, wptr_prev, wptr);
            wptr_prev = wptr;
        end
    end

    reg [4:0] rptr_prev;
    initial rptr_prev = 0;
    always @(posedge rclk) begin
        if (rrst && (rptr !== rptr_prev)) begin
            if (count_of(wptr, rptr_prev) == 0)
                $display("*** ILLEGAL READ @ T=%0t : pre-count=0 ***", $time);
            else
                $display("     good read  @ T=%0t : rptr %0d -> %0d",
                         $time, rptr_prev, rptr);
            rptr_prev = rptr;
        end
    end
endmodule