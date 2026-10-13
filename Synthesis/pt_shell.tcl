set search_path [list . /fetools/work_area/frontend/SAED32_EDK/lib/stdcell_hvt/db_nldm]
set target_library [list saed32hvt_ss0p75v25c.db]
set link_library "* $target_library "
set designer "Tamil Selvan Elangovan"
read_ddc -netlist_only MAINFSM_mapped.ddc
#source CAn.sdc
report_global_timing
report_analysis_coverage -status_details untested
report_qor
report_port -v
report_clocks