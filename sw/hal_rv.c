/*
 * hal_rv.c -- Implementasi HAL untuk SoC RISC-V di FPGA Basys 3
 * Semua periferal diakses dengan load/store biasa ke alamat MMIO (lihat hw/top/soc.vhd).
 */
#include "hal.h"
#include "hal_internal.h"

#define FB_BASE  0x10000000u
#define IO_BASE  0x20000000u
#define IO(off)  (*(volatile uint32_t *)(IO_BASE + (off)))

#define REG_BTN    IO(0x000)
#define REG_SW     IO(0x004)
#define REG_LED    IO(0x008)
#define REG_SEG7   IO(0x00C)
#define REG_FRAME  IO(0x010)
#define REG_RAND   IO(0x014)
#define REG_KEYEVT IO(0x018)
#define REG_KEYS(i) IO(0x100 + 4 * (i))

volatile uint8_t *const hal_fb = (volatile uint8_t *)FB_BASE;

static uint32_t rng_state = 0x2545F491u;

void hal_init(void)
{
    for (int i = 0; i < 8; i++)
        hal_keys_now[i] = hal_keys_prev[i] = 0;
    rng_state ^= REG_RAND << 8;
    if (rng_state == 0) rng_state = 1;
}

void wait_vsync(void)
{
    uint32_t f = REG_FRAME;
    while (REG_FRAME == f)
        ;                                   /* tunggu awal vblank berikutnya */
    for (int i = 0; i < 8; i++) {
        hal_keys_prev[i] = hal_keys_now[i];
        hal_keys_now[i]  = REG_KEYS(i);
    }
    hal_merge_buttons(REG_BTN);
}

uint32_t frame_count(void) { return REG_FRAME; }

uint16_t rand16(void)
{
    /* xorshift32, dicampur dengan LFSR hardware yang berjalan bebas */
    uint32_t x = rng_state ^ REG_RAND;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    rng_state = x;
    return (uint16_t)(x >> 16);
}

uint32_t key_last_event(void) { return REG_KEYEVT; }
uint16_t sw_read(void)        { return (uint16_t)(REG_SW & 0x7FFF); }
void     seg7_hex(uint16_t v) { REG_SEG7 = v; }
void     led_set(uint16_t v)  { REG_LED = v; }
