/*
 * hal_pc.c -- Implementasi HAL untuk laptop (x86) memakai SDL2
 *
 * Game yang sama berjalan di jendela 640x480 (setiap piksel 4x4), sehingga
 * logika game bisa diuji dalam hitungan detik tanpa sintesis ulang Vivado.
 *
 * Variabel lingkungan (opsional, untuk pengujian otomatis):
 *   HAL_FRAMES=N         keluar otomatis setelah N frame
 *   HAL_SCREENSHOT=f.ppm simpan isi layar saat keluar (format PPM)
 * Tombol F12 menyimpan tangkapan layar ke screenshot.ppm (untuk laporan).
 */
#define SDL_MAIN_HANDLED          /* main() milik program sendiri, bukan SDL_main */
#include <SDL.h>
#include <stdio.h>
#include <stdlib.h>
#include "hal.h"
#include "hal_internal.h"

static uint8_t fb_buf[SCREEN_W * SCREEN_H] __attribute__((aligned(4)));
volatile uint8_t *const hal_fb = fb_buf;

static SDL_Window   *win;
static SDL_Renderer *ren;
static SDL_Texture  *tex;
static uint32_t frames, max_frames, next_tick;
static uint16_t seg7_val;
static uint32_t last_evt;

/* Pemetaan kode PS/2 (keys.h) <-> SDL_Scancode */
static const struct { uint8_t key; SDL_Scancode sc; } keymap[] = {
    {KEY_A, SDL_SCANCODE_A}, {KEY_B, SDL_SCANCODE_B}, {KEY_C, SDL_SCANCODE_C},
    {KEY_D, SDL_SCANCODE_D}, {KEY_E, SDL_SCANCODE_E}, {KEY_F, SDL_SCANCODE_F},
    {KEY_G, SDL_SCANCODE_G}, {KEY_H, SDL_SCANCODE_H}, {KEY_I, SDL_SCANCODE_I},
    {KEY_J, SDL_SCANCODE_J}, {KEY_K, SDL_SCANCODE_K}, {KEY_L, SDL_SCANCODE_L},
    {KEY_M, SDL_SCANCODE_M}, {KEY_N, SDL_SCANCODE_N}, {KEY_O, SDL_SCANCODE_O},
    {KEY_P, SDL_SCANCODE_P}, {KEY_Q, SDL_SCANCODE_Q}, {KEY_R, SDL_SCANCODE_R},
    {KEY_S, SDL_SCANCODE_S}, {KEY_T, SDL_SCANCODE_T}, {KEY_U, SDL_SCANCODE_U},
    {KEY_V, SDL_SCANCODE_V}, {KEY_W, SDL_SCANCODE_W}, {KEY_X, SDL_SCANCODE_X},
    {KEY_Y, SDL_SCANCODE_Y}, {KEY_Z, SDL_SCANCODE_Z},
    {KEY_0, SDL_SCANCODE_0}, {KEY_1, SDL_SCANCODE_1}, {KEY_2, SDL_SCANCODE_2},
    {KEY_3, SDL_SCANCODE_3}, {KEY_4, SDL_SCANCODE_4}, {KEY_5, SDL_SCANCODE_5},
    {KEY_6, SDL_SCANCODE_6}, {KEY_7, SDL_SCANCODE_7}, {KEY_8, SDL_SCANCODE_8},
    {KEY_9, SDL_SCANCODE_9},
    {KEY_SPACE, SDL_SCANCODE_SPACE}, {KEY_ENTER, SDL_SCANCODE_RETURN},
    {KEY_ESC, SDL_SCANCODE_ESCAPE}, {KEY_BACKSPACE, SDL_SCANCODE_BACKSPACE},
    {KEY_TAB, SDL_SCANCODE_TAB}, {KEY_LSHIFT, SDL_SCANCODE_LSHIFT},
    {KEY_RSHIFT, SDL_SCANCODE_RSHIFT}, {KEY_LCTRL, SDL_SCANCODE_LCTRL},
    {KEY_LALT, SDL_SCANCODE_LALT}, {KEY_MINUS, SDL_SCANCODE_MINUS},
    {KEY_EQUAL, SDL_SCANCODE_EQUALS}, {KEY_COMMA, SDL_SCANCODE_COMMA},
    {KEY_PERIOD, SDL_SCANCODE_PERIOD}, {KEY_SLASH, SDL_SCANCODE_SLASH},
    {KEY_F1, SDL_SCANCODE_F1}, {KEY_F2, SDL_SCANCODE_F2},
    {KEY_F3, SDL_SCANCODE_F3}, {KEY_F4, SDL_SCANCODE_F4},
    {KEY_UP, SDL_SCANCODE_UP}, {KEY_DOWN, SDL_SCANCODE_DOWN},
    {KEY_LEFT, SDL_SCANCODE_LEFT}, {KEY_RIGHT, SDL_SCANCODE_RIGHT},
    {KEY_RCTRL, SDL_SCANCODE_RCTRL}, {KEY_RALT, SDL_SCANCODE_RALT},
    {KEY_HOME, SDL_SCANCODE_HOME}, {KEY_END, SDL_SCANCODE_END},
    {KEY_PGUP, SDL_SCANCODE_PAGEUP}, {KEY_PGDN, SDL_SCANCODE_PAGEDOWN},
    {KEY_DELETE, SDL_SCANCODE_DELETE},
    {KEY_KP8, SDL_SCANCODE_KP_8}, {KEY_KP2, SDL_SCANCODE_KP_2},
    {KEY_KP4, SDL_SCANCODE_KP_4}, {KEY_KP6, SDL_SCANCODE_KP_6},
};

