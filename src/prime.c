#include "prime.h"
#include <stdlib.h>
#include <time.h>
#include <stdio.h>
#include <inttypes.h>
#include <string.h>

static inline uint64_t modmul(uint64_t a, uint64_t b, uint64_t mod) {
    __uint128_t res = (__uint128_t)a * b;
    res %= mod;
    return (uint64_t)res;
}

static inline uint64_t modpow(uint64_t a, uint64_t d, uint64_t mod) {
    uint64_t res = 1;
    while (d) {
        if (d & 1) res = modmul(res, a, mod);
        a = modmul(a, a, mod);
        d >>= 1;
    }
    return res;
}

int is_probable_prime(uint64_t n) {
    if (n < 2) return 0;
    static const uint64_t small[] = {2,3,5,7,11,13,17,19,23,29,31,37};
    for (size_t i=0;i<sizeof(small)/sizeof(small[0]);++i) {
        if (n == small[i]) return 1;
        if (n % small[i] == 0) return 0;
    }
    uint64_t d = n - 1; int s = 0;
    while ((d & 1) == 0) { d >>= 1; s++; }
    uint64_t bases[] = {2,325,9375,28178,450775,9780504,1795265022};
    for (size_t i=0;i<sizeof(bases)/sizeof(bases[0]);++i) {
        uint64_t a = bases[i] % (n-1) + 1;
        uint64_t x = modpow(a, d, n);
        if (x == 1 || x == n-1) continue;
        int composite = 1;
        for (int r=1;r<s;++r) {
            x = modmul(x, x, n);
            if (x == n-1) { composite = 0; break; }
        }
        if (composite) return 0;
    }
    return 1;
}

__attribute__((constructor))
static void initrand() {
    srand(time(NULL) ^ (uintptr_t)&initrand);
}

uint64_t gen_random_of_digits(int digits) {
    if (digits <= 0) return 0;
    uint64_t low = 1;
    for (int i=1;i<digits;++i) low *= 10ULL;
    uint64_t high = low * 10ULL - 1ULL;
    uint64_t range = high - low + 1ULL;
    uint64_t x = ((uint64_t)rand() << 32) ^ ((uint64_t)rand() << 16) ^ (uint64_t)rand();
    uint64_t val = low + (x % range);
    if ((val & 1) == 0) val |= 1;
    return val;
}

char *u64_to_str(uint64_t v) {
    char buf[32];
    snprintf(buf, sizeof(buf), "%" PRIu64, v);
    return strdup(buf);
}
