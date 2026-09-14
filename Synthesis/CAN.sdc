#16MHz for CAN_CLK and 64 MHz for PCLK
create_clock -period 62.5 [get_ports CAN_CLK]
create_clock -period 15.625 [get_ports PCLK]
#same values are used cos they are the same chip and most likely the can osc is actaully near to the chip instead of cpu
set_clock_latency -source 4 [get_ports CAN_CLK]
set_clock_latency -source 4  [get_ports PCLK]
set_clock_latency 0.5 [get_ports PCLK]
set_clock_latency 0.8 [get_ports CAN_CLK]
set_clock_transition 0.150 PCLK
set_clock_transition 0.200 CAN_CLK
#uncertainities
set_clock_uncertainty 0.1 [get_ports PCLK]
set_clock_uncertainty 0.2 [get_ports CAN_CLK]
#logic delays
set_input_delay 5 -clock PCLK [get_ports {PSEL PENABLE PWRITE PADDR PWDATA}]
set_output_delay 5 -clock PCLK [get_ports {PREADY PSLVERR PRDATA}]
#as interrupts will be used by PCLK domain 
set_output_delay 5 -clock PCLK [get_ports {done_RXs done_TXs}]
set_output_delay 15 -clock CAN_CLK [get_ports {TX}]
#need to be more strict on TX cos its going to be  input to long distance nodes
#path definition
set_clock_groups -asynchronous -group PCLK -group CAN_CLK
#false paths
set_false_path -from [get_ports RX]
set_false_path -from [get_ports CAN_RST]
set_false_path -from [get_ports PRESETn]

#real worldness but TBD
#both of them doesnt actually have to do that much there are intruupt and TX is for transciever (analog cell)
set_load 3 [get_ports {done_RXs done_TXs}]
set_load 10 [get_ports {TX}]
set_load 3.0 [get_ports {PREADY PSLVERR PRDATA}]
set_max_transition 0.5 [get_ports {TX done_RXs done_TXs}]
set_max_transition 0.3 [get_ports {PREADY PSLVERR PRDATA}]