static void save_ppm(const char *path)
{
    FILE *f = fopen(path, "wb");
    if (!f) return;
    fprintf(f, "P6\n%d %d\n255\n", SCREEN_W, SCREEN_H);
    for (int i = 0; i < SCREEN_W * SCREEN_H; i++) {
        uint8_t p = fb_buf[i];
        uint8_t rgb[3] = {
            (uint8_t)(((p >> 5) & 7) * 255 / 7),
            (uint8_t)(((p >> 2) & 7) * 255 / 7),
            (uint8_t)((p & 3) * 255 / 3)
        };
        fwrite(rgb, 1, 3, f);
    }
    fclose(f);
    printf("tangkapan layar disimpan: %s\n", path);
}

static void quit(void)
{
    const char *shot = getenv("HAL_SCREENSHOT");
    if (shot) save_ppm(shot);
    SDL_Quit();
    exit(0);
}

void hal_init(void)
{
    SDL_SetMainReady();
    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        fprintf(stderr, "SDL_Init gagal: %s\n", SDL_GetError());
        exit(1);
    }
    win = SDL_CreateWindow("RV32 Game Kit (PC)", SDL_WINDOWPOS_CENTERED,
                           SDL_WINDOWPOS_CENTERED, SCREEN_W * 4, SCREEN_H * 4, 0);
    ren = SDL_CreateRenderer(win, -1, 0);
    if (!win || !ren) {
        fprintf(stderr, "SDL gagal membuat jendela: %s\n", SDL_GetError());
        exit(1);
    }
    tex = SDL_CreateTexture(ren, SDL_PIXELFORMAT_ARGB8888,
                            SDL_TEXTUREACCESS_STREAMING, SCREEN_W, SCREEN_H);
    const char *mf = getenv("HAL_FRAMES");
    max_frames = mf ? (uint32_t)atoi(mf) : 0;
    srand((unsigned)SDL_GetTicks() ^ 0x5EED);
    next_tick = SDL_GetTicks();
}

static void present(void)
{
    static uint32_t pix[SCREEN_W * SCREEN_H];
    for (int i = 0; i < SCREEN_W * SCREEN_H; i++) {
        uint8_t p = fb_buf[i];
        uint32_t r = ((p >> 5) & 7) * 255 / 7, g = ((p >> 2) & 7) * 255 / 7, b = (p & 3) * 255 / 3;
        pix[i] = 0xFF000000u | (r << 16) | (g << 8) | b;
    }
    SDL_UpdateTexture(tex, NULL, pix, SCREEN_W * 4);
    SDL_RenderClear(ren);
    SDL_RenderCopy(ren, tex, NULL, NULL);
    SDL_RenderPresent(ren);
}

void wait_vsync(void)
{
    present();

    SDL_Event e;
    while (SDL_PollEvent(&e)) {
        if (e.type == SDL_QUIT) quit();
        if (e.type == SDL_KEYDOWN && !e.key.repeat) {
            if (e.key.keysym.scancode == SDL_SCANCODE_F12) save_ppm("screenshot.ppm");
            for (size_t i = 0; i < sizeof keymap / sizeof keymap[0]; i++)
                if (keymap[i].sc == e.key.keysym.scancode)
                    last_evt = ((last_evt >> 16) + 1) << 16 | (keymap[i].key & 0x7F) |
                               ((keymap[i].key & 0x80) ? 0x100 : 0);
        }
    }

    /* jaga 60 FPS */
    next_tick += 17;
    uint32_t now = SDL_GetTicks();
    if ((int32_t)(next_tick - now) > 0) SDL_Delay(next_tick - now);
    else next_tick = now;

    const Uint8 *ks = SDL_GetKeyboardState(NULL);
    for (int i = 0; i < 8; i++) {
        hal_keys_prev[i] = hal_keys_now[i];
        hal_keys_now[i] = 0;
    }
    for (size_t i = 0; i < sizeof keymap / sizeof keymap[0]; i++)
        if (ks[keymap[i].sc])
            hal_keys_now[keymap[i].key >> 5] |= 1u << (keymap[i].key & 31);

    frames++;
    if (max_frames && frames >= max_frames) quit();
}

uint32_t frame_count(void) { return frames; }
uint16_t rand16(void)      { return (uint16_t)(rand() & 0xFFFF); }
uint32_t key_last_event(void) { return last_evt; }
uint16_t sw_read(void)     { return 0; }

void seg7_hex(uint16_t v)
{
    if (v != seg7_val) {
        char title[64];
        seg7_val = v;
        snprintf(title, sizeof title, "RV32 Game Kit (PC)  |  7-segment: %04X", v);
        SDL_SetWindowTitle(win, title);
    }
}

void led_set(uint16_t v) { (void)v; }
