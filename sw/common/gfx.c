/*
 * gfx.c -- Fungsi gambar, teks, dan keyboard yang SAMA untuk FPGA dan PC.
 * Bagian yang berbeda per platform ada di hal_rv.c dan hal_pc.c.
 */
#include "hal.h"
#include "hal_internal.h"
#include "font.h"

/* ---- Gambar ---------------------------------------------------------------- */

void fb_clear(uint8_t c)
{
    /* tulis 4 piksel sekaligus (sw) agar cepat */
    uint32_t v = c * 0x01010101u;
    volatile uint32_t *p = (volatile uint32_t *)hal_fb;
    for (int i = 0; i < SCREEN_W * SCREEN_H / 4; i++)
        p[i] = v;
}

void fb_pixel(int x, int y, uint8_t c)
{
    if ((unsigned)x < SCREEN_W && (unsigned)y < SCREEN_H)
        hal_fb[y * SCREEN_W + x] = c;
}

uint8_t fb_get(int x, int y)
{
    if ((unsigned)x < SCREEN_W && (unsigned)y < SCREEN_H)
        return hal_fb[y * SCREEN_W + x];
    return 0;
}

void fb_rect(int x, int y, int w, int h, uint8_t c)
{
    if (x < 0) { w += x; x = 0; }
    if (y < 0) { h += y; y = 0; }
    if (x + w > SCREEN_W) w = SCREEN_W - x;
    if (y + h > SCREEN_H) h = SCREEN_H - y;
    if (w <= 0 || h <= 0) return;
    volatile uint8_t *row = hal_fb + y * SCREEN_W + x;
    for (int j = 0; j < h; j++) {
        for (int i = 0; i < w; i++)
            row[i] = c;
        row += SCREEN_W;
    }
}

void fb_frame(int x, int y, int w, int h, uint8_t c)
{
    fb_rect(x, y, w, 1, c);
    fb_rect(x, y + h - 1, w, 1, c);
    fb_rect(x, y, 1, h, c);
    fb_rect(x + w - 1, y, 1, h, c);
}

void fb_sprite(int x, int y, const uint8_t *rows, int w, int h, uint8_t c)
{
    for (int j = 0; j < h; j++)
        for (int i = 0; i < w; i++)
            if (rows[j] & (0x80 >> i))
                fb_pixel(x + i, y + j, c);
}

/* ---- Teks ------------------------------------------------------------------ */

static void draw_char(int x, int y, char ch, uint8_t c, int scale)
{
    if (ch >= 'a' && ch <= 'z') ch -= 32;
    if (ch < FONT_FIRST || ch > FONT_LAST) ch = '?';
    uint16_t g = font3x5[ch - FONT_FIRST];
    for (int r = 0; r < 5; r++)
        for (int col = 0; col < 3; col++)
            if (g & (1u << (r * 3 + (2 - col)))) {
                if (scale == 1)
                    fb_pixel(x + col, y + r, c);
                else
                    fb_rect(x + col * scale, y + r * scale, scale, scale, c);
            }
}

void fb_text_big(int x, int y, const char *s, uint8_t c, int scale)
{
    if (scale < 1) scale = 1;
    int x0 = x;
    for (; *s; s++) {
        if (*s == '\n') { x = x0; y += 6 * scale; continue; }
        draw_char(x, y, *s, c, scale);
        x += 4 * scale;
    }
}

void fb_text(int x, int y, const char *s, uint8_t c)
{
    fb_text_big(x, y, s, c, 1);
}

int fb_text_width(const char *s, int scale)
{
    int n = 0;
    while (s[n]) n++;
    return n > 0 ? (n * 4 - 1) * scale : 0;
}

void fb_number(int x, int y, int n, uint8_t c)
{
    char buf[12];
    int i = 11;
    unsigned u = n < 0 ? (unsigned)(-n) : (unsigned)n;
    buf[i] = 0;
    do { buf[--i] = '0' + (u % 10); u /= 10; } while (u);
    if (n < 0) buf[--i] = '-';
    fb_text(x, y, &buf[i], c);
}

void fb_hex(int x, int y, uint32_t v, int digits, uint8_t c)
{
    char buf[9];
    if (digits < 1) digits = 1;
    if (digits > 8) digits = 8;
    for (int i = digits - 1; i >= 0; i--) {
        int d = v & 0xF;
        buf[i] = d < 10 ? '0' + d : 'A' + d - 10;
        v >>= 4;
    }
    buf[digits] = 0;
    fb_text(x, y, buf, c);
}

/* ---- Keyboard ----------------------------------------------------------------- */

uint32_t hal_keys_now[8];
uint32_t hal_keys_prev[8];

int key_down(int key)
{
    key &= 0xFF;
    return (hal_keys_now[key >> 5] >> (key & 31)) & 1;
}

int key_pressed(int key)
{
    key &= 0xFF;
    return ((hal_keys_now[key >> 5] & ~hal_keys_prev[key >> 5]) >> (key & 31)) & 1;
}

/* Tandai tombol board sebagai tombol keyboard (dipanggil oleh HAL platform) */
void hal_merge_buttons(uint32_t btn)
{
    static const uint8_t map[5] = { KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_ENTER };
    for (int i = 0; i < 5; i++)
        if (btn & (1u << i))
            hal_keys_now[map[i] >> 5] |= 1u << (map[i] & 31);
    if (btn & 0x10)
        hal_keys_now[KEY_SPACE >> 5] |= 1u << (KEY_SPACE & 31);
}

/* ---- 7-segment ------------------------------------------------------------------ */

void score_show(int a, int b)
{
    if (a < 0) a = 0;
    if (a > 99) a = 99;
    if (b < 0) b = 0;
    if (b > 99) b = 99;
    seg7_hex((uint16_t)(((a / 10) << 12) | ((a % 10) << 8) | ((b / 10) << 4) | (b % 10)));
}
