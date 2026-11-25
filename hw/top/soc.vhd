-- =============================================================================
-- soc.vhd -- System-on-Chip game: inti RV32I + memori + periferal + bus MMIO
--
-- PETA MEMORI
--   0x0000_0000 - 0x0000_7FFF  Memori utama 32 KB (program, data, stack)
--   0x1000_0000 - 0x1000_4AFF  Framebuffer 160x120, 1 byte/piksel (RGB332)
--   0x2000_0000  BTN    (baca)  bit 0..4 = btnU, btnD, btnL, btnR, btnC
--   0x2000_0004  SW     (baca)  16 sakelar
--   0x2000_0008  LED    (tulis) 16 LED
--   0x2000_000C  SEG7   (tulis) 4 digit heksa di 7-segment
--   0x2000_0010  FRAME  (baca)  penghitung frame, naik 1 setiap vblank (60 Hz)
--   0x2000_0014  RAND   (baca)  angka acak 16 bit (LFSR berjalan bebas)
--   0x2000_0018  KEYEVT (baca)  event keyboard terakhir (lihat key_state.vhd)
--   0x2000_0100 - 0x2000_011C  KEYS (baca) 256 bit status tombol, 8 word
--   [PENGEMBANGAN] periferal baru: gunakan alamat 0x2000_0020 ke atas
--
-- Semua pembacaan bus berlatensi 1 siklus (seperti BRAM).
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rv_pkg.all;

entity soc is
  port (
    clk      : in  std_logic;                       -- 25 MHz
    rst      : in  std_logic;
    btn      : in  std_logic_vector(4 downto 0);    -- U D L R C (sudah disinkronkan)
    sw       : in  std_logic_vector(15 downto 0);
    led      : out std_logic_vector(15 downto 0);
    seg7_val : out std_logic_vector(15 downto 0);
    ps2_clk  : in  std_logic;
    ps2_data : in  std_logic;
    vga_r    : out std_logic_vector(3 downto 0);
    vga_g    : out std_logic_vector(3 downto 0);
    vga_b    : out std_logic_vector(3 downto 0);
    vga_hs   : out std_logic;
    vga_vs   : out std_logic;
    vga_de   : out std_logic;
    halted   : out std_logic
  );
end entity soc;

architecture rtl of soc is
  -- inti
  signal imem_addr, imem_rdata : std_logic_vector(31 downto 0);
  signal d_addr, d_wdata, d_rdata : std_logic_vector(31 downto 0);
  signal d_we  : std_logic_vector(3 downto 0);
  signal d_re  : std_logic;
  signal pc    : std_logic_vector(31 downto 0);

  -- dekoder alamat
  signal sel_main, sel_fb, sel_io : std_logic;
  signal rsel : std_logic_vector(1 downto 0) := "00";   -- sumber data baca (tertunda 1 siklus)
  signal main_we, fb_we : std_logic_vector(3 downto 0);
  signal main_dout, fb_dout : std_logic_vector(31 downto 0);
  signal io_dout : std_logic_vector(31 downto 0) := (others => '0');

  -- periferal
  signal fb_vaddr : std_logic_vector(12 downto 0);
  signal fb_vdata : std_logic_vector(31 downto 0);
  signal frame_tick : std_logic;
  signal frame_cnt  : unsigned(31 downto 0) := (others => '0');
  signal lfsr       : std_logic_vector(15 downto 0) := x"ACE1";
  signal led_reg, seg_reg : std_logic_vector(15 downto 0) := (others => '0');
  signal kcode : std_logic_vector(7 downto 0);
  signal kvalid : std_logic;
  signal keys : std_logic_vector(255 downto 0);
  signal kevt : std_logic_vector(31 downto 0);
