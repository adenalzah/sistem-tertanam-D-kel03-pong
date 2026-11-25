/* hal_internal.h -- dipakai bersama oleh gfx.c, hal_rv.c, dan hal_pc.c (bukan untuk kode game) */
#ifndef HAL_INTERNAL_H
#define HAL_INTERNAL_H
#include <stdint.h>

extern volatile uint8_t *const hal_fb;   /* alamat framebuffer 160x120          */
extern uint32_t hal_keys_now[8];         /* status 256 tombol, frame ini        */
extern uint32_t hal_keys_prev[8];        /* status 256 tombol, frame sebelumnya */
void hal_merge_buttons(uint32_t btn);    /* bit 0..4 = btnU, btnD, btnL, btnR, btnC */

#endif
