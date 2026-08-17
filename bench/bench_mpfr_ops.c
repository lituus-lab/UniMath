/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 lituus-lab */
/* What does ONE MPFR/GMP operation cost at 256 bits?
 *
 * The transcendental gap (exp 2.8x, sin 3.0x) could be a difference in how many
 * operations each library performs, or in what one operation costs. Those want
 * opposite fixes -- a better series against a cheaper primitive -- so measuring
 * the primitive settles which work is worth doing.
 *
 * Both an mpfr_t-reused form (the fastest idiomatic usage, no allocation) and an
 * init/clear-per-call form, because UniMath's value API allocates per operation
 * and only the second is comparable to it.
 *
 * Build and run:  make -C bench mpfrops
 */
#include <gmp.h>
#include <mpfr.h>
#include <stdio.h>
#include <time.h>

#define PREC 256
#define REPS 2000000

static double now_ns(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return ts.tv_sec * 1e9 + ts.tv_nsec;
}

int main(void) {
  mpfr_t a, b, r;
  mpfr_inits2(PREC, a, b, r, (mpfr_ptr)0);
  mpfr_set_d(a, 1.4142135623730951, MPFR_RNDN);
  mpfr_set_d(b, 1.7320508075688772, MPFR_RNDN);

  double t0, best;
  printf("MPFR %s / GMP %s, %d bits, best of 5 x %d\n",
         mpfr_get_version(), gmp_version, PREC, REPS);
  printf("| op | reused (ns) | init+clear (ns) |\n");
  printf("|---|---|---|\n");

/* Two expressions, not one. The allocated form has to compute INTO the fresh
 * mpfr_t: reusing `r` and copying afterwards measures the reused operation plus
 * an mpfr_set, which is a different thing and understates the allocation. */
#define BENCH(name, reuse_call, alloc_call)                                   \
  do {                                                                        \
    best = 1e30;                                                              \
    for (int k = 0; k < 5; k++) {                                             \
      t0 = now_ns();                                                          \
      for (int i = 0; i < REPS; i++) { reuse_call; }                          \
      double d = (now_ns() - t0) / REPS;                                      \
      if (d < best) best = d;                                                 \
    }                                                                         \
    double reused = best;                                                     \
    best = 1e30;                                                              \
    for (int k = 0; k < 5; k++) {                                             \
      t0 = now_ns();                                                          \
      for (int i = 0; i < REPS; i++) {                                        \
        mpfr_t tmp;                                                           \
        mpfr_init2(tmp, PREC);                                                \
        alloc_call;                                                           \
        mpfr_clear(tmp);                                                      \
      }                                                                       \
      double d = (now_ns() - t0) / REPS;                                      \
      if (d < best) best = d;                                                 \
    }                                                                         \
    printf("| %s | %.1f | %.1f |\n", name, reused, best);                     \
  } while (0)

  BENCH("mpfr_mul", mpfr_mul(r, a, b, MPFR_RNDN),
        mpfr_mul(tmp, a, b, MPFR_RNDN));
  BENCH("mpfr_add", mpfr_add(r, a, b, MPFR_RNDN),
        mpfr_add(tmp, a, b, MPFR_RNDN));
  BENCH("mpfr_sub", mpfr_sub(r, a, b, MPFR_RNDN),
        mpfr_sub(tmp, a, b, MPFR_RNDN));
  BENCH("mpfr_div", mpfr_div(r, a, b, MPFR_RNDN),
        mpfr_div(tmp, a, b, MPFR_RNDN));
  BENCH("mpfr_sqrt", mpfr_sqrt(r, a, MPFR_RNDN), mpfr_sqrt(tmp, a, MPFR_RNDN));
  BENCH("mpfr_mul_ui", mpfr_mul_ui(r, a, 7, MPFR_RNDN),
        mpfr_mul_ui(tmp, a, 7, MPFR_RNDN));
  BENCH("mpfr_div_ui", mpfr_div_ui(r, a, 7, MPFR_RNDN),
        mpfr_div_ui(tmp, a, 7, MPFR_RNDN));

  /* The raw integer multiply underneath, for the BigInt comparison. */
  mpz_t x, y, z;
  mpz_inits(x, y, z, (mpz_ptr)0);
  mpz_ui_pow_ui(x, 3, 200);
  mpz_ui_pow_ui(y, 5, 150);
  best = 1e30;
  for (int k = 0; k < 5; k++) {
    t0 = now_ns();
    for (int i = 0; i < REPS / 4; i++) mpz_mul(z, x, y);
    double d = (now_ns() - t0) / (REPS / 4);
    if (d < best) best = d;
  }
  printf("| mpz_mul (~320x350 bits) | %.1f | - |\n", best);

  mpfr_clears(a, b, r, (mpfr_ptr)0);
  mpz_clears(x, y, z, (mpz_ptr)0);
  mpfr_free_cache();
  return 0;
}
