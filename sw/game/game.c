/*
 * game.c -- KERANGKA GAME (diisi oleh kelompok)
 *
 * Pilih game sesuai yang ditetapkan dosen:
 *   - Pong 2 pemain
 *   - Snake
 *   - Penembak luar angkasa mini
 *
 * Aturan:
 *   - Hanya gunakan fungsi dari hal.h agar game berjalan di laptop DAN di FPGA.
 *   - Uji di laptop :  make pc APP=game
 *   - Jalankan di FPGA: make rv APP=game  lalu Generate Bitstream di Vivado.
 *
 * Tips:
 *   - Jangan hapus seluruh layar setiap frame (fb_clear lambat & berkedip):
 *     hapus objek di posisi lama, lalu gambar di posisi baru (lihat demo.c).
 *   - RV32I tidak punya instruksi kali/bagi: * / % dengan variabel dihitung
 *     software (lebih lambat). Gunakan geser (<<, >>) bila memungkinkan.
 *   - Gunakan state machine untuk layar: menu -> main -> game over -> menu.
 */
#include "hal.h"

typedef enum {
    ST_MENU,        /* TODO: halaman muka */
    ST_PLAY,
    ST_GAMEOVER
} state_t;

typedef struct {
    state_t state;
    int score1, score2;
    /* TODO: posisi, kecepatan, ukuran, array objek, dll. */
} game_t;

static void game_init(game_t *g)
{
    g->state  = ST_PLAY;
    g->score1 = 0;
    g->score2 = 0;
    /* TODO: nilai awal semua objek game */
}

static void game_input(game_t *g)
{
    (void)g;
    /* TODO: baca tombol dengan key_down() / key_pressed()
     *       contoh: if (key_down(KEY_W)) ...                       */
}

static void game_update(game_t *g)
{
    (void)g;
    /* TODO: gerak objek, deteksi tabrakan, aturan skor, kondisi game over */
}

static void game_draw(const game_t *g)
{
    /* Sementara: tampilkan pesan. Ganti dengan tampilan game Anda. */
    static int drawn = 0;
    if (!drawn) {
        fb_clear(COLOR_BLACK);
        fb_text(4, 4, "GAME BELUM DIBUAT", COLOR_WHITE);
        fb_text(4, 12, "LENGKAPI SW/GAME/GAME.C", COLOR_GRAY);
        drawn = 1;
    }
    score_show(g->score1, g->score2);
}

int main(void)
{
    game_t g;
    hal_init();
    game_init(&g);
    for (;;) {
        wait_vsync();
        game_input(&g);
        game_update(&g);
        game_draw(&g);
    }
}
