# =============================================================================
# build_bitstream.tcl -- sintesis, implementasi, bitstream, dan laporan
#
# Jalankan di Tcl Console Vivado setelah create_project.tcl:
#   source hw/vivado/build_bitstream.tcl
# Hasil:
#   release/rv32_game.bit             bitstream untuk Program Device
#   release/utilization.txt           pemakaian LUT, FF, BRAM, DSP (untuk laporan)
#   release/timing_summary.txt        WNS dan ringkasan timing (untuk laporan)
# =============================================================================
set root [file normalize [file join [file dirname [info script]] .. ..]]
set xpr  [file join $root build vivado rv32_game_kit.xpr]

if {[catch {current_project}]} { open_project $xpr }

reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    error "Implementasi gagal. Periksa pesan di jendela Messages."
}

file mkdir [file join $root release]
open_run impl_1
report_utilization    -file [file join $root release utilization.txt]
report_timing_summary -file [file join $root release timing_summary.txt]
set bit [glob [file join $root build vivado rv32_game_kit.runs impl_1 *.bit]]
file copy -force $bit [file join $root release rv32_game.bit]
puts "Bitstream: [file join $root release rv32_game.bit]"
