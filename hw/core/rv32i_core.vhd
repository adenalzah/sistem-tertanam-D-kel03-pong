-- =============================================================================
-- rv32i_core.vhd -- Prosesor RISC-V RV32I multi-cycle
--
-- Mendukung seluruh instruksi dasar RV32I:
--   lui auipc jal jalr beq bne blt bge bltu bgeu lb lh lw lbu lhu sb sh sw
--   addi slti sltiu xori ori andi slli srli srai
--   add sub sll slt sltu xor srl sra or and   fence (= nop)
--   ecall/ebreak dan instruksi tak dikenal -> prosesor berhenti (halted = '1')
--
-- Memori dibaca SINKRON (BRAM, latensi 1 siklus), karena itu prosesor
-- dibuat multi-cycle (Harris & Harris RISC-V Ed., Bagian 7.4):
--
--   S_FETCH : alamat PC dikirim ke memori instruksi
--   S_EXEC  : instruksi tersedia -> decode, ALU, tulis register, hitung PC
--             (load: kirim alamat data lalu ke S_LOAD; store: tulis memori)
--   S_LOAD  : data memori tersedia -> tulis ke register rd
--
--   CPI = 2 (ALU, branch, jump, store) atau 3 (load).
--   Pada clock 25 MHz: sekitar 10 juta instruksi per detik.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rv_pkg.all;

entity rv32i_core is
  generic (
    RESET_PC : std_logic_vector(31 downto 0) := x"00000000"
  );
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;                      -- reset sinkron, aktif tinggi
    -- antarmuka memori instruksi (baca sinkron)
    imem_addr  : out std_logic_vector(31 downto 0);
    imem_rdata : in  std_logic_vector(31 downto 0);
    -- antarmuka bus data (baca sinkron, tulis dengan byte enable)
    dmem_addr  : out std_logic_vector(31 downto 0);
    dmem_wdata : out std_logic_vector(31 downto 0);
    dmem_we    : out std_logic_vector(3 downto 0);
    dmem_re    : out std_logic;
    dmem_rdata : in  std_logic_vector(31 downto 0);
    -- status
    halted     : out std_logic;
    pc_out     : out std_logic_vector(31 downto 0)
  );
end entity rv32i_core;

architecture rtl of rv32i_core is
  type state_t is (S_FETCH, S_EXEC, S_LOAD, S_HALT);
  signal state : state_t := S_FETCH;
  signal pc    : unsigned(31 downto 0) := unsigned(RESET_PC);

  signal instr  : std_logic_vector(31 downto 0);
  signal opcode : std_logic_vector(6 downto 0);
  signal funct3 : std_logic_vector(2 downto 0);
  signal f7b5   : std_logic;
  signal rd, rs1, rs2 : std_logic_vector(4 downto 0);

  signal imm_i, imm_s, imm_b, imm_u, imm_j : unsigned(31 downto 0);

  signal rs1_val, rs2_val : std_logic_vector(31 downto 0);
  signal alu_b, alu_y     : std_logic_vector(31 downto 0);
  signal alu_op           : alu_op_t;

  signal mem_addr   : unsigned(31 downto 0);
  signal br_taken   : std_logic;
  signal pc_plus4   : unsigned(31 downto 0);
  signal pc_next    : unsigned(31 downto 0);

  signal writes_rd  : std_logic;
  signal rf_we      : std_logic;
  signal rf_wdata   : std_logic_vector(31 downto 0);
  signal load_data  : std_logic_vector(31 downto 0);
  signal illegal    : std_logic;
