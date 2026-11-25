-- =============================================================================
-- regfile.vhd -- Register file 32 x 32-bit, x0 selalu 0
-- 2 port baca asinkron, 1 port tulis sinkron (disintesis sebagai LUTRAM)
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity regfile is
  port (
    clk      : in  std_logic;
    we       : in  std_logic;
    rs1      : in  std_logic_vector(4 downto 0);
    rs2      : in  std_logic_vector(4 downto 0);
    rd       : in  std_logic_vector(4 downto 0);
    rd_data  : in  std_logic_vector(31 downto 0);
    rs1_data : out std_logic_vector(31 downto 0);
    rs2_data : out std_logic_vector(31 downto 0)
  );
end entity regfile;

architecture rtl of regfile is
  type regs_t is array (0 to 31) of std_logic_vector(31 downto 0);
  signal regs : regs_t := (others => (others => '0'));
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if we = '1' and rd /= "00000" then
        regs(to_integer(unsigned(rd))) <= rd_data;
      end if;
    end if;
  end process;

  rs1_data <= (others => '0') when rs1 = "00000" else regs(to_integer(unsigned(rs1)));
  rs2_data <= (others => '0') when rs2 = "00000" else regs(to_integer(unsigned(rs2)));
end architecture rtl;
