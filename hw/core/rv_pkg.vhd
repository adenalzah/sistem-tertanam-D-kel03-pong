-- =============================================================================
-- rv_pkg.vhd -- Konstanta bersama untuk inti RV32I dan SoC game
-- Mata kuliah : Sistem Tertanam -- Sarjana Terapan Teknik Elektronika FV UNY
-- Referensi   : Harris & Harris, Digital Design and Computer Architecture,
--               RISC-V Edition (2021), Bab 6 dan Bab 7
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package rv_pkg is

  -- Opcode RV32I (instr[6:0])
  constant OPC_LUI    : std_logic_vector(6 downto 0) := "0110111";
  constant OPC_AUIPC  : std_logic_vector(6 downto 0) := "0010111";
  constant OPC_JAL    : std_logic_vector(6 downto 0) := "1101111";
  constant OPC_JALR   : std_logic_vector(6 downto 0) := "1100111";
  constant OPC_BRANCH : std_logic_vector(6 downto 0) := "1100011";
  constant OPC_LOAD   : std_logic_vector(6 downto 0) := "0000011";
  constant OPC_STORE  : std_logic_vector(6 downto 0) := "0100011";
  constant OPC_OP_IMM : std_logic_vector(6 downto 0) := "0010011";
  constant OPC_OP     : std_logic_vector(6 downto 0) := "0110011";
  constant OPC_FENCE  : std_logic_vector(6 downto 0) := "0001111";
  constant OPC_SYSTEM : std_logic_vector(6 downto 0) := "1110011";
  constant OPC_CUSTOM0: std_logic_vector(6 downto 0) := "0001011";  -- bebas untuk instruksi kustom

  -- Operasi ALU (internal)
  subtype alu_op_t is std_logic_vector(3 downto 0);
  constant ALU_ADD  : alu_op_t := "0000";
  constant ALU_SUB  : alu_op_t := "0001";
  constant ALU_SLL  : alu_op_t := "0010";
  constant ALU_SLT  : alu_op_t := "0011";
  constant ALU_SLTU : alu_op_t := "0100";
  constant ALU_XOR  : alu_op_t := "0101";
  constant ALU_SRL  : alu_op_t := "0110";
  constant ALU_SRA  : alu_op_t := "0111";
  constant ALU_OR   : alu_op_t := "1000";
  constant ALU_AND  : alu_op_t := "1001";
  -- [PENGEMBANGAN] Ekstensi M: tambahkan mis. ALU_MUL "1010", ALU_MULH "1011", ...

  -- Ukuran memori (dalam word 32-bit)
  constant MAIN_WORDS : integer := 8192;   -- 32 KB program + data + stack
  constant FB_WIDTH   : integer := 160;
  constant FB_HEIGHT  : integer := 120;
  constant FB_WORDS   : integer := FB_WIDTH * FB_HEIGHT / 4;   -- 4800 word

  type word_array_t is array (natural range <>) of std_logic_vector(31 downto 0);

end package rv_pkg;
