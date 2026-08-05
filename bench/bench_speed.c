// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 lituus-lab
/* Head-to-head speed benchmark: the UniMath C ABI vs the native GMP/MPFR
 * oracles at matching precision. One binary links libUniMath.a + libmpfr +
 * libgmp, runs identical workloads through both, and prints ns/op plus the
 * UniMath/oracle ratio (<1.0 means UniMath is faster).
 *
 * Fairness notes (also in bench/README.md):
 *   - UniMath's handle ABI allocates a new result per op and the caller frees
 *     it (`*_destroy`). To match that allocation model on the oracle side, each
 *     op is timed twice for GMP/MPFR: "reuse" (init the result once, overwrite
 *     it every iter — the idiomatic, fastest oracle usage) and "alloc/op" (init
 *     + clear the result every iter — the apples-to-apples match to UniMath).
 *   - BigFloat precision is 256 bits on both sides (UniMath default; MPFR
 *     mpfr_init2(.., 256)). BigInt operand sizes are matched by construction.
 *   - `g_sink` accumulates a checksum of every result so the -O2 optimizer
 *     cannot dead-code-eliminate the pure bodies.
 *
 * Build: `nimble benchSpeed` (needs libmpfr/libgmp via pkg-config; not in the
 * default gate). */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <math.h>
#include <gmp.h>
#include <mpfr.h>
#include "UniMath.h"

static long double g_sink = 0.0;

static double now_s(void) {
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return (double)t.tv_sec + (double)t.tv_nsec * 1e-9;
}

typedef void (*bench_fn)(void *ctx, long iters);

static double timeit(bench_fn f, void *ctx, long iters) {
  double t0 = now_s();
  f(ctx, iters);
  double t1 = now_s();
  return ((t1 - t0) * 1e9) / (double)iters;
}

static void row(const char *name, double um, double reuse, double alloc) {
  printf("  %-22s | uni %10.2f | orc-reuse %10.2f | orc-alloc %10.2f"
         " | uni/orc-alloc %.2f\n",
         name, um, reuse, alloc, um / alloc);
}

/* ---- BigInt mul, 64-bit operands ---- */
typedef struct { unimath_bigint a, b; } UmBB;
static void um_mul(void *p, long n) {
  UmBB *c = p;
  for (long i = 0; i < n; i++) {
    unimath_bigint r = unimath_bigint_mul(c->a, c->b);
    g_sink += (long double)(unsigned long long)(size_t)r;
    unimath_bigint_destroy(r);
  }
}
typedef struct { mpz_t a, b, c; } GmpReuse;
static void gmp_mul_reuse(void *p, long n) {
  GmpReuse *c = p;
  for (long i = 0; i < n; i++) {
    mpz_mul(c->c, c->a, c->b);
    g_sink += (long double)mpz_get_si(c->c);
  }
}
typedef struct { mpz_t a, b; } GmpAlloc;
static void gmp_mul_alloc(void *p, long n) {
  GmpAlloc *c = p;
  mpz_t r;
  for (long i = 0; i < n; i++) {
    mpz_init(r);
    mpz_mul(r, c->a, c->b);
    g_sink += (long double)mpz_get_si(r);
    mpz_clear(r);
  }
}

/* ---- BigInt div, 1024-bit / 64-bit ---- */
static void um_div(void *p, long n) {
  UmBB *c = p; /* a = 1024-bit, b = 64-bit */
  for (long i = 0; i < n; i++) {
    unimath_bigint r = unimath_bigint_div(c->a, c->b);
    g_sink += (long double)(unsigned long long)(size_t)r;
    unimath_bigint_destroy(r);
  }
}
static void gmp_div_reuse(void *p, long n) {
  GmpReuse *c = p;
  for (long i = 0; i < n; i++) {
    mpz_tdiv_q(c->c, c->a, c->b);
    g_sink += (long double)mpz_get_si(c->c);
  }
}
static void gmp_div_alloc(void *p, long n) {
  GmpAlloc *c = p;
  mpz_t r;
  for (long i = 0; i < n; i++) {
    mpz_init(r);
    mpz_tdiv_q(r, c->a, c->b);
    g_sink += (long double)mpz_get_si(r);
    mpz_clear(r);
  }
}

/* ---- BigFloat transcendentals, 256-bit ---- */
typedef struct { unimath_bigfloat x; } UmBF;
#define UM_BF(NAME, API)                                                       \
  static void NAME(void *p, long n) {                                          \
    UmBF *c = p;                                                               \
    for (long i = 0; i < n; i++) {                                             \
      unimath_bigfloat r = API(c->x);                                          \
      g_sink += (long double)(unsigned long long)(size_t)r;                    \
      unimath_bigfloat_destroy(r);                                             \
    }                                                                          \
  }