begin

  -- ---------------------------------------------------------------------------
  -- Inti prosesor
  -- ---------------------------------------------------------------------------
  u_core : entity work.rv32i_core
    port map (clk => clk, rst => rst,
              imem_addr => imem_addr, imem_rdata => imem_rdata,
              dmem_addr => d_addr, dmem_wdata => d_wdata, dmem_we => d_we,
              dmem_re => d_re, dmem_rdata => d_rdata,
              halted => halted, pc_out => pc);

  -- ---------------------------------------------------------------------------
  -- Dekoder alamat (bit 31..28)
  -- ---------------------------------------------------------------------------
  sel_main <= '1' when d_addr(31 downto 28) = x"0" else '0';
  sel_fb   <= '1' when d_addr(31 downto 28) = x"1" else '0';
  sel_io   <= '1' when d_addr(31 downto 28) = x"2" else '0';

  main_we <= d_we when sel_main = '1' else "0000";
  fb_we   <= d_we when sel_fb   = '1' else "0000";

  -- ---------------------------------------------------------------------------
  -- Memori
  -- ---------------------------------------------------------------------------
  u_main : entity work.main_mem
    port map (clk => clk,
              a_addr => imem_addr(14 downto 2), a_dout => imem_rdata,
              b_addr => d_addr(14 downto 2), b_we => main_we,
              b_din => d_wdata, b_dout => main_dout);

  u_fb : entity work.fb_mem
    port map (clk => clk,
              a_addr => d_addr(14 downto 2), a_we => fb_we,
              a_din => d_wdata, a_dout => fb_dout,
              b_addr => fb_vaddr, b_dout => fb_vdata);

  -- ---------------------------------------------------------------------------
  -- Register I/O: tulis
  -- ---------------------------------------------------------------------------
  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        led_reg <= (others => '0');
        seg_reg <= (others => '0');
      elsif sel_io = '1' and d_we /= "0000" then
        case d_addr(11 downto 2) is
          when "0000000010" => led_reg <= d_wdata(15 downto 0);   -- 0x008
          when "0000000011" => seg_reg <= d_wdata(15 downto 0);   -- 0x00C
          when others => null;
        end case;
      end if;
    end if;
  end process;

  -- Register I/O: baca (latensi 1 siklus)
  process (clk)
    variable w : integer range 0 to 7;
  begin
    if rising_edge(clk) then
      io_dout <= (others => '0');
      if d_addr(8) = '1' then                                -- 0x100..0x11C: KEYS
        w := to_integer(unsigned(d_addr(4 downto 2)));
        io_dout <= keys(32*w + 31 downto 32*w);
      else
        case d_addr(7 downto 2) is
          when "000000" => io_dout(4 downto 0)  <= btn;               -- 0x000
          when "000001" => io_dout(15 downto 0) <= sw;                -- 0x004
          when "000010" => io_dout(15 downto 0) <= led_reg;           -- 0x008
          when "000011" => io_dout(15 downto 0) <= seg_reg;           -- 0x00C
          when "000100" => io_dout <= std_logic_vector(frame_cnt);    -- 0x010
          when "000101" => io_dout(15 downto 0) <= lfsr;              -- 0x014
          when "000110" => io_dout <= kevt;                           -- 0x018
          when others   => null;
        end case;
      end if;
      -- catat sumber data untuk siklus berikutnya
      if sel_fb = '1' then rsel <= "01";
      elsif sel_io = '1' then rsel <= "10";
      else rsel <= "00"; end if;
    end if;
  end process;

  with rsel select
    d_rdata <= fb_dout   when "01",
               io_dout   when "10",
               main_dout when others;

  -- ---------------------------------------------------------------------------
  -- Penghitung frame & LFSR (Galois, x^16 + x^14 + x^13 + x^11 + 1)
  -- ---------------------------------------------------------------------------
  process (clk)
  begin
    if rising_edge(clk) then
      if lfsr(0) = '1' then
        lfsr <= ('0' & lfsr(15 downto 1)) xor x"B400";
      else
        lfsr <= '0' & lfsr(15 downto 1);
      end if;
      if rst = '1' then
        frame_cnt <= (others => '0');
      elsif frame_tick = '1' then
        frame_cnt <= frame_cnt + 1;
      end if;
    end if;
  end process;

  -- ---------------------------------------------------------------------------
  -- Periferal
  -- ---------------------------------------------------------------------------
  u_vga : entity work.vga_fb
    port map (clk => clk, rst => rst, fb_addr => fb_vaddr, fb_data => fb_vdata,
              vga_r => vga_r, vga_g => vga_g, vga_b => vga_b,
              vga_hs => vga_hs, vga_vs => vga_vs, vga_de => vga_de,
              frame_tick => frame_tick);

  u_ps2 : entity work.ps2_rx
    port map (clk => clk, rst => rst, ps2_clk => ps2_clk, ps2_data => ps2_data,
              code => kcode, valid => kvalid);

  u_keys : entity work.key_state
    port map (clk => clk, rst => rst, code => kcode, valid => kvalid,
              keys => keys, last_evt => kevt);

  led      <= led_reg;
  seg7_val <= seg_reg;

end architecture rtl;
