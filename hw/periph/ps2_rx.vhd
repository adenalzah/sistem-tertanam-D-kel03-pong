-- =============================================================================
-- ps2_rx.vhd -- Penerima protokol PS/2 (keyboard -> FPGA)
--
-- Basys 3: keyboard USB dibaca chip PIC24 yang meniru keyboard PS/2 pada
-- pin PS2Clk (C17) dan PS2Data (B17). Bingkai 11 bit:
--   start(0) | 8 bit data, LSB dulu | paritas ganjil | stop(1)
-- Data dibaca pada tepi TURUN ps2_clk (~10-16 kHz).
-- Referensi: Bruno, FPGA Programming for Beginners, Bab 10.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ps2_rx is
  port (
    clk      : in  std_logic;                     -- 25 MHz
    rst      : in  std_logic;
    ps2_clk  : in  std_logic;
    ps2_data : in  std_logic;
    code     : out std_logic_vector(7 downto 0);  -- scancode diterima
    valid    : out std_logic                      -- pulsa 1 siklus
  );
end entity ps2_rx;

architecture rtl of ps2_rx is
  signal clk_sync  : std_logic_vector(2 downto 0) := (others => '1');
  signal dat_sync  : std_logic_vector(1 downto 0) := (others => '1');
  signal filt_cnt  : unsigned(3 downto 0) := (others => '1');
  signal clk_filt  : std_logic := '1';
  signal clk_prev  : std_logic := '1';
  signal shreg     : std_logic_vector(10 downto 0) := (others => '0');
  signal bitcnt    : unsigned(3 downto 0) := (others => '0');
  signal idle_cnt  : unsigned(15 downto 0) := (others => '0');   -- ~2,6 ms timeout
begin

  process (clk)
    variable par : std_logic;
  begin
    if rising_edge(clk) then
      valid <= '0';
      if rst = '1' then
        bitcnt   <= (others => '0');
        idle_cnt <= (others => '0');
        clk_filt <= '1';
        clk_prev <= '1';
      else
        -- sinkronisasi
        clk_sync <= clk_sync(1 downto 0) & ps2_clk;
        dat_sync <= dat_sync(0) & ps2_data;

        -- filter derau: ps2_clk harus stabil 15 siklus sebelum dianggap berubah
        if clk_sync(2) /= clk_filt then
          if filt_cnt = 0 then
            clk_filt <= clk_sync(2);
            filt_cnt <= (others => '1');
          else
            filt_cnt <= filt_cnt - 1;
          end if;
        else
          filt_cnt <= (others => '1');
        end if;
        clk_prev <= clk_filt;

        -- bila jalur diam terlalu lama, mulai bingkai baru (sinkron ulang)
        if clk_filt = '1' then
          if idle_cnt /= x"FFFF" then idle_cnt <= idle_cnt + 1; end if;
          if idle_cnt = x"FFFE" then bitcnt <= (others => '0'); end if;
        else
          idle_cnt <= (others => '0');
        end if;

        -- tepi turun: ambil satu bit
        if clk_prev = '1' and clk_filt = '0' then
          shreg <= dat_sync(1) & shreg(10 downto 1);
          if bitcnt = 10 then
            bitcnt <= (others => '0');
            -- Saat bit ke-11 (stop) datang, isi shreg SEBELUM digeser:
            --   shreg(1) = start, shreg(9..2) = data (MSB..LSB), shreg(10) = paritas
            par := shreg(10) xor shreg(9) xor shreg(8) xor shreg(7) xor shreg(6) xor
                   shreg(5) xor shreg(4) xor shreg(3) xor shreg(2);   -- paritas ganjil -> '1'
            if shreg(1) = '0' and dat_sync(1) = '1' and par = '1' then
              code  <= shreg(9 downto 2);
              valid <= '1';
            end if;
          else
            bitcnt <= bitcnt + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

end architecture rtl;
