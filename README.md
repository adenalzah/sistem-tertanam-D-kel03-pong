# RV32 Game Kit — Game 2D pada Prosesor RISC-V di FPGA Basys 3

Kit awal Proyek Akhir **Sistem Tertanam**, Sarjana Terapan Teknik Elektronika FV UNY,
semester gasal 2026/2027. Dosen pengampu: Faris Yusuf Baktiar, M.Cs.

Kit ini berisi **SoC RISC-V lengkap** (prosesor RV32I, memori, VGA, keyboard PS/2,
7-segment) dan **pustaka C** untuk membuat game. Semua bagian sudah diuji di
simulasi. Tugas kelompok: membuat game di `sw/game/game.c`, mengembangkan
antarmukanya, dan mengerjakan satu tugas hardware RISC-V.

---

## 1. Struktur folder

```
rv32-game-kit/
├── hw/                         Hardware (VHDL)
│   ├── core/                   rv_pkg, alu, regfile, rv32i_core (prosesor)
│   ├── mem/                    main_mem (32 KB), fb_mem (framebuffer), program_init (otomatis)
│   ├── periph/                 vga_fb, ps2_rx, key_state, seg7_hex
│   ├── top/                    soc (bus MMIO), top_basys3, basys3.xdc
│   ├── sim/                    tb_soc (testbench + "kamera" VGA)
│   └── vivado/                 create_project.tcl, build_bitstream.tcl
├── sw/                         Software (C)
│   ├── common/                 hal.h, keys.h, gfx.c, font.h, libmini.c, crt0.S, link.ld
│   ├── hal_rv.c                HAL untuk FPGA (memory-mapped I/O)
│   ├── hal_pc.c                HAL untuk laptop (SDL2)
│   ├── demo/                   demo bola memantul + uji keyboard
│   ├── selftest/               uji instruksi prosesor
│   └── game/                   KERANGKA GAME — diisi kelompok
├── tools/                      bin2vhd.py, ppm2png.py, gen_font.py
├── release/                    bitstream & laporan Vivado untuk pengumpulan
└── Makefile
```

## 2. Mulai cepat

Semua perintah dijalankan dari folder repositori (Windows: terminal **MSYS2 UCRT64**).

### a. Jalankan di laptop (paling cepat untuk mengembangkan game)

```bash
make pc                 # demo
make pc APP=selftest    # uji prosesor versi PC
make pc APP=game        # game kelompok
```

Muncul jendela 640×480. Tekan **F12** untuk menyimpan tangkapan layar `screenshot.ppm`
(ubah ke PNG: `python3 tools/ppm2png.py screenshot.ppm screenshot.png`).

### b. Jalankan di FPGA Basys 3

1. Compile program untuk RISC-V:
   ```bash
   make rv APP=demo
   ```
   Perintah ini menulis `hw/mem/program_init.vhd` (isi awal memori) dan
   `build/demo.lst` (hasil disassembly — berguna untuk laporan).
   Pengguna Ubuntu yang memakai compiler dari apt: `make rv CROSS=riscv64-unknown-elf-`.
2. **Sekali saja**, buat proyek Vivado. Di Vivado 2026.1 buka *Window → Tcl Console*:
   ```tcl
   cd C:/lokasi/rv32-game-kit
   source hw/vivado/create_project.tcl
   ```
3. Klik **Generate Bitstream** (atau `source hw/vivado/build_bitstream.tcl`, yang juga
   menyalin bitstream dan laporan pemakaian sumber daya ke `release/`).
4. *Open Hardware Manager → Auto Connect → Program Device*.
5. Pastikan **SW15 di posisi bawah** (SW15 atas = prosesor ditahan reset).

Setiap kali kode C berubah: ulangi `make rv`, lalu Generate Bitstream lagi.

### c. Simulasi (opsional, butuh GHDL)

```bash
make sim APP=demo FRAMES=3
```

Testbench menjalankan program di prosesor, mengirim tombol **W** lewat protokol PS/2,
lalu menyimpan tampilan VGA frame ke-3 sebagai `build/frame.png`. Simulasi juga bisa
dijalankan di Vivado (*Run Simulation*, top `tb_soc`); satu frame = 16,8 ms waktu simulasi.

## 3. Kontrol di board

| Kontrol | Fungsi |
| --- | --- |
| SW15 | atas = reset, bawah = jalan |
| btnU / btnD / btnL / btnR | sama dengan tombol panah keyboard |
| btnC | sama dengan Enter dan Spasi |
| LED15 | menyala bila prosesor berhenti (instruksi tak dikenal / `ecall`) |
| 7-segment | diatur program (`score_show`, `seg7_hex`) |
| Port USB (J2) | keyboard |
| Port VGA | monitor |

## 4. Peta memori

| Alamat | Isi | Akses |
| --- | --- | --- |
| `0x0000_0000`–`0x0000_7FFF` | Memori utama 32 KB: program, data, stack | baca/tulis |
| `0x1000_0000`–`0x1000_4AFF` | Framebuffer 160×120, 1 byte/piksel RGB332 | baca/tulis |
| `0x2000_0000` | BTN: bit 0–4 = U, D, L, R, C | baca |
| `0x2000_0004` | SW: 16 sakelar | baca |
| `0x2000_0008` | LED: 16 LED | tulis |
| `0x2000_000C` | SEG7: 4 digit heksa | tulis |
| `0x2000_0010` | FRAME: naik 1 setiap frame (60 Hz) | baca |
| `0x2000_0014` | RAND: LFSR 16 bit | baca |
| `0x2000_0018` | KEYEVT: event keyboard terakhir | baca |
| `0x2000_0100`–`0x2000_011C` | KEYS: 256 bit status tombol | baca |

