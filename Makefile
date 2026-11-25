# =============================================================================
# Makefile -- RV32 Game Kit
#
#   make pc  [APP=demo]        jalankan program di laptop (x86 + SDL2)
#   make rv  [APP=demo]        compile untuk RISC-V -> hw/mem/program_init.vhd
#   make sim [APP=demo]        simulasi SoC dengan GHDL -> build/frame.png
#   make clean
#
# APP   : demo | selftest | game        (folder di sw/)
# MARCH : rv32i (bawaan) | rv32im (setelah ekstensi M ditambahkan ke inti)
# CROSS : awalan cross-compiler, bawaan riscv-none-elf- (xPack)
#         contoh Ubuntu: make rv CROSS=riscv64-unknown-elf-
# =============================================================================

APP    ?= demo
MARCH  ?= rv32i
CROSS  ?= riscv-none-elf-
PYTHON ?= python3
GHDL   ?= ghdl

BUILD  := build
COMMON := sw/common
APPSRC := $(wildcard sw/$(APP)/*.c)

ifeq ($(APPSRC),)
$(error Folder sw/$(APP) tidak ditemukan atau kosong)
endif

# ---------------------------------------------------------------------------
# Versi laptop (x86)
# ---------------------------------------------------------------------------
PC_CC     ?= gcc
PC_CFLAGS := -O2 -Wall -Wextra -I$(COMMON) $(shell sdl2-config --cflags)
ifeq ($(OS),Windows_NT)
PC_LIBS   := -lmingw32 -lSDL2          # MSYS2 UCRT64: aplikasi konsol + SDL2
else
PC_LIBS   := $(shell sdl2-config --libs)
endif
PC_EXE    := $(BUILD)/$(APP)_pc

.PHONY: pc
pc: $(PC_EXE)
	./$(PC_EXE)

$(PC_EXE): $(APPSRC) $(COMMON)/gfx.c sw/hal_pc.c $(wildcard $(COMMON)/*.h) | $(BUILD)
	$(PC_CC) $(PC_CFLAGS) -o $@ $(APPSRC) $(COMMON)/gfx.c sw/hal_pc.c $(PC_LIBS)

# ---------------------------------------------------------------------------
# Versi RISC-V (FPGA)
# ---------------------------------------------------------------------------
RV_CC      := $(CROSS)gcc
RV_OBJCOPY := $(CROSS)objcopy
RV_OBJDUMP := $(CROSS)objdump
RV_SIZE    := $(CROSS)size
RV_CFLAGS  := -march=$(MARCH) -mabi=ilp32 -O2 -Wall -Wextra \
              -ffreestanding -fno-builtin -fno-tree-loop-distribute-patterns \
              -ffunction-sections -fdata-sections -msmall-data-limit=8 -I$(COMMON)
RV_LDFLAGS := -nostdlib -nostartfiles -T $(COMMON)/link.ld -Wl,--gc-sections \
              -Wl,-Map,$(BUILD)/$(APP).map -Wl,--no-warn-rwx-segments
RV_SRC     := $(COMMON)/crt0.S $(APPSRC) $(COMMON)/gfx.c $(COMMON)/libmini.c sw/hal_rv.c
RV_ELF     := $(BUILD)/$(APP).elf
PROG_VHD   := hw/mem/program_init.vhd

.PHONY: rv
rv: $(PROG_VHD)
	@echo ""
	@echo "Selesai. Di Vivado: jalankan ulang Generate Bitstream, lalu Program Device."

$(RV_ELF): $(RV_SRC) $(wildcard $(COMMON)/*.h) $(COMMON)/link.ld FORCE | $(BUILD)
	$(RV_CC) $(RV_CFLAGS) $(RV_LDFLAGS) -o $@ $(RV_SRC)
	$(RV_OBJDUMP) -d -M no-aliases,numeric $@ > $(BUILD)/$(APP).lst
	$(RV_SIZE) $@

$(PROG_VHD): $(RV_ELF)
	$(RV_OBJCOPY) -O binary $< $(BUILD)/$(APP).bin
	$(PYTHON) tools/bin2vhd.py $(BUILD)/$(APP).bin $@

# ---------------------------------------------------------------------------
# Simulasi SoC dengan GHDL (opsional)
# ---------------------------------------------------------------------------
HW_SRC := hw/core/rv_pkg.vhd $(PROG_VHD) hw/core/alu.vhd hw/core/regfile.vhd \
          hw/core/rv32i_core.vhd hw/mem/main_mem.vhd hw/mem/fb_mem.vhd \
          hw/periph/vga_fb.vhd hw/periph/ps2_rx.vhd hw/periph/key_state.vhd \
          hw/top/soc.vhd hw/sim/tb_soc.vhd
FRAMES ?= 3

.PHONY: sim
sim: $(PROG_VHD) | $(BUILD)
	cd $(BUILD) && $(GHDL) -a --std=93c $(addprefix ../,$(HW_SRC))
	cd $(BUILD) && $(GHDL) -e --std=93c tb_soc
	cd $(BUILD) && $(GHDL) -r --std=93c tb_soc --ieee-asserts=disable -gCAPTURE_FRAME=$(FRAMES)
	$(PYTHON) tools/ppm2png.py $(BUILD)/frame.ppm $(BUILD)/frame.png 4

# ---------------------------------------------------------------------------
$(BUILD):
	mkdir -p $(BUILD)

.PHONY: clean FORCE
FORCE:
clean:
	rm -rf $(BUILD)
