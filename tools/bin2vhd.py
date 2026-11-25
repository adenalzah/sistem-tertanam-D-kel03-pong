#!/usr/bin/env python3
"""
bin2vhd.py -- mengubah program biner RISC-V menjadi isi awal memori utama (VHDL)

Pemakaian:
    python3 tools/bin2vhd.py build/demo.bin hw/mem/program_init.vhd

Keluaran: package `program_init_pkg` berisi konstanta PROGRAM_INIT (8192 word).
Vivado memakai konstanta ini sebagai isi awal Block RAM, sehingga setelah
program diganti cukup jalankan ulang Synthesis/Generate Bitstream.
"""
import os
import sys

MAIN_WORDS = 8192          # 32 KB


def main():
    if len(sys.argv) != 3:
        sys.exit("pemakaian: bin2vhd.py <program.bin> <program_init.vhd>")
    src, dst = sys.argv[1], sys.argv[2]
    data = open(src, "rb").read()
    if len(data) > MAIN_WORDS * 4:
        sys.exit(f"program terlalu besar: {len(data)} byte (maks {MAIN_WORDS * 4})")
    data += b"\0" * (-len(data) % 4)
    words = [int.from_bytes(data[i:i + 4], "little") for i in range(0, len(data), 4)]

    lines = [
        "-- =============================================================================",
        f"-- program_init.vhd -- DIBANGKITKAN OTOMATIS oleh tools/bin2vhd.py dari {os.path.basename(src)}",
        "-- Jangan disunting manual. Jalankan `make rv APP=<nama>` untuk memperbarui.",
        f"-- Ukuran program: {len(data)} byte ({len(words)} word)",
        "-- =============================================================================",
        "library ieee;",
        "use ieee.std_logic_1164.all;",
        "use work.rv_pkg.all;",
        "",
        "package program_init_pkg is",
        "  constant PROGRAM_INIT : word_array_t(0 to MAIN_WORDS - 1) := (",
    ]
    for i, w in enumerate(words):
        lines.append(f"    {i} => x\"{w:08X}\",")
    lines += [
        "    others => x\"00000000\"",
        "  );",
        "end package program_init_pkg;",
        "",
    ]
    with open(dst, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"{dst}: {len(data)} byte program ({100 * len(data) // (MAIN_WORDS * 4)}% dari 32 KB)")


if __name__ == "__main__":
    main()
