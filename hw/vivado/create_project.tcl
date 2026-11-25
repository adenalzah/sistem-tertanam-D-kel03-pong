# =============================================================================
# create_project.tcl -- membuat proyek Vivado RV32 Game Kit secara otomatis
#
# Cara pakai (Vivado 2026.1):
#   1. Buka Vivado -> menu Window -> Tcl Console
#   2. Ketik (sesuaikan lokasi folder repositori; gunakan garis miring /):
#        cd C:/Users/nama/rv32-game-kit
#        source hw/vivado/create_project.tcl
#   Proyek dibuat di build/vivado/rv32_game_kit.xpr
#
# File sumber TIDAK disalin ke dalam proyek, sehingga setelah `make rv`
# memperbarui hw/mem/program_init.vhd, Vivado otomatis memakai versi terbaru.
# =============================================================================
set root     [file normalize [file join [file dirname [info script]] .. ..]]
set proj_dir [file join $root build vivado]

create_project rv32_game_kit $proj_dir -part xc7a35tcpg236-1 -force
set_property target_language VHDL [current_project]
set_property simulator_language VHDL [current_project]

add_files -norecurse [concat \
    [glob $root/hw/core/*.vhd] \
    [glob $root/hw/mem/*.vhd] \
    [glob $root/hw/periph/*.vhd] \
    [glob $root/hw/top/*.vhd]]
add_files -fileset constrs_1 -norecurse $root/hw/top/basys3.xdc
add_files -fileset sim_1 -norecurse $root/hw/sim/tb_soc.vhd

set_property top top_basys3 [current_fileset]
set_property top tb_soc [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]
update_compile_order -fileset sources_1

puts "Proyek dibuat: $proj_dir/rv32_game_kit.xpr"
puts "Langkah berikutnya: Generate Bitstream, lalu Open Hardware Manager -> Program Device."
puts "Atau jalankan: source hw/vivado/build_bitstream.tcl"
