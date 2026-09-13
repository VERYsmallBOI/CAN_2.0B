# APB Register Map

## Overview

| Offset (Dec) | Offset (Hex) | Register | Bits | Description |
| :--- | :--- | :--- | :--- | :--- |
| 0 | `0x00` | MODE / TIMING | `[31:27]` Reserved (0)<br>`[26:24]` SJW (3 bits)<br>`[23:20]` TPROP (4 bits, 1–8)<br>`[19:16]` TSEG2 (4 bits, 1–8)<br>`[15:12]` TSEG1 (4 bits, 1–8)<br>`[11:7]` BRP (5 bits, 0–31)<br>`[6:3]` Reserved (0)<br>`[2]` Loopback (1 = internal TX→RX)<br>`[1]` Listen-Only (1 = TX forced recessive)<br>`[0]` Soft Reset (1 = reset, 0 = run) | CAN Mode and Bus Timing Configuration |
| 4 | `0x04` | TXID | `[31:29]` Reserved (0)<br>`[28:0]` Identifier (29 bits) | 29-bit ID. For standard (11-bit), use bits `[10:0]`. |
| 8 | `0x08` | TXCTRL | `[31:6]` Reserved (0)<br>`[5]` RTR (1 = Remote Frame)<br>`[4]` IDE (1 = Extended Frame)<br>`[3:0]` DLC (0–8) | Frame control. DLC values 9–15 are reserved. |
| 12 | `0x0C` | TXDATAH | `[31:24]` Byte 7<br>`[23:16]` Byte 6<br>`[15:8]` Byte 5<br>`[7:0]` Byte 4 | Transmit data bytes 4–7 (LSB-first packing). |
| 16 | `0x10` | TXDATAL | `[31:24]` Byte 3<br>`[23:16]` Byte 2<br>`[15:8]` Byte 1<br>`[7:0]` Byte 0 | Transmit data bytes 0–3 (LSB-first packing). |
| 20 | `0x14` | TXREQ | `[31:1]` Reserved (0)<br>`[0]` Start | Write 1 to start transmission. Auto-clears to 0 when transmission starts. Poll `TXIDLE` (`STATUS[28]`) to know when frame is done. |
| 24 | `0x18` | RXFIFO_POP | `[31:1]` Reserved (0)<br>`[0]` Pop | Write 1 to pop the current frame from the RX FIFO. The next frame (if any) appears at `RXID`/`RXCTRL`/`RXDATA`. |
| 28 | `0x1C` | RXID | `[31:29]` Reserved (0)<br>`[28:0]` Identifier | Received ID (Read-only). |
| 32 | `0x20` | RXCTRL | `[31:6]` Reserved (0)<br>`[5]` RTR<br>`[4]` IDE<br>`[3:0]` DLC | Received frame control (Read-only). |
| 36 | `0x24` | RXDATAH | `[31:24]` Byte 7<br>`[23:16]` Byte 6<br>`[15:8]` Byte 5<br>`[7:0]` Byte 4 | Received data bytes 4–7 (Read-only). |
| 40 | `0x28` | RXDATAL | `[31:24]` Byte 3<br>`[23:16]` Byte 2<br>`[15:8]` Byte 1<br>`[7:0]` Byte 0 | Received data bytes 0–3 (Read-only). |
| 44 | `0x2C` | STATUS | See detailed table below | Unified Status + Counters + Interrupts. |

---

## STATUS Register (Offset 44 / 0x2C)

| Bit(s) | Name | Access | Description |
| :--- | :--- | :---: | :--- |
| 31 | BUSOFF | R | 1 = Node is in Bus-Off (TEC ≥ 256). |
| 30 | ERPASSIVE | R | 1 = Node is Error-Passive (TEC ≥ 128 or REC ≥ 128). |
| 29 | RXEMPTY | R | 0 = RX FIFO has at least one frame waiting (i.e., not empty). |
| 28 | TXIDLE | R | 1 = Transmitter is idle (no frame pending or in progress). |
| 27 | RESERVED | - | Read as 0. |
| 26 | RESERVED | - | Read as 0. |
| 25:17 | REC | R | Receive Error Counter (9 bits, 0–511). |
| 16:8 | TEC | R | Transmit Error Counter (9 bits, 0–511). |
| 7:0 | Reserved | - | Read as 0, write ignored. |
