-- =============================================================================
-- main_mem.vhd -- Memori utama 32 KB (program + data + stack), BRAM dual-port
--   Port A : baca instruksi (fetch)
--   Port B : baca/tulis data dengan byte enable (load/store)
-- Isi awal diambil dari program_init_pkg (dibangkitkan oleh `make rv`).
-- Pola kode mengikuti templat Vivado "True Dual Port RAM with byte-wide
-- write enable" (UG901) agar disintesis sebagai Block RAM.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rv_pkg.all;
use work.program_init_pkg.all;

entity main_mem is
  port (
    clk    : in  std_logic;
    a_addr : in  std_logic_vector(12 downto 0);   -- alamat word
    a_dout : out std_logic_vector(31 downto 0);
    b_addr : in  std_logic_vector(12 downto 0);
    b_we   : in  std_logic_vector(3 downto 0);
    b_din  : in  std_logic_vector(31 downto 0);
    b_dout : out std_logic_vector(31 downto 0)
  );
end entity main_mem;

architecture rtl of main_mem is
  shared variable ram : word_array_t(0 to MAIN_WORDS - 1) := PROGRAM_INIT;
begin

  port_a : process (clk)
  begin
    if rising_edge(clk) then
      a_dout <= ram(to_integer(unsigned(a_addr)));
    end if;
  end process;

  port_b : process (clk)
    variable idx : integer range 0 to MAIN_WORDS - 1;
  begin
    if rising_edge(clk) then
      idx := to_integer(unsigned(b_addr));
      b_dout <= ram(idx);                            -- read-first
      for i in 0 to 3 loop
        if b_we(i) = '1' then
          ram(idx)(8*i + 7 downto 8*i) := b_din(8*i + 7 downto 8*i);
        end if;
      end loop;
    end if;
  end process;

end architecture rtl;
