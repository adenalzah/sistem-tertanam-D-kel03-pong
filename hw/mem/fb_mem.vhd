-- =============================================================================
-- fb_mem.vhd -- Framebuffer 160 x 120 piksel, 1 byte per piksel (RGB332)
--   Port A : CPU (baca/tulis, byte enable)
--   Port B : pengendali VGA (baca saja)
-- 19.200 byte = 4.800 word 32-bit (sekitar 5 Block RAM).
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rv_pkg.all;

entity fb_mem is
  port (
    clk    : in  std_logic;
    a_addr : in  std_logic_vector(12 downto 0);
    a_we   : in  std_logic_vector(3 downto 0);
    a_din  : in  std_logic_vector(31 downto 0);
    a_dout : out std_logic_vector(31 downto 0);
    b_addr : in  std_logic_vector(12 downto 0);
    b_dout : out std_logic_vector(31 downto 0)
  );
end entity fb_mem;

architecture rtl of fb_mem is
  shared variable ram : word_array_t(0 to FB_WORDS - 1) := (others => (others => '0'));
begin

  port_a : process (clk)
    variable idx : integer range 0 to 8191;
  begin
    if rising_edge(clk) then
      idx := to_integer(unsigned(a_addr));
      if idx < FB_WORDS then
        a_dout <= ram(idx);
        for i in 0 to 3 loop
          if a_we(i) = '1' then
            ram(idx)(8*i + 7 downto 8*i) := a_din(8*i + 7 downto 8*i);
          end if;
        end loop;
      else
        a_dout <= (others => '0');              -- di luar layar: abaikan
      end if;
    end if;
  end process;

  port_b : process (clk)
    variable idx : integer range 0 to 8191;
  begin
    if rising_edge(clk) then
      idx := to_integer(unsigned(b_addr));
      if idx < FB_WORDS then
        b_dout <= ram(idx);
      else
        b_dout <= (others => '0');
      end if;
    end if;
  end process;

end architecture rtl;
