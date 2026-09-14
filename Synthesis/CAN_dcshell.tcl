set search_path [list . /fetools/work_area/frontend/SAED32_EDK/lib/stdcell_hvt/db_nldm]
set target_library [list saed32hvt_ss0p75v25c.db]
set link_library "* $target_library "
set designer "Tamil Selvan Elangovan"
set symbol_library
set synthetic_library

read_sverilog -rtl {MAINFSM.v APBDock.sv FIFO.v TXMachine.sv RXMachine.v TFF.v APBCDC.sv ErrorHandler.sv Prescaler.v Rengine.v bitstuffer.v CRC.v}
read_sdc CAN.sdc
link
check_design
write_file -format verilog -hier -out MAINFSM_unmapped.v
compile_ultra
write_file -format verilog -hier -out MAINFSM_mapped.v
write_file -format ddc -hier -out MAINFSM_mapped.ddc