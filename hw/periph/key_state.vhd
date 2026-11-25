-- =============================================================================
-- key_state.vhd -- Tabel status tombol keyboard (ditekan / dilepas)
--
-- Keyboard mengirim scancode set 2:
--   tekan           : <kode>              mis. W     = 1D
--   lepas           : F0 <kode>           mis. W     = F0 1D
--   tombol extended : E0 <kode> / E0 F0 <kode>  mis. panah atas = E0 75
-- Indeks tabel = kode (0x00-0x7F) untuk tombol biasa,
--                0x80 + kode untuk tombol extended (panah atas = 0xF5).
-- CPU membaca 256 bit ini sebagai 8 word, sehingga beberapa tombol yang
-- ditekan BERSAMAAN (mis. W dan panah atas pada Pong 2 pemain) terbaca semua.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity key_state is
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    code     : in  std_logic_vector(7 downto 0);
    valid    : in  std_logic;
    keys     : out std_logic_vector(255 downto 0);  -- 1 = sedang ditekan
    last_evt : out std_logic_vector(31 downto 0)    -- [7:0] kode, [8] extended,
                                                    -- [9] lepas, [31:16] jumlah event
  );
end entity key_state;

architecture rtl of key_state is
  signal tbl     : std_logic_vector(255 downto 0) := (others => '0');
  signal ext     : std_logic := '0';
  signal brk     : std_logic := '0';
  signal evt     : std_logic_vector(31 downto 0) := (others => '0');
  signal evt_cnt : unsigned(15 downto 0) := (others => '0');
begin

  process (clk)
    variable idx : integer range 0 to 255;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        tbl     <= (others => '0');
        ext     <= '0';
        brk     <= '0';
        evt     <= (others => '0');
        evt_cnt <= (others => '0');
      elsif valid = '1' then
        if code = x"E0" then
          ext <= '1';
        elsif code = x"F0" then
          brk <= '1';
        elsif code(7) = '0' then
          idx := to_integer(unsigned(ext & code(6 downto 0)));
          tbl(idx) <= not brk;
          evt_cnt  <= evt_cnt + 1;
          evt      <= std_logic_vector(evt_cnt + 1) & "000000" & brk & ext & code;
          ext <= '0';
          brk <= '0';
        else
          -- kode lain (AA, FA, E1, ...) diabaikan
          ext <= '0';
          brk <= '0';
        end if;
      end if;
    end if;
  end process;

  keys     <= tbl;
  last_evt <= evt;

end architecture rtl;