begin

  -- ---------------------------------------------------------------------------
  -- Fetch: PC ditahan selama S_EXEC/S_LOAD sehingga instruksi tetap stabil
  -- ---------------------------------------------------------------------------
  imem_addr <= std_logic_vector(pc);
  instr     <= imem_rdata;

  -- ---------------------------------------------------------------------------
  -- Decode (Harris Tabel 7.5: format immediate)
  -- ---------------------------------------------------------------------------
  opcode <= instr(6 downto 0);
  rd     <= instr(11 downto 7);
  funct3 <= instr(14 downto 12);
  rs1    <= instr(19 downto 15);
  rs2    <= instr(24 downto 20);
  f7b5   <= instr(30);

  imm_i <= unsigned(resize(signed(instr(31 downto 20)), 32));
  -- std_logic_vector'(...) = qualified expression: memastikan hasil '&' bertipe std_logic_vector
  imm_s <= unsigned(resize(signed(std_logic_vector'(instr(31 downto 25) & instr(11 downto 7))), 32));
  imm_b <= unsigned(resize(signed(std_logic_vector'(instr(31) & instr(7) & instr(30 downto 25) &
                                                    instr(11 downto 8) & '0')), 32));
  imm_u <= unsigned(std_logic_vector'(instr(31 downto 12) & x"000"));
  imm_j <= unsigned(resize(signed(std_logic_vector'(instr(31) & instr(19 downto 12) & instr(20) &
                                                    instr(30 downto 21) & '0')), 32));

  u_rf : entity work.regfile
    port map (clk => clk, we => rf_we, rs1 => rs1, rs2 => rs2, rd => rd,
              rd_data => rf_wdata, rs1_data => rs1_val, rs2_data => rs2_val);

  -- ---------------------------------------------------------------------------
  -- ALU decoder: funct3 (+ instr[30]) -> operasi ALU
  -- ---------------------------------------------------------------------------
  process (funct3, f7b5, opcode)
  begin
    case funct3 is
      when "000" =>
        if opcode = OPC_OP and f7b5 = '1' then alu_op <= ALU_SUB; else alu_op <= ALU_ADD; end if;
      when "001" => alu_op <= ALU_SLL;
      when "010" => alu_op <= ALU_SLT;
      when "011" => alu_op <= ALU_SLTU;
      when "100" => alu_op <= ALU_XOR;
      when "101" =>
        if f7b5 = '1' then alu_op <= ALU_SRA; else alu_op <= ALU_SRL; end if;
      when "110" => alu_op <= ALU_OR;
      when others => alu_op <= ALU_AND;
    end case;
    -- [PENGEMBANGAN] Ekstensi M: bila opcode = OPC_OP dan instr[31:25] = "0000001",
    --                pilih operasi mul/mulh/div/rem sesuai funct3.
  end process;

  alu_b <= rs2_val when opcode = OPC_OP else std_logic_vector(imm_i);

  u_alu : entity work.alu
    port map (a => rs1_val, b => alu_b, op => alu_op, result => alu_y);

  -- ---------------------------------------------------------------------------
  -- Pembanding branch
  -- ---------------------------------------------------------------------------
  process (funct3, rs1_val, rs2_val)
  begin
    case funct3 is
      when "000"  => if rs1_val = rs2_val then br_taken <= '1'; else br_taken <= '0'; end if;                     -- beq
      when "001"  => if rs1_val /= rs2_val then br_taken <= '1'; else br_taken <= '0'; end if;                    -- bne
      when "100"  => if signed(rs1_val) < signed(rs2_val) then br_taken <= '1'; else br_taken <= '0'; end if;     -- blt
      when "101"  => if signed(rs1_val) >= signed(rs2_val) then br_taken <= '1'; else br_taken <= '0'; end if;    -- bge
      when "110"  => if unsigned(rs1_val) < unsigned(rs2_val) then br_taken <= '1'; else br_taken <= '0'; end if; -- bltu
      when "111"  => if unsigned(rs1_val) >= unsigned(rs2_val) then br_taken <= '1'; else br_taken <= '0'; end if;-- bgeu
      when others => br_taken <= '0';
    end case;
  end process;

  -- ---------------------------------------------------------------------------
  -- PC berikutnya
  -- ---------------------------------------------------------------------------
  pc_plus4 <= pc + 4;

  process (opcode, pc, pc_plus4, imm_j, imm_b, imm_i, rs1_val, br_taken)
    variable t : unsigned(31 downto 0);
  begin
    case opcode is
      when OPC_JAL    => pc_next <= pc + imm_j;
      when OPC_JALR   => t := unsigned(rs1_val) + imm_i; pc_next <= t(31 downto 1) & '0';
      when OPC_BRANCH =>
        if br_taken = '1' then pc_next <= pc + imm_b; else pc_next <= pc_plus4; end if;
      when others     => pc_next <= pc_plus4;
    end case;
  end process;

  -- ---------------------------------------------------------------------------
  -- Instruksi mana yang menulis rd, dan instruksi tak dikenal
  -- ---------------------------------------------------------------------------
  process (opcode)
  begin
    writes_rd <= '0';
    illegal   <= '0';
    case opcode is
      when OPC_LUI | OPC_AUIPC | OPC_JAL | OPC_JALR | OPC_OP_IMM | OPC_OP => writes_rd <= '1';
      when OPC_BRANCH | OPC_LOAD | OPC_STORE | OPC_FENCE => null;
      -- [PENGEMBANGAN] instruksi kustom: when OPC_CUSTOM0 => ...
      when others => illegal <= '1';   -- termasuk ecall/ebreak (OPC_SYSTEM)
    end case;
  end process;

  -- ---------------------------------------------------------------------------
  -- Akses memori data: alamat = rs1 + imm
  -- ---------------------------------------------------------------------------
  mem_addr <= unsigned(rs1_val) + imm_s when opcode = OPC_STORE else unsigned(rs1_val) + imm_i;
  dmem_addr <= std_logic_vector(mem_addr);
  dmem_re   <= '1' when state = S_EXEC and opcode = OPC_LOAD else '0';

  process (state, opcode, funct3, rs2_val, mem_addr)
  begin
    dmem_we    <= "0000";
    dmem_wdata <= rs2_val;
    if state = S_EXEC and opcode = OPC_STORE then
      case funct3(1 downto 0) is
        when "00" =>                                           -- sb
          dmem_wdata <= rs2_val(7 downto 0) & rs2_val(7 downto 0) &
                        rs2_val(7 downto 0) & rs2_val(7 downto 0);
          case mem_addr(1 downto 0) is
            when "00"   => dmem_we <= "0001";
            when "01"   => dmem_we <= "0010";
            when "10"   => dmem_we <= "0100";
            when others => dmem_we <= "1000";
          end case;
        when "01" =>                                           -- sh
          dmem_wdata <= rs2_val(15 downto 0) & rs2_val(15 downto 0);
          if mem_addr(1) = '0' then dmem_we <= "0011"; else dmem_we <= "1100"; end if;
        when others =>                                         -- sw
          dmem_we <= "1111";
      end case;
    end if;
  end process;

  -- Data load: pilih byte/half sesuai alamat, lalu perluasan tanda
  process (funct3, mem_addr, dmem_rdata)
    variable b : std_logic_vector(7 downto 0);
    variable h : std_logic_vector(15 downto 0);
  begin
    case mem_addr(1 downto 0) is
      when "00"   => b := dmem_rdata(7 downto 0);
      when "01"   => b := dmem_rdata(15 downto 8);
      when "10"   => b := dmem_rdata(23 downto 16);
      when others => b := dmem_rdata(31 downto 24);
    end case;
    if mem_addr(1) = '0' then h := dmem_rdata(15 downto 0); else h := dmem_rdata(31 downto 16); end if;
    case funct3 is
      when "000"  => load_data <= std_logic_vector(resize(signed(b), 32));     -- lb
      when "001"  => load_data <= std_logic_vector(resize(signed(h), 32));     -- lh
      when "100"  => load_data <= std_logic_vector(resize(unsigned(b), 32));   -- lbu
      when "101"  => load_data <= std_logic_vector(resize(unsigned(h), 32));   -- lhu
      when others => load_data <= dmem_rdata;                                  -- lw
    end case;
  end process;

  -- ---------------------------------------------------------------------------
  -- Write-back
  -- ---------------------------------------------------------------------------
  process (state, opcode, imm_u, pc, pc_plus4, alu_y, load_data)
  begin
    if state = S_LOAD then
      rf_wdata <= load_data;
    else
      case opcode is
        when OPC_LUI            => rf_wdata <= std_logic_vector(imm_u);
        when OPC_AUIPC          => rf_wdata <= std_logic_vector(pc + imm_u);
        when OPC_JAL | OPC_JALR => rf_wdata <= std_logic_vector(pc_plus4);
        when others             => rf_wdata <= alu_y;
      end case;
    end if;
  end process;

  rf_we <= '1' when (state = S_EXEC and writes_rd = '1') or state = S_LOAD else '0';

  -- ---------------------------------------------------------------------------
  -- Mesin keadaan
  -- ---------------------------------------------------------------------------
  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state <= S_FETCH;
        pc    <= unsigned(RESET_PC);
      else
        case state is
          when S_FETCH =>
            state <= S_EXEC;
          when S_EXEC =>
            if illegal = '1' then
              state <= S_HALT;
            elsif opcode = OPC_LOAD then
              state <= S_LOAD;
            else
              pc    <= pc_next;
              state <= S_FETCH;
            end if;
          when S_LOAD =>
            pc    <= pc_plus4;
            state <= S_FETCH;
          when S_HALT =>
            null;
        end case;
      end if;
    end if;
  end process;

  halted <= '1' when state = S_HALT else '0';
  pc_out <= std_logic_vector(pc);

end architecture rtl;
