/*
 * selftest.c -- Uji instruksi RV32I pada prosesor (dan pustaka libmini)
 *
 * Jalankan di laptop dan di FPGA; keduanya harus menampilkan "SEMUA LULUS".
 * Berguna setelah memodifikasi inti (mis. menambah ekstensi M):
 *   make rv APP=selftest            (RV32I murni)
 *   make rv APP=selftest MARCH=rv32im  (setelah ekstensi M dibuat)
 */
#include "hal.h"

static volatile int32_t  vi[4] = { 0x12345678, 0x0F0F0F0F, -100, 7 };
static volatile uint8_t  vb[8];
static volatile uint16_t vh[4];

static int fib(int n) { return n < 2 ? n : fib(n - 1) + fib(n - 2); }
static int add1(int x) { return x + 1; }
static int dbl(int x)  { return x * 2; }

struct pt { int x, y, z, w; };

static int line;
static int fails;

static void check(const char *name, uint32_t got, uint32_t expect)
{
    int ok = got == expect;
    fb_text(4, line, name, COLOR_WHITE);
    fb_text(60, line, ok ? "OK" : "GAGAL", ok ? COLOR_GREEN : COLOR_RED);
    if (!ok) { fb_hex(84, line, got, 8, COLOR_RED); fails++; }
    line += 6;
}

int main(void)
{
    hal_init();
    fb_clear(COLOR_BLACK);
    fb_text(4, 2, "SELFTEST RV32I", COLOR_YELLOW);
    line = 12;

    int32_t a = vi[0], b = vi[1], m = vi[2], s = vi[3];

    check("ADD/SUB",  (uint32_t)(a + b - 3),          0x21436584u);
    check("AND/OR",   (uint32_t)((a & b) | 0x80),     0x02040688u);
    check("XOR",      (uint32_t)(a ^ b),               0x1D3B5977u);
    check("SLL/SRL",  (uint32_t)((a << 4) ^ ((uint32_t)a >> 8)), 0x235753D6u);
    check("SRA",      (uint32_t)(m >> 2),              (uint32_t)-25);
    check("SLT/SLTU", (uint32_t)((m < s) * 2 + ((uint32_t)m < (uint32_t)s)), 2);

    vb[1] = 0xF0; vh[1] = 0x8001;
    check("LB/LBU",   (uint32_t)((int8_t)vb[1] + vb[1]),  0x000000E0u);
    check("LH/LHU",   (uint32_t)((int16_t)vh[1] + vh[1]), 0x00000002u);

    check("MUL",      (uint32_t)(a * s),               0x7F6E5D48u);
    check("DIV/REM",  (uint32_t)((m / s) * 100 + (m % s)), (uint32_t)-1402);
    check("DIVU",     0xFFFFFFFFu / (uint32_t)(s - 4), 0x55555555u);

    int sum = 0;
    for (int i = 1; i <= 100; i++) sum += i;
    check("LOOP",     (uint32_t)sum,                   5050);
    check("REKURSI",  (uint32_t)fib(15),               610);

    int (*fp[2])(int) = { add1, dbl };
    check("JALR",     (uint32_t)(fp[(s & 1)](20) + fp[0](1)), 42);

    struct pt p1 = { 1, 2, 3, 4 }, p2;
    p2 = p1;
    check("STRUCT",   (uint32_t)(p2.x + p2.y * 10 + p2.z * 100 + p2.w * 1000), 4321);

    line += 2;
    if (fails == 0)
        fb_text_big(4, line, "SEMUA LULUS", COLOR_GREEN, 2);
    else
        fb_text_big(4, line, "ADA GAGAL", COLOR_RED, 2);
    led_set(fails == 0 ? 0x7FFF : 0x0001);
    seg7_hex((uint16_t)fails);

    for (;;) wait_vsync();
}
