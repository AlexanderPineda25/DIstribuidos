#ifndef PRIME_H
#define PRIME_H

#include <stdint.h>

int is_probable_prime(uint64_t n);
uint64_t gen_random_of_digits(int digits);
char *u64_to_str(uint64_t v);

#endif
