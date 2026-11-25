-- =============================================================================
-- seg7_hex.vhd -- Penggerak 4 digit 7-segment Basys 3 (multipleks, heksadesimal)
-- Segmen dan anoda aktif rendah. seg(0) = a ... seg(6) = g
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity seg7_hex is
  port (
    clk   : in  std_logic;                       -- 25 MHz
    value : in  std_logic_vector(15 downto 0);
    seg   : out std_logic_vector(6 downto 0);
    an    : out std_logic_vector(3 downto 0)
  );
end entity seg7_hex;

architecture rtl of seg7_hex is
  signal cnt   : unsigned(17 downto 0) := (others => '0');
  signal digit : std_logic_vector(1 downto 0);
  signal nib   : std_logic_vector(3 downto 0);
begin
  process (clk)
  begin
    if rising_edge(clk) then
      cnt <= cnt + 1;               -- 25 MHz / 2^16 = ~381 Hz per digit
    end if;
  end process;

  digit <= std_logic_vector(cnt(17 downto 16));

  with digit select
    nib <= value(3 downto 0)   when "00",
           value(7 downto 4)   when "01",
           value(11 downto 8)  when "10",
           value(15 downto 12) when others;

  with digit select
    an <= "1110" when "00",
          "1101" when "01",
          "1011" when "10",
          "0111" when others;

  --              gfedcba
  with nib select
    seg <= "1000000" when "0000", "1111001" when "0001", "0100100" when "0010",
           "0110000" when "0011", "0011001" when "0100", "0010010" when "0101",
           "0000010" when "0110", "1111000" when "0111", "0000000" when "1000",
           "0010000" when "1001", "0001000" when "1010", "0000011" when "1011",
           "1000110" when "1100", "0100001" when "1101", "0000110" when "1110",
           "0001110" when others;
end architecture rtl;
