/*
 * hal.h -- Hardware Abstraction Layer untuk RV32 Game Kit
 *
 * Fungsi yang sama tersedia di dua platform:
 *   - FPGA Basys 3 (hal_rv.c)  : akses memory-mapped I/O
 *   - Laptop x86   (hal_pc.c)  : jendela SDL2, untuk uji cepat
 * Kode game hanya boleh memakai fungsi di file ini agar berjalan di keduanya.
 *
 * Layar: 160 x 120 piksel, (0,0) di kiri atas, 1 byte warna RGB332 per piksel.
 */
#ifndef HAL_H
#define HAL_H

#include <stdint.h>
#include "keys.h"

#define SCREEN_W 160
#define SCREEN_H 120

/* Warna RGB332: rrrgggbb */
#define RGB(r, g, b) ((uint8_t)(((r) & 0xE0) | (((g) >> 3) & 0x1C) | ((b) >> 6)))
#define COLOR_BLACK    0x00
#define COLOR_WHITE    0xFF
#define COLOR_GRAY     0x92
#define COLOR_DARKGRAY 0x49
#define COLOR_RED      0xE0
#define COLOR_GREEN    0x1C
#define COLOR_BLUE     0x03
#define COLOR_YELLOW   0xFC
#define COLOR_CYAN     0x1F
#define COLOR_MAGENTA  0xE3
#define COLOR_ORANGE   0xF0

/* ---- Sistem ------------------------------------------------------------- */
void     hal_init(void);          /* panggil sekali di awal main()               */
void     wait_vsync(void);        /* tunggu frame berikutnya (60 FPS) + baca tombol */
uint32_t frame_count(void);       /* jumlah frame sejak reset                    */
uint16_t rand16(void);            /* angka acak 0..65535                         */

/* ---- Gambar --------------------------------------------------------------- */
void    fb_clear(uint8_t c);                                   /* seluruh layar   */
void    fb_pixel(int x, int y, uint8_t c);                     /* satu piksel     */
uint8_t fb_get(int x, int y);                                  /* baca piksel     */
void    fb_rect(int x, int y, int w, int h, uint8_t c);        /* kotak terisi    */
void    fb_frame(int x, int y, int w, int h, uint8_t c);       /* garis tepi kotak */
void    fb_sprite(int x, int y, const uint8_t *rows, int w, int h, uint8_t c);
        /* gambar 1 bit per piksel, maksimum lebar 8: rows[i] bit 7 = kolom kiri  */

/* ---- Teks (font 3x5 dalam sel 4x6, huruf kecil tampil sebagai huruf besar) - */
void fb_text(int x, int y, const char *s, uint8_t c);
void fb_text_big(int x, int y, const char *s, uint8_t c, int scale);  /* skala 2,3,.. */
int  fb_text_width(const char *s, int scale);   /* lebar teks dalam piksel           */
void fb_number(int x, int y, int n, uint8_t c);  /* bilangan bulat desimal            */
void fb_hex(int x, int y, uint32_t v, int digits, uint8_t c);

/* ---- Masukan ------------------------------------------------------------------ */
int      key_down(int key);       /* 1 bila tombol sedang ditekan (lihat keys.h)  */
int      key_pressed(int key);    /* 1 hanya pada frame tombol mulai ditekan       */
uint32_t key_last_event(void);    /* event keyboard terakhir (diagnosa keyboard)   */
uint16_t sw_read(void);           /* sakelar SW14..SW0 (SW15 = reset)              */

/* ---- Keluaran board ---------------------------------------------------------- */
void score_show(int a, int b);    /* 7-segment: dua skor desimal 0..99            */
void seg7_hex(uint16_t v);        /* 7-segment: 4 digit heksa                     */
void led_set(uint16_t v);         /* LED14..LED0 (LED15 = prosesor berhenti)       */

#endif