UM_BF(um_sin, unimath_bigfloat_sin)
UM_BF(um_exp, unimath_bigfloat_exp)
UM_BF(um_ln, unimath_bigfloat_ln)
UM_BF(um_sqrt, unimath_bigfloat_sqrt)

typedef struct { mpfr_t x, r; } MpfrReuse;
typedef struct { mpfr_t x; } MpfrAlloc;
#define MPFR_REUSE(NAME, API)                                                  \
  static void NAME(void *p, long n) {                                          \
    MpfrReuse *c = p;                                                          \
    for (long i = 0; i < n; i++) {                                             \
      API(c->r, c->x, MPFR_RNDN);                                              \
      g_sink += (long double)mpfr_get_d(c->r, MPFR_RNDN);                      \
    }                                                                          \
  }
#define MPFR_ALLOC(NAME, API)                                                  \
  static void NAME(void *p, long n) {                                          \
    MpfrAlloc *c = p;                                                          \
    mpfr_t r;                                                                  \
    for (long i = 0; i < n; i++) {                                             \
      mpfr_init2(r, 256);                                                      \
      API(r, c->x, MPFR_RNDN);                                                 \
      g_sink += (long double)mpfr_get_d(r, MPFR_RNDN);                         \
      mpfr_clear(r);                                                           \
    }                                                                          \
  }
MPFR_REUSE(mpfr_sin_reuse, mpfr_sin)
MPFR_REUSE(mpfr_exp_reuse, mpfr_exp)
MPFR_REUSE(mpfr_ln_reuse, mpfr_log)
MPFR_REUSE(mpfr_sqrt_reuse, mpfr_sqrt)
MPFR_ALLOC(mpfr_sin_alloc, mpfr_sin)
MPFR_ALLOC(mpfr_exp_alloc, mpfr_exp)
MPFR_ALLOC(mpfr_ln_alloc, mpfr_log)
MPFR_ALLOC(mpfr_sqrt_alloc, mpfr_sqrt)

/* Build a ~1024-bit BigInt by squaring a 60-bit seed four times (60 -> 120 ->
 * 240 -> 480 -> 960 bits). Same construction on both sides -> same operands. */
static unimath_bigint um_big1024(void) {
  unimath_bigint a = unimath_bigint_from_i64(1234567890123456789LL);
  for (int i = 0; i < 4; i++) {
    unimath_bigint s = unimath_bigint_mul(a, a);
    unimath_bigint_destroy(a);
    a = s;
  }
  return a;
}
static void gmp_big1024(mpz_t out) {
  mpz_set_si(out, 1234567890123456789LL);
  for (int i = 0; i < 4; i++) mpz_mul(out, out, out);
}

/* Build a ~480-bit BigInt by squaring a 60-bit seed three times (60 -> 120 ->
 * 240 -> 480 bits) — an 8-limb divisor for the multi-limb division bench. */
static unimath_bigint um_big512(void) {
  unimath_bigint a = unimath_bigint_from_i64(1234567890123456789LL);
  for (int i = 0; i < 3; i++) {
    unimath_bigint s = unimath_bigint_mul(a, a);
    unimath_bigint_destroy(a);
    a = s;
  }
  return a;
}
static void gmp_big512(mpz_t out) {
  mpz_set_si(out, 1234567890123456789LL);
  for (int i = 0; i < 3; i++) mpz_mul(out, out, out);
}

