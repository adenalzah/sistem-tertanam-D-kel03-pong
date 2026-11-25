-- =============================================================================
-- alu.vhd -- ALU 32-bit untuk RV32I
-- Operasi: add sub sll slt sltu xor srl sra or and
-- Referensi: Harris & Harris RISC-V Ed., Bagian 5.2.4 dan Tabel 7.3
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rv_pkg.all;

entity alu is
  port (
    a      : in  std_logic_vector(31 downto 0);
    b      : in  std_logic_vector(31 downto 0);
    op     : in  alu_op_t;
    result : out std_logic_vector(31 downto 0)
  );
end entity alu;

architecture rtl of alu is
begin
  process (a, b, op)
    variable sh : integer range 0 to 31;
  begin
    sh := to_integer(unsigned(b(4 downto 0)));
    case op is
      when ALU_ADD  => result <= std_logic_vector(unsigned(a) + unsigned(b));
      when ALU_SUB  => result <= std_logic_vector(unsigned(a) - unsigned(b));
      when ALU_SLL  => result <= std_logic_vector(shift_left(unsigned(a), sh));
      when ALU_SLT  =>
        if signed(a) < signed(b) then result <= x"00000001"; else result <= x"00000000"; end if;
      when ALU_SLTU =>
        if unsigned(a) < unsigned(b) then result <= x"00000001"; else result <= x"00000000"; end if;
      when ALU_XOR  => result <= a xor b;
      when ALU_SRL  => result <= std_logic_vector(shift_right(unsigned(a), sh));
      when ALU_SRA  => result <= std_logic_vector(shift_right(signed(a), sh));
      when ALU_OR   => result <= a or b;
      when ALU_AND  => result <= a and b;
      -- [PENGEMBANGAN] Ekstensi M: when ALU_MUL => ...
      when others   => result <= (others => '0');
    end case;
  end process;
end architecture rtl;
