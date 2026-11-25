-- =============================================================================
-- top_basys3.vhd -- Top-level untuk Digilent Basys 3
--
-- Clock 100 MHz -> MMCM -> 25 MHz (clock inti dan clock piksel VGA)
-- SW15 = 1  -> prosesor ditahan reset (turunkan SW15 untuk menjalankan)
-- LED15     -> menyala bila prosesor berhenti (instruksi tak dikenal/ecall)
-- Tombol btnU/D/L/R/C dan SW14..0 dapat dibaca program.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

entity top_basys3 is
  port (
    clk      : in  std_logic;
    btnU     : in  std_logic;
    btnD     : in  std_logic;
    btnL     : in  std_logic;
    btnR     : in  std_logic;
    btnC     : in  std_logic;
    sw       : in  std_logic_vector(15 downto 0);
    led      : out std_logic_vector(15 downto 0);
    seg      : out std_logic_vector(6 downto 0);
    dp       : out std_logic;
    an       : out std_logic_vector(3 downto 0);
    vgaRed   : out std_logic_vector(3 downto 0);
    vgaGreen : out std_logic_vector(3 downto 0);
    vgaBlue  : out std_logic_vector(3 downto 0);
    Hsync    : out std_logic;
    Vsync    : out std_logic;
    PS2Clk   : in  std_logic;
    PS2Data  : in  std_logic
  );
end entity top_basys3;

architecture rtl of top_basys3 is
  signal clk_fb, clk25_unbuf, clk25, locked : std_logic;
  signal rst_sync : std_logic_vector(1 downto 0) := "11";
  signal rst      : std_logic;
  signal btn_s1, btn_s2 : std_logic_vector(4 downto 0) := (others => '0');
  signal sw_s1, sw_s2   : std_logic_vector(15 downto 0) := (others => '0');
  signal led_i    : std_logic_vector(15 downto 0);
  signal seg7_val : std_logic_vector(15 downto 0);
  signal halted, de : std_logic;
begin

  -- 100 MHz x 8 = 800 MHz (VCO) / 32 = 25 MHz
  u_mmcm : MMCME2_BASE
    generic map (CLKIN1_PERIOD => 10.0, CLKFBOUT_MULT_F => 8.0,
                 CLKOUT0_DIVIDE_F => 32.0, DIVCLK_DIVIDE => 1)
    port map (CLKIN1 => clk, CLKFBIN => clk_fb, CLKFBOUT => clk_fb,
              CLKOUT0 => clk25_unbuf, LOCKED => locked, PWRDWN => '0', RST => '0');

  u_bufg : BUFG port map (I => clk25_unbuf, O => clk25);

  -- sinkronisasi reset, tombol, dan sakelar ke domain 25 MHz
  process (clk25)
  begin
    if rising_edge(clk25) then
      rst_sync <= rst_sync(0) & (sw(15) or not locked);
      btn_s1   <= btnC & btnR & btnL & btnD & btnU;
      btn_s2   <= btn_s1;
      sw_s1    <= sw;
      sw_s2    <= sw_s1;
    end if;
  end process;
  rst <= rst_sync(1);

  u_soc : entity work.soc
    port map (clk => clk25, rst => rst, btn => btn_s2, sw => sw_s2,
              led => led_i, seg7_val => seg7_val,
              ps2_clk => PS2Clk, ps2_data => PS2Data,
              vga_r => vgaRed, vga_g => vgaGreen, vga_b => vgaBlue,
              vga_hs => Hsync, vga_vs => Vsync, vga_de => de,
              halted => halted);

  u_seg : entity work.seg7_hex
    port map (clk => clk25, value => seg7_val, seg => seg, an => an);

  dp  <= '1';
  led <= halted & led_i(14 downto 0);

end architecture rtl;