int main(void) {
  if (!unimath_init()) { printf("unimath_init failed\n"); return 1; }
  printf("UniMath %s vs GMP/MPFR (256-bit BigFloat); ns/op, lower is faster\n",
         unimath_version());
  printf("  ratio = UniMath / oracle-alloc  (<1.0 => UniMath faster)\n");
  printf("%s\n", "  ----------------------------------------------------------------------------------------------");

  /* BigInt mul 64-bit */
  {
    UmBB u = {unimath_bigint_from_i64(1234567890LL),
              unimath_bigint_from_i64(987654321LL)};
    GmpReuse g; mpz_init_set_si(g.a, 1234567890LL); mpz_init_set_si(g.b, 987654321LL); mpz_init(g.c);
    GmpAlloc ga; mpz_init_set_si(ga.a, 1234567890LL); mpz_init_set_si(ga.b, 987654321LL);
    long n = 1000000;
    row("BigInt mul 64-bit", timeit(um_mul, &u, n),
        timeit(gmp_mul_reuse, &g, n), timeit(gmp_mul_alloc, &ga, n));
    unimath_bigint_destroy(u.a); unimath_bigint_destroy(u.b);
    mpz_clears(g.a, g.b, g.c, NULL); mpz_clears(ga.a, ga.b, NULL);
  }
  /* BigInt mul 1024-bit */
  {
    UmBB u = {um_big1024(), um_big1024()};
    GmpReuse g; mpz_init(g.a); mpz_init(g.b); mpz_init(g.c);
    gmp_big1024(g.a); gmp_big1024(g.b);
    GmpAlloc ga; mpz_init(ga.a); gmp_big1024(ga.a); mpz_init(ga.b); gmp_big1024(ga.b);
    long n = 100000;
    row("BigInt mul 1024-bit", timeit(um_mul, &u, n),
        timeit(gmp_mul_reuse, &g, n), timeit(gmp_mul_alloc, &ga, n));
    unimath_bigint_destroy(u.a); unimath_bigint_destroy(u.b);
    mpz_clears(g.a, g.b, g.c, NULL); mpz_clears(ga.a, ga.b, NULL);
  }
  /* BigInt div 1024/64 */
  {
    UmBB u = {um_big1024(), unimath_bigint_from_i64(987654321LL)};
    GmpReuse g; mpz_init(g.a); mpz_init(g.b); mpz_init(g.c);
    gmp_big1024(g.a); mpz_set_si(g.b, 987654321LL);
    GmpAlloc ga; mpz_init(ga.a); gmp_big1024(ga.a); mpz_init_set_si(ga.b, 987654321LL);
    long n = 100000;
    row("BigInt div 1024/64", timeit(um_div, &u, n),
        timeit(gmp_div_reuse, &g, n), timeit(gmp_div_alloc, &ga, n));
    unimath_bigint_destroy(u.a); unimath_bigint_destroy(u.b);
    mpz_clears(g.a, g.b, g.c, NULL); mpz_clears(ga.a, ga.b, NULL);
  }
  /* BigInt div 1024/512 (multi-limb divisor -> Knuth Algorithm D). */
  {
    UmBB u = {um_big1024(), um_big512()};
    GmpReuse g; mpz_init(g.a); mpz_init(g.b); mpz_init(g.c);
    gmp_big1024(g.a); gmp_big512(g.b);
    GmpAlloc ga; mpz_init(ga.a); gmp_big1024(ga.a); mpz_init(ga.b); gmp_big512(ga.b);
    long n = 100000;
    row("BigInt div 1024/512", timeit(um_div, &u, n),
        timeit(gmp_div_reuse, &g, n), timeit(gmp_div_alloc, &ga, n));
    unimath_bigint_destroy(u.a); unimath_bigint_destroy(u.b);
    mpz_clears(g.a, g.b, g.c, NULL); mpz_clears(ga.a, ga.b, NULL);
  }
  /* BigFloat transcendentals (256-bit). x chosen per op, same on both sides. */
  {
    struct { const char *name; double x; bench_fn um, reuse, alloc; long n; } ops[] = {
      {"BigFloat sin",  1.0, um_sin,  mpfr_sin_reuse,  mpfr_sin_alloc,  2000},
      {"BigFloat exp",  1.0, um_exp,  mpfr_exp_reuse,  mpfr_exp_alloc,  2000},
      {"BigFloat ln",   2.0, um_ln,   mpfr_ln_reuse,   mpfr_ln_alloc,   20000},
      {"BigFloat sqrt", 2.0, um_sqrt, mpfr_sqrt_reuse, mpfr_sqrt_alloc, 5000},
    };
    for (size_t i = 0; i < sizeof(ops) / sizeof(ops[0]); i++) {
      UmBF u = {unimath_bigfloat_from_f64(ops[i].x)};
      MpfrReuse g; mpfr_init2(g.x, 256); mpfr_init2(g.r, 256); mpfr_set_d(g.x, ops[i].x, MPFR_RNDN);
      MpfrAlloc ga; mpfr_init2(ga.x, 256); mpfr_set_d(ga.x, ops[i].x, MPFR_RNDN);
      row(ops[i].name, timeit(ops[i].um, &u, ops[i].n),
          timeit(ops[i].reuse, &g, ops[i].n), timeit(ops[i].alloc, &ga, ops[i].n));
      unimath_bigfloat_destroy(u.x);
      mpfr_clear(g.x); mpfr_clear(g.r); mpfr_clear(ga.x);
    }
  }

  printf("  checksum = %Lg (keeps every result live)\n", g_sink);
  unimath_cleanup();
  return 0;
}