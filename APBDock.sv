module APBDock (
    input             PCLK,
    input             PRESETn,
    input             PSEL,
    input             PENABLE,
    input             PWRITE,
    input      [ 5:0] PADDR,       // 0 to 44
    output reg        PREADY,
    output reg        PSLVERR,
    output reg [31:0] PRDATA,
    input      [31:0] PWDATA,
    input             empty_fifo,  // from FIFO So syncronized (read side)
    output reg [31:0] TXBUFFER,    // Hand shake data signal
    output reg        change,      // Hand shake signal
    input             done_HS,     // Hand shake signal
    input      [31:8] STATUS_F,    // from can domain (syncronized)
    input      [98:0] FIFO_READ,
    output reg        rd_cmd,      // read_pop
    output reg [ 4:0] PWADDR
);

  reg [7:0] REGBANK [28:43];  // 5 registers for reading, index = PADDR/4
  reg       sample_en;
  reg [5:0] PADDRr;           // registered version
  reg       PWRITEr, PSLVERRr, PREADYr;
  reg [31:0] PWDATAr;
  reg        write_en, read_en;  // for enabling write and read in apb
  reg        rd_cmd_r;
  reg        changer;

  always @(posedge PCLK or negedge PRESETn) begin
    if (~PRESETn) begin
      PREADY      <= 0;
      REGBANK[28] <= 0;
      REGBANK[29] <= 0;
      REGBANK[30] <= 0;
      REGBANK[31] <= 0;
      REGBANK[32] <= 0;
      REGBANK[33] <= 0;
      REGBANK[34] <= 0;
      REGBANK[35] <= 0;
      REGBANK[36] <= 0;
      REGBANK[37] <= 0;
      REGBANK[38] <= 0;
      REGBANK[39] <= 0;
      REGBANK[40] <= 0;
      REGBANK[41] <= 0;
      REGBANK[42] <= 0;
      REGBANK[43] <= 0;
      change      <= 0;
      rd_cmd      <= 0;
      PWADDR      <= 0;
      PADDRr      <= 0;
      PWDATAr     <= 0;
      TXBUFFER    <= 0;
      PRDATA      <= 0;
      PWRITEr     <=0;
      PSLVERR     <=0;
       rd_cmd_r<=0;
    end else begin
      if (sample_en) begin
        PADDRr  <= PADDR;
        PWRITEr <= PWRITE;
        PWDATAr <= PWDATA;
      end

      PREADY  <= PREADYr;
      change  <= changer;
      PSLVERR <= PSLVERRr;

      if (~empty_fifo) begin
        // read from FIFO_READ

// ============================================================
        // RXID @ 28-31
        // [31:29] = 0
        // [28:0]  = Identifier
        // ============================================================
        REGBANK[28] <= FIFO_READ[75:68];            // RXID[7:0]
        REGBANK[29] <= FIFO_READ[83:76];            // RXID[15:8]
        REGBANK[30] <= FIFO_READ[91:84];            // RXID[23:16]
        REGBANK[31] <= {3'b000, FIFO_READ[96:92]};  // RXID[31:24]

        // ============================================================
        // RXCTRL @ 32-35
        // [31:6] = 0
        // [5]    = RTR
        // [4]    = IDE
        // [3:0]  = DLC
        // ============================================================
        REGBANK[32] <= {2'b00, FIFO_READ[97], FIFO_READ[98], FIFO_READ[3:0]};
        REGBANK[33] <= 8'h00;
        REGBANK[34] <= 8'h00;
        REGBANK[35] <= 8'h00;

        // ============================================================
        // RXDATAH @ 36-39
        // [31:24] = Byte7
        // [23:16] = Byte6
        // [15:8]  = Byte5
        // [7:0]   = Byte4
        // ============================================================
        REGBANK[36] <= FIFO_READ[43:36];  // Byte4 = DATA[39:32]
        REGBANK[37] <= FIFO_READ[51:44];  // Byte5 = DATA[47:40]
        REGBANK[38] <= FIFO_READ[59:52];  // Byte6 = DATA[55:48]
        REGBANK[39] <= FIFO_READ[67:60];  // Byte7 = DATA[63:56]

        // ============================================================
        // RXDATAL @ 40-43
        // [31:24] = Byte3
        // [23:16] = Byte2
        // [15:8]  = Byte1
        // [7:0]   = Byte0
        // ============================================================
        REGBANK[40] <= FIFO_READ[11:4];   // Byte0 = DATA[7:0]
        REGBANK[41] <= FIFO_READ[19:12];  // Byte1 = DATA[15:8]
        REGBANK[42] <= FIFO_READ[27:20];  // Byte2 = DATA[23:16]
        REGBANK[43] <= FIFO_READ[35:28];  // Byte3 = DATA[31:24]
      end
      rd_cmd_r<=(~change&&(PADDRr==24));
      if (~rd_cmd_r) begin
        rd_cmd <= PWDATA[0]&&(~change&&(PADDRr==24));
      end else begin
        rd_cmd <= 0;
      end

      if (PWRITEr && write_en) begin  // write
        // change <= done_HS ? : ; // pending on what values to be sent as HS
        TXBUFFER <= PWDATAr;
        PWADDR   <= PADDRr[4:0];
      end else if (PWRITEr == 0 && read_en) begin  // read
        if (PADDRr == 44) begin
          PRDATA <= {STATUS_F, 8'b0};
        end else begin
          PRDATA <=  {
            REGBANK[6'(PADDRr + 3)],
            REGBANK[6'(PADDRr + 2)],
            REGBANK[6'(PADDRr + 1)],
            REGBANK[PADDRr]
          };
        end
      end
    end
  end

  always @(*) begin
    if (PSEL) begin  // chip selected
      if (!PENABLE) begin  // setup
        sample_en = 1;
        if (PWRITE) begin  // write
          changer  = 0;
          PSLVERRr = 0;
          PREADYr  = 0;  // if more end transaction here
          write_en = 0;
          read_en  = 0;
        end else begin  // read
          // changer = (PADDR > 6'h14 && PADDR < 6'h2D) ? 1 : 0;
          changer  = 0;
          PSLVERRr = 0;
          PREADYr  = 0;  // if more end transaction here
          write_en = 0;
          read_en  = 0;
        end
      end else begin  // access
        sample_en = 0;
        if (PWRITE) begin  // write
        if(PADDRr<=24)begin
          PREADYr=((change?done_HS:0)||PREADY||(PADDRr==24));
          PSLVERRr=0;
          write_en=~change&&(PADDRr!=24);
          changer=change?~done_HS:~(PADDRr==24);
          read_en = 0;
        end
        else begin
          read_en=0;
          PSLVERRr=1;
          PREADYr=1;
          write_en=0;
          changer=0;
        end
        end else begin  // read
          PREADYr  = ((PADDRr == 44) ? 1 : ~empty_fifo) || PREADY;     // if checking status direclty give ouput else wait untl fifo go non empry
          PSLVERRr = (PADDRr < 28 || PADDRr > 44);                     // btw the range of read
          write_en = 0;
          read_en  = (~empty_fifo && (PADDRr >= 28 && PADDRr <= 40)) || (PADDRr == 44);  // status reg is continouts flowing
          // PREADY && (~empty_fifo || PADDR == 'h2C);
          changer  = 0;
        end
      end
    end else begin
      read_en   = 0;
      write_en  = 0;
      PSLVERRr  = 0;
      changer   = 0;
      PREADYr   = 0;
      sample_en = 0;
    end
  end

endmodule

// vbusy will be based on the read and empty fifo