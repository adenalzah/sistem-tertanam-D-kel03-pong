/*
 * demo.c -- Program demo RV32 Game Kit (BUKAN salah satu game tugas)
 *
 * Menunjukkan semua fungsi HAL:
 *   - bola memantul (gerak fixed-point, warna acak saat memantul)
 *   - daftar tombol yang sedang ditekan (uji keyboard, termasuk tekan bersamaan)
 *   - event keyboard terakhir dalam heksa (diagnosa keyboard di board)
 *   - jumlah pantulan dan detik di 7-segment
 *
 * Teknik penting: layar TIDAK dihapus setiap frame. Latar digambar sekali,
 * lalu hanya bagian yang berubah yang dihapus dan digambar ulang. Ini
 * mengurangi kedip karena framebuffer langsung ditampilkan ke monitor.
 */
#include "hal.h"

static const struct { uint8_t key; const char *name; } names[] = {
    {KEY_W, "W"}, {KEY_A, "A"}, {KEY_S, "S"}, {KEY_D, "D"},
    {KEY_UP, "ATAS"}, {KEY_DOWN, "BAWAH"}, {KEY_LEFT, "KIRI"}, {KEY_RIGHT, "KANAN"},
    {KEY_SPACE, "SPASI"}, {KEY_ENTER, "ENTER"}, {KEY_ESC, "ESC"}, {KEY_P, "P"},
    {KEY_Q, "Q"}, {KEY_E, "E"}, {KEY_LSHIFT, "SHIFT"}, {KEY_LCTRL, "CTRL"},
};
#define NNAMES ((int)(sizeof names / sizeof names[0]))

/* arena bola */
#define AX 4
#define AY 56
#define AW 152
#define AH 60
#define BALL 4

static void draw_static(void)
{
    const char *title = "RV32 GAME KIT";
    fb_clear(COLOR_BLACK);
    fb_text_big((SCREEN_W - fb_text_width(title, 2)) / 2, 3, title, COLOR_YELLOW, 2);
    fb_text(4, 18, "DEMO PLATFORM - SISTEM TERTANAM", COLOR_GRAY);
    fb_text(4, 28, "TOMBOL:", COLOR_WHITE);
    fb_text(4, 44, "EVENT:", COLOR_WHITE);
    fb_text(70, 44, "FRAME:", COLOR_WHITE);
    fb_frame(AX - 1, AY - 1, AW + 2, AH + 2, COLOR_GRAY);
}

int main(void)
{
    int bx = 20 << 4, by = 20 << 4;     /* posisi bola x16 (fixed-point) */
    int vx = 23, vy = 17;               /* kecepatan x16 per frame       */
    int bounces = 0;
    uint8_t color = COLOR_WHITE;

    hal_init();
    draw_static();

    for (;;) {
        wait_vsync();

        /* ---- hapus bola lama ---- */
        fb_rect(AX + (bx >> 4), AY + (by >> 4), BALL, BALL, COLOR_BLACK);

        /* ---- gerak & pantulan ---- */
        bx += vx;
        by += vy;
        if (bx < 0)                      { bx = 0;                      vx = -vx; bounces++; color = rand16() | 0x24; }
        if (bx > (AW - BALL) << 4)       { bx = (AW - BALL) << 4;       vx = -vx; bounces++; color = rand16() | 0x24; }
        if (by < 0)                      { by = 0;                      vy = -vy; bounces++; color = rand16() | 0x24; }
        if (by > (AH - BALL) << 4)       { by = (AH - BALL) << 4;       vy = -vy; bounces++; color = rand16() | 0x24; }

        /* tombol panah mempercepat/memperlambat bola */
        if (key_pressed(KEY_UP)   && vy > -60) vy += vy < 0 ? -4 : 4;
        if (key_pressed(KEY_DOWN) && vy < 60)  vy += vy < 0 ? 2 : -2;

        fb_rect(AX + (bx >> 4), AY + (by >> 4), BALL, BALL, color);

        /* ---- daftar tombol yang ditekan ---- */
        fb_rect(34, 28, 126, 12, COLOR_BLACK);
        int x = 34, y = 28, count = 0;
        for (int i = 0; i < NNAMES; i++) {
            if (key_down(names[i].key)) {
                int w = fb_text_width(names[i].name, 1) + 4;
                if (x + w > SCREEN_W) { x = 34; y += 6; }
                if (y < 40) fb_text(x, y, names[i].name, COLOR_GREEN);
                x += w;
                count++;
            }
        }
        if (count == 0) fb_text(34, 28, "-", COLOR_DARKGRAY);

        /* ---- diagnosa keyboard & frame ---- */
        fb_rect(30, 44, 36, 6, COLOR_BLACK);
        fb_hex(30, 44, key_last_event() & 0x3FF, 3, COLOR_CYAN);
        fb_rect(96, 44, 60, 6, COLOR_BLACK);
        fb_number(96, 44, (int)frame_count(), COLOR_CYAN);

        /* ---- board ---- */
        score_show(bounces % 100, (int)(frame_count() / 60) % 100);
        led_set((uint16_t)((1u << count) - 1));
    }
}
