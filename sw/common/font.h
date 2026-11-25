/* font.h -- DIBANGKITKAN OTOMATIS oleh tools/gen_font.py. Jangan disunting manual. */
/* Glyph 3x5: bit (baris*3 + (2-kolom)) = 1 berarti piksel menyala. */
#ifndef FONT_H
#define FONT_H
#include <stdint.h>
#define FONT_FIRST 0x20
#define FONT_LAST  0x5F
static const uint16_t font3x5[FONT_LAST - FONT_FIRST + 1] = {
    0x0000, /* ' ' */
    0x2092, /* '!' */
    0x002D, /* '"' */
    0x5F7D, /* '#' */
    0x66B3, /* '$' */
    0x188C, /* '%' */
    0x3AAA, /* '&' */
    0x0012, /* ''' */
    0x1491, /* '(' */
    0x4494, /* ')' */
    0x0AA8, /* '*' */
    0x05D0, /* '+' */
    0x4400, /* ',' */
    0x01C0, /* '-' */
    0x2000, /* '.' */
    0x4889, /* '/' */
    0x7B6F, /* '0' */
    0x74B2, /* '1' */
    0x79CF, /* '2' */
    0x72CF, /* '3' */
    0x13ED, /* '4' */
    0x73E7, /* '5' */
    0x7BE7, /* '6' */
    0x244F, /* '7' */
    0x7BEF, /* '8' */
    0x73EF, /* '9' */
    0x0410, /* ':' */
    0x4410, /* ';' */
    0x1511, /* '<' */
    0x0E38, /* '=' */
    0x4454, /* '>' */
    0x20CF, /* '?' */
    0x79EF, /* '@' */
    0x5BEA, /* 'A' */
    0x6BAE, /* 'B' */
    0x3923, /* 'C' */
    0x6B6E, /* 'D' */
    0x79A7, /* 'E' */
    0x49A7, /* 'F' */
    0x3B63, /* 'G' */
    0x5BED, /* 'H' */
    0x7497, /* 'I' */
    0x2A49, /* 'J' */
    0x5BAD, /* 'K' */
    0x7924, /* 'L' */
    0x5BFD, /* 'M' */
    0x5B6E, /* 'N' */
    0x2B6A, /* 'O' */
    0x49AE, /* 'P' */
    0x3D6A, /* 'Q' */
    0x5BAE, /* 'R' */
    0x62A3, /* 'S' */
    0x2497, /* 'T' */
    0x7B6D, /* 'U' */
    0x2B6D, /* 'V' */
    0x5FED, /* 'W' */
    0x5AAD, /* 'X' */
    0x24AD, /* 'Y' */
    0x788F, /* 'Z' */
    0x6926, /* '[' */
    0x12A4, /* 'backslash' */
    0x324B, /* ']' */
    0x002A, /* '^' */
    0x7000, /* '_' */
};
#endif
