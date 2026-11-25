/*
 * libmini.c -- Pustaka minimal untuk RV32I tanpa pustaka standar C.
 *
 * RV32I tidak punya instruksi perkalian/pembagian. Bila kode C memakai * / %
 * dengan variabel, compiler memanggil fungsi __mulsi3, __divsi3, dst. di bawah
 * (dihitung dengan geser dan tambah/kurang). Setelah ekstensi M ditambahkan ke
 * inti dan program di-compile dengan MARCH=rv32im, compiler langsung memakai
 * instruksi mul/div sehingga jauh lebih cepat.
 *
 * Juga berisi memset/memcpy/memmove/memcmp yang kadang dipanggil compiler
 * (mis. untuk menyalin struct).
 */
#include <stdint.h>
#include <stddef.h>

unsigned int __mulsi3(unsigned int a, unsigned int b)
{
    unsigned int r = 0;
    while (b) {
        if (b & 1) r += a;
        a <<= 1;
        b >>= 1;
    }
    return r;
}

static unsigned int udivmod(unsigned int n, unsigned int d, unsigned int *rem)
{
    unsigned int q = 0, r = 0;
    if (d == 0) { if (rem) *rem = n; return 0xFFFFFFFFu; }   /* perilaku RISC-V */
    for (int i = 31; i >= 0; i--) {
        r = (r << 1) | ((n >> i) & 1);
        if (r >= d) { r -= d; q |= 1u << i; }
    }
    if (rem) *rem = r;
    return q;
}

unsigned int __udivsi3(unsigned int a, unsigned int b) { return udivmod(a, b, 0); }
unsigned int __umodsi3(unsigned int a, unsigned int b) { unsigned int r; udivmod(a, b, &r); return r; }

int __divsi3(int a, int b)
{
    int neg = (a < 0) ^ (b < 0);
    unsigned int q = udivmod(a < 0 ? -(unsigned)a : (unsigned)a,
                             b < 0 ? -(unsigned)b : (unsigned)b, 0);
    if (b == 0) return -1;
    return neg ? -(int)q : (int)q;
}

int __modsi3(int a, int b)
{
    unsigned int r;
    udivmod(a < 0 ? -(unsigned)a : (unsigned)a, b < 0 ? -(unsigned)b : (unsigned)b, &r);
    if (b == 0) return a;
    return a < 0 ? -(int)r : (int)r;
}

void *memset(void *s, int c, size_t n)
{
    uint8_t *p = s;
    while (n--) *p++ = (uint8_t)c;
    return s;
}

void *memcpy(void *dst, const void *src, size_t n)
{
    uint8_t *d = dst;
    const uint8_t *s = src;
    while (n--) *d++ = *s++;
    return dst;
}

void *memmove(void *dst, const void *src, size_t n)
{
    uint8_t *d = dst;
    const uint8_t *s = src;
    if (d < s) { while (n--) *d++ = *s++; }
    else       { d += n; s += n; while (n--) *--d = *--s; }
    return dst;
}

int memcmp(const void *a, const void *b, size_t n)
{
    const uint8_t *p = a, *q = b;
    for (; n; n--, p++, q++)
        if (*p != *q) return *p - *q;
    return 0;
}
