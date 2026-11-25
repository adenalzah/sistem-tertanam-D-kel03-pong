-- =============================================================================
-- vga_fb.vhd -- Pengendali VGA 640x480 @60 Hz yang membaca framebuffer 160x120
--
-- Clock piksel 25 MHz (standar 25,175 MHz; 25 MHz diterima hampir semua monitor).
-- Setiap piksel framebuffer tampil sebagai kotak 4x4 piksel monitor.
-- Format warna 1 byte RGB332: bit 7..5 = merah, 4..2 = hijau, 1..0 = biru
--   0x00 = hitam, 0xFF = putih, 0xE0 = merah, 0x1C = hijau, 0x03 = biru
--
-- Timing horizontal : 640 tampil + 16 front porch + 96 sync + 48 back porch = 800
-- Timing vertikal   : 480 tampil + 10 front porch +  2 sync + 33 back porch = 525
-- Sinkronisasi aktif rendah.
-- Referensi: Harris & Harris RISC-V Ed. Bagian e9.4.2; Bruno Bab 9.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_fb is
  port (
    clk        : in  std_logic;                      -- 25 MHz
    rst        : in  std_logic;
    fb_addr    : out std_logic_vector(12 downto 0);  -- alamat word framebuffer
    fb_data    : in  std_logic_vector(31 downto 0);  -- data (latensi 1 siklus)
    vga_r      : out std_logic_vector(3 downto 0);
    vga_g      : out std_logic_vector(3 downto 0);
    vga_b      : out std_logic_vector(3 downto 0);
    vga_hs     : out std_logic;
    vga_vs     : out std_logic;
    vga_de     : out std_logic;                      -- area tampil (untuk simulasi)
    frame_tick : out std_logic                       -- pulsa 1 siklus di awal vblank
  );
end entity vga_fb;

architecture rtl of vga_fb is
  constant H_VIS : integer := 640;
  constant H_FP  : integer := 16;
  constant H_SY  : integer := 96;
  constant H_TOT : integer := 800;
  constant V_VIS : integer := 480;
  constant V_FP  : integer := 10;
  constant V_SY  : integer := 2;
  constant V_TOT : integer := 525;

  signal hc : unsigned(9 downto 0) := (others => '0');
  signal vc : unsigned(9 downto 0) := (others => '0');

  -- tahap 0: penghitung; tahap 1: data BRAM tersedia; tahap 2: keluaran register
  signal de0, hs0, vs0 : std_logic;
  signal de1, hs1, vs1 : std_logic := '0';
  signal lane1         : std_logic_vector(1 downto 0) := "00";
begin

  -- Penghitung horizontal & vertikal
  process (clk)
  begin
    if rising_edge(clk) then
      frame_tick <= '0';
      if rst = '1' then
        hc <= (others => '0');
        vc <= (others => '0');
      else
        if hc = H_TOT - 1 then
          hc <= (others => '0');
          if vc = V_TOT - 1 then
            vc <= (others => '0');
          else
            vc <= vc + 1;
          end if;
          if vc = V_VIS - 1 then
            frame_tick <= '1';        -- baris tampil terakhir selesai -> mulai vblank
          end if;
        else
          hc <= hc + 1;
        end if;
      end if;
    end if;
  end process;

  de0 <= '1' when hc < H_VIS and vc < V_VIS else '0';
  hs0 <= '0' when hc >= H_VIS + H_FP and hc < H_VIS + H_FP + H_SY else '1';
  vs0 <= '0' when vc >= V_VIS + V_FP and vc < V_VIS + V_FP + V_SY else '1';

  -- Alamat framebuffer: indeks = (vc/4)*160 + hc/4 ; word = indeks/4
  process (hc, vc)
    variable px  : unsigned(7 downto 0);
    variable py  : unsigned(6 downto 0);
    variable idx : unsigned(14 downto 0);
  begin
    px  := hc(9 downto 2);
    py  := vc(8 downto 2);
    idx := resize(py & "0000000", 15) + resize(py & "00000", 15) + resize(px, 15); -- py*128 + py*32 + px
    fb_addr <= std_logic_vector(idx(14 downto 2));
  end process;

  -- Pipeline: tunda sinyal sinkron sesuai latensi BRAM
  process (clk)
    variable pix : std_logic_vector(7 downto 0);
  begin
    if rising_edge(clk) then
      de1   <= de0;
      hs1   <= hs0;
      vs1   <= vs0;
      lane1 <= std_logic_vector(hc(3 downto 2));   -- px mod 4 = byte dalam word

      case lane1 is
        when "00"   => pix := fb_data(7 downto 0);
        when "01"   => pix := fb_data(15 downto 8);
        when "10"   => pix := fb_data(23 downto 16);
        when others => pix := fb_data(31 downto 24);
      end case;

      if de1 = '1' then
        vga_r <= pix(7 downto 5) & pix(7);
        vga_g <= pix(4 downto 2) & pix(4);
        vga_b <= pix(1 downto 0) & pix(1 downto 0);
      else
        vga_r <= (others => '0');
        vga_g <= (others => '0');
        vga_b <= (others => '0');
      end if;
      vga_hs <= hs1;
      vga_vs <= vs1;
      vga_de <= de1;
    end if;
  end process;

end architecture rtl;
