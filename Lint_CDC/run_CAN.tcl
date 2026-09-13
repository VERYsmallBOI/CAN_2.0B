
read_file -type hdl MAINFSM.v APBDock.sv FIFO.v TXMachine.sv RXMachine.v TFF.v APBCDC.sv ErrorHandler.sv Prescaler.v Rengine.v bitstuffer.v CRC.v
read_file -type sgdc CAN.sgdc
read_file -type awl CAN.awl
set_option enableSV yes
current_design MAINFSM
current_goal Design_Read -alltop
run_goal
current_goal lint/lint_rtl -alltop
run_goal
write_report  moresimple
current_goal lint/lint_rtl_enhanced -alltop
run_goal
write_report  moresimple
current_goal cdc/cdc_verify -alltop
run_goal
write_report  moresimple
gui_start
