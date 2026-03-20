# Uses the first jtag_debug service it finds to reset the system.  If no jtag
# debug services are found, display an error message
#
# This script relies on a JTAG to Avalon Master Bridge or Avalon-ST JTAG
# Interface component to be in the system to work.

proc reset_system { } {
  set jtag_debug_list [ get_service_paths jtag_debug ]
  if { [llength $jtag_debug_list] == 0 } {
    puts "No jtag_debug service path found.  System not reset"
    return
  }
  set jd [ lindex $jtag_debug_list 0 ]
  open_service jtag_debug $jd
  jtag_debug_reset_system $jd
  close_service jtag_debug $jd
  puts "System Reset!"
  unset jd jtag_debug_list
}
