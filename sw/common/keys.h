/*
 * keys.h -- Kode tombol keyboard (PS/2 scancode set 2) untuk key_down()/key_pressed()
 *
 * Tombol biasa   : indeks = scancode            (mis. W = 0x1D)
 * Tombol extended: indeks = 0x80 + scancode     (panah atas = E0 75 -> 0xF5)
 *
 * Tombol board Basys 3 juga terbaca sebagai cadangan:
 *   btnU = KEY_UP, btnD = KEY_DOWN, btnL = KEY_LEFT, btnR = KEY_RIGHT,
 *   btnC = KEY_ENTER dan KEY_SPACE
 */
#ifndef KEYS_H
#define KEYS_H

/* Huruf */
#define KEY_A 0x1C
#define KEY_B 0x32
#define KEY_C 0x21
#define KEY_D 0x23
#define KEY_E 0x24
#define KEY_F 0x2B
#define KEY_G 0x34
#define KEY_H 0x33
#define KEY_I 0x43
#define KEY_J 0x3B
#define KEY_K 0x42
#define KEY_L 0x4B
#define KEY_M 0x3A
#define KEY_N 0x31
#define KEY_O 0x44
#define KEY_P 0x4D
#define KEY_Q 0x15
#define KEY_R 0x2D
#define KEY_S 0x1B
#define KEY_T 0x2C
#define KEY_U 0x3C
#define KEY_V 0x2A
#define KEY_W 0x1D
#define KEY_X 0x22
#define KEY_Y 0x35
#define KEY_Z 0x1A

/* Angka (baris atas) */
#define KEY_0 0x45
#define KEY_1 0x16
#define KEY_2 0x1E
#define KEY_3 0x26
#define KEY_4 0x25
#define KEY_5 0x2E
#define KEY_6 0x36
#define KEY_7 0x3D
#define KEY_8 0x3E
#define KEY_9 0x46

/* Tombol khusus */
#define KEY_SPACE     0x29
#define KEY_ENTER     0x5A
#define KEY_ESC       0x76
#define KEY_BACKSPACE 0x66
#define KEY_TAB       0x0D
#define KEY_LSHIFT    0x12
#define KEY_RSHIFT    0x59
#define KEY_LCTRL     0x14
#define KEY_LALT      0x11
#define KEY_MINUS     0x4E
#define KEY_EQUAL     0x55
#define KEY_COMMA     0x41
#define KEY_PERIOD    0x49
#define KEY_SLASH     0x4A
#define KEY_F1        0x05
#define KEY_F2        0x06
#define KEY_F3        0x04
#define KEY_F4        0x0C

/* Tombol extended (awalan E0) */
#define KEY_UP     (0x80 | 0x75)
#define KEY_DOWN   (0x80 | 0x72)
#define KEY_LEFT   (0x80 | 0x6B)
#define KEY_RIGHT  (0x80 | 0x74)
#define KEY_RCTRL  (0x80 | 0x14)
#define KEY_RALT   (0x80 | 0x11)
#define KEY_HOME   (0x80 | 0x6C)
#define KEY_END    (0x80 | 0x69)
#define KEY_PGUP   (0x80 | 0x7D)
#define KEY_PGDN   (0x80 | 0x7A)
#define KEY_DELETE (0x80 | 0x71)

/* Keypad angka (tanpa NumLock memakai kode yang sama dengan angka keypad) */
#define KEY_KP8 0x75
#define KEY_KP2 0x72
#define KEY_KP4 0x6B
#define KEY_KP6 0x74

#endif
