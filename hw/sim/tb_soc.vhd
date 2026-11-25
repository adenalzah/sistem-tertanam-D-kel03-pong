-- =============================================================================
-- tb_soc.vhd -- Testbench SoC dengan "kamera" VGA
--
-- 1. Menjalankan program di hw/mem/program_init.vhd pada inti RV32I.
-- 2. Mengirim penekanan tombol W lewat protokol PS/2 (seperti keyboard asli).
-- 3. Merekam keluaran VGA pada frame ke-CAPTURE_FRAME dan menyimpannya ke
--    frame.ppm (160x120, satu sampel per kotak 4x4) -> lihat dengan
--    `python3 tools/ppm2png.py build/frame.ppm build/frame.png`.
--
-- Jalankan lewat `make sim APP=demo FRAMES=3`.
-- Satu frame = 16,8 ms waktu simulasi (sekitar 420.000 siklus clock).
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb_soc is
  generic (
    CAPTURE_FRAME : integer := 3;
    PRESS_KEY     : integer := 16#1D#     -- scancode tombol W
  );
end entity tb_soc;

architecture sim of tb_soc is
  constant TCLK : time := 40 ns;           -- 25 MHz

  signal clk      : std_logic := '0';
  signal rst      : std_logic := '1';
  signal ps2_clk  : std_logic := '1';
  signal ps2_data : std_logic := '1';
  signal vga_r, vga_g, vga_b : std_logic_vector(3 downto 0);
  signal vga_hs, vga_vs, vga_de, halted : std_logic;
  signal led, seg7 : std_logic_vector(15 downto 0);
  signal done : boolean := false;

  type img_t is array (0 to 160 * 120 - 1) of std_logic_vector(11 downto 0);
begin

  clk <= not clk after TCLK / 2 when not done;

  dut : entity work.soc
    port map (clk => clk, rst => rst, btn => "00000", sw => x"0000",
              led => led, seg7_val => seg7, ps2_clk => ps2_clk, ps2_data => ps2_data,
              vga_r => vga_r, vga_g => vga_g, vga_b => vga_b,
              vga_hs => vga_hs, vga_vs => vga_vs, vga_de => vga_de, halted => halted);

  -- reset
  process
  begin
    rst <= '1';
    wait for 10 * TCLK;
    wait until rising_edge(clk);
    rst <= '0';
    wait;
  end process;

  -- keyboard PS/2: kirim kode tekan (tanpa lepas) setelah 2 ms
  keyboard : process
    procedure send_byte(b : std_logic_vector(7 downto 0)) is
      variable frame : std_logic_vector(10 downto 0);
      variable par   : std_logic := '1';
    begin
      for i in 0 to 7 loop par := par xor b(i); end loop;
      frame := '1' & par & b & '0';          -- stop, paritas, data, start
      for i in 0 to 10 loop
        ps2_data <= frame(i);
        wait for 20 us;
        ps2_clk <= '0';                      -- keyboard menurunkan clock: data dibaca
        wait for 40 us;
        ps2_clk <= '1';
        wait for 20 us;
      end loop;
      ps2_data <= '1';
      wait for 200 us;
    end procedure;
  begin
    wait for 2 ms;
    if PRESS_KEY >= 16#80# then
      send_byte(x"E0");
      send_byte(std_logic_vector(to_unsigned(PRESS_KEY - 16#80#, 8)));
    else
      send_byte(std_logic_vector(to_unsigned(PRESS_KEY, 8)));
    end if;
    report "tb_soc: tombol dikirim lewat PS/2, scancode " & integer'image(PRESS_KEY) severity note;
    wait;
  end process;

  -- kamera VGA
  camera : process
    variable img   : img_t;
    variable frame : integer := 0;
    variable px, py : integer := 0;
    variable vs_prev : std_logic := '1';
    file f : text;
    variable l : line;
    variable c : std_logic_vector(11 downto 0);
    variable warned : boolean := false;
  begin
    loop
      wait until rising_edge(clk);
      if vs_prev = '1' and vga_vs = '0' then      -- awal sinkron vertikal
        frame := frame + 1;
        px := 0; py := 0;
        report "tb_soc: frame " & integer'image(frame) & " selesai" severity note;
        exit when frame > CAPTURE_FRAME;
      end if;
      vs_prev := vga_vs;
      if vga_de = '1' then
        if frame = CAPTURE_FRAME and (px mod 4) = 0 and (py mod 4) = 0 then
          img((py / 4) * 160 + px / 4) := vga_r & vga_g & vga_b;
        end if;
        px := px + 1;
        if px = 640 then px := 0; py := py + 1; end if;
      end if;
      if halted = '1' and not warned then
        warned := true;
        report "tb_soc: PROSESOR BERHENTI (instruksi tak dikenal / ecall)" severity warning;
      end if;
    end loop;

    file_open(f, "frame.ppm", write_mode);
    write(l, string'("P3")); writeline(f, l);
    write(l, string'("160 120")); writeline(f, l);
    write(l, string'("15")); writeline(f, l);
    for i in 0 to 160 * 120 - 1 loop
      c := img(i);
      write(l, integer'image(to_integer(unsigned(c(11 downto 8)))) & " " &
               integer'image(to_integer(unsigned(c(7 downto 4)))) & " " &
               integer'image(to_integer(unsigned(c(3 downto 0)))));
      writeline(f, l);
    end loop;
    file_close(f);
    report "tb_soc: frame " & integer'image(CAPTURE_FRAME) &
           " disimpan ke frame.ppm, 7-segment = " &
           integer'image(to_integer(unsigned(seg7))) severity note;
    done <= true;
    wait;
  end process;

end architecture sim;