Piksel (x, y) berada di `0x1000_0000 + y*160 + x`. Warna RGB332: `rrrgggbb`
(0x00 hitam, 0xFF putih, 0xE0 merah, 0x1C hijau, 0x03 biru).

## 5. Fungsi HAL (`sw/common/hal.h`)

| Fungsi | Keterangan |
| --- | --- |
| `hal_init()` | panggil sekali di awal `main()` |
| `wait_vsync()` | tunggu frame berikutnya (60 FPS) dan perbarui status tombol |
| `frame_count()`, `rand16()` | penghitung frame, angka acak 0–65535 |
| `fb_clear(c)`, `fb_pixel(x,y,c)`, `fb_get(x,y)` | layar dan piksel |
| `fb_rect(x,y,w,h,c)`, `fb_frame(x,y,w,h,c)` | kotak terisi dan garis tepi |
| `fb_sprite(x,y,rows,w,h,c)` | gambar 1 bit (lebar ≤ 8) |
| `fb_text(x,y,s,c)`, `fb_text_big(x,y,s,c,skala)` | teks font 3×5 (sel 4×6) |
| `fb_text_width(s,skala)` | lebar teks, untuk menengahkan judul |
| `fb_number(x,y,n,c)`, `fb_hex(x,y,v,digit,c)` | angka desimal / heksa |
| `key_down(k)` | 1 selama tombol ditekan (`KEY_W`, `KEY_UP`, …, lihat `keys.h`) |
| `key_pressed(k)` | 1 hanya pada frame tombol mulai ditekan (untuk menu) |
| `score_show(a,b)` | dua skor desimal 0–99 di 7-segment |
| `led_set(v)`, `sw_read()`, `seg7_hex(v)` | LED, sakelar, 7-segment heksa |

## 6. Tips membuat game

- **Kembangkan di laptop dulu** (`make pc APP=game`), baru uji di board.
- **Jangan `fb_clear()` setiap frame.** Framebuffer langsung tampil ke monitor, jadi
  menghapus seluruh layar membuat gambar berkedip. Hapus objek di posisi lamanya,
  lalu gambar di posisi baru (lihat `sw/demo/demo.c`).
- **RV32I tidak punya instruksi kali/bagi.** `*`, `/`, `%` dengan variabel dihitung oleh
  `libmini.c` (lambat). Gunakan geser (`x << 2` = `x * 4`) bila bisa.
  Perkalian dengan konstanta (mis. `y * 160`) sudah diubah compiler menjadi geser.
- Gunakan **fixed-point** untuk gerak halus: simpan posisi ×16, tampilkan `pos >> 4`.
- Tidak ada `printf`, `malloc`, atau pustaka standar C. Gunakan array statis.
- Batas memori: program + data maksimum ~28 KB (4 KB untuk stack).

## 7. Titik pengembangan hardware

Cari komentar `[PENGEMBANGAN]` di kode VHDL:

| Tugas | File yang diubah |
| --- | --- |
| Ekstensi M (`mul`, `div`, `rem`) | `rv_pkg.vhd`, `alu.vhd`, `rv32i_core.vhd`; compile dengan `make rv MARCH=rv32im`; uji dengan `APP=selftest` |
| Periferal baru (suara PWM, timer) | `soc.vhd` (alamat `0x2000_0020` ke atas), `top_basys3.vhd`, `basys3.xdc`, `hal.h`, `hal_rv.c`, `hal_pc.c` |
| Instruksi kustom | opcode `OPC_CUSTOM0` di `rv32i_core.vhd`; panggil dari C dengan `asm volatile(".insn r 0x0B, ...")` |
| Framebuffer 1 bit/piksel atau double buffer | `fb_mem.vhd`, `vga_fb.vhd`, `gfx.c` |

## 8. Mengatasi masalah

| Gejala | Penyebab / solusi |
| --- | --- |
| Layar hitam, LED15 mati | SW15 masih di atas (reset). Turunkan SW15. |
| LED15 menyala | Prosesor menemui instruksi tak dikenal. Periksa `MARCH` (harus `rv32i` kecuali ekstensi M sudah dibuat). |
| Monitor "No signal" | Periksa kabel VGA; coba monitor lain. |
| Tombol tidak terbaca di board | Keyboard tidak kompatibel dengan chip USB→PS/2 Basys 3. Lihat angka EVENT di demo: bila tidak berubah saat ditekan, ganti keyboard (keyboard sederhana/lama lebih mudah dikenali). Tombol board tetap bisa dipakai. |
| `riscv-none-elf-gcc: command not found` | Folder `bin` xPack belum masuk PATH (lihat jobsheet). |
| `sdl2-config: command not found` | Windows: gunakan terminal **MSYS2 UCRT64**, bukan MSYS. Linux: `sudo apt install libsdl2-dev`. |
| Program terlalu besar | Pesan dari linker: kurangi data/array besar. |

## 9. Referensi

- S. Harris & D. Harris, *Digital Design and Computer Architecture: RISC-V Edition*, 2021 (Bab 6, 7, 9).
- F. Bruno, *FPGA Programming for Beginners*, 2021 (Bab 9 VGA, Bab 10 keyboard).
- Digilent, *Basys 3 Reference Manual*.
