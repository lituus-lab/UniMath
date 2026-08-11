// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 lituus-lab
/* Head-to-head speed benchmark: the UniMath C ABI vs the native GMP/MPFR/MPC
 * oracles at matching precision. One binary links libUniMath.a + libmpc +
 * libmpfr + libgmp, runs identical workloads through both, and prints ns/op
 * plus the UniMath/oracle ratio (<1.0 means UniMath is faster).
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
 *   - The complex sections are split by ABI shape, because the fair oracle
 *     column differs. `Complex[float64]` crosses the boundary BY VALUE and
 *     allocates nothing, so its match is MPC-reuse, and MPC runs at 53 bits to
 *     hold the precision equal. `Complex[BigFloat]` is handle-based like the
 *     BigFloat scalars, so its match is MPC-alloc at 256 bits. Comparing the
 *     float64 row against a 256-bit oracle would flatter UniMath by three
 *     orders of magnitude and mean nothing.
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
#include <mpc.h>
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

static void row_reuse(const char *name, double um, double reuse, double alloc) {
  printf("  %-22s | uni %10.2f | orc-reuse %10.2f | orc-alloc %10.2f"
         " | uni/orc-reuse %.2f\n",
         name, um, reuse, alloc, um / reuse);
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

/* ---- Complex over float64: value ABI vs MPC at 53 bits ----
 * `unimath_complex` is two doubles in registers, so there is no handle to
 * free and no allocation to match; MPC-reuse is the comparable model. MPC is
 * held at 53 bits so both sides carry the same precision. */
typedef struct { unimath_complex a, b; } UmCx;
#define UM_CX1(NAME, API)                                                      \
  static void NAME(void *p, long n) {                                          \
    UmCx *c = p;                                                               \
    for (long i = 0; i < n; i++) {                                             \
      unimath_complex r = API(c->a);                                           \
      g_sink += (long double)r.re;                                             \
    }                                                                          \
  }
#define UM_CX2(NAME, API)                                                      \
  static void NAME(void *p, long n) {                                          \
    UmCx *c = p;                                                               \
    for (long i = 0; i < n; i++) {                                             \
      unimath_complex r = API(c->a, c->b);                                     \
      g_sink += (long double)r.re;                                             \
    }                                                                          \
  }
UM_CX2(um_cx_mul, unimath_complex_mul)
UM_CX2(um_cx_div, unimath_complex_div)
UM_CX1(um_cx_sqrt, unimath_complex_sqrt)
UM_CX1(um_cx_exp, unimath_complex_exp)
UM_CX1(um_cx_ln, unimath_complex_ln)
UM_CX1(um_cx_sin, unimath_complex_sin)

/* ---- Complex over BigFloat: handle ABI vs MPC at 256 bits ---- */
typedef struct { unimath_complex_bigfloat a, b; } UmCxBf;
#define UM_CXBF1(NAME, API)                                                    \
  static void NAME(void *p, long n) {                                          \
    UmCxBf *c = p;                                                             \
    for (long i = 0; i < n; i++) {                                             \
      unimath_complex_bigfloat r = API(c->a);                                  \
      g_sink += (long double)(unsigned long long)(size_t)r;                    \
      unimath_complex_bigfloat_destroy(r);                                     \
    }                                                                          \
  }
#define UM_CXBF2(NAME, API)                                                    \
  static void NAME(void *p, long n) {                                          \
    UmCxBf *c = p;                                                             \
    for (long i = 0; i < n; i++) {                                             \
      unimath_complex_bigfloat r = API(c->a, c->b);                            \
      g_sink += (long double)(unsigned long long)(size_t)r;                    \
      unimath_complex_bigfloat_destroy(r);                                     \
    }                                                                          \
  }
UM_CXBF2(um_cxbf_mul, unimath_complex_bigfloat_mul)
UM_CXBF2(um_cxbf_div, unimath_complex_bigfloat_div)
UM_CXBF1(um_cxbf_sqrt, unimath_complex_bigfloat_sqrt)
UM_CXBF1(um_cxbf_exp, unimath_complex_bigfloat_exp)
UM_CXBF1(um_cxbf_ln, unimath_complex_bigfloat_ln)
UM_CXBF1(um_cxbf_sin, unimath_complex_bigfloat_sin)

/* ---- MPC, both precisions. `prec` travels in the context so one macro pair
 * serves the 53-bit and the 256-bit sections. ---- */
typedef struct { mpc_t a, b, r; } MpcReuse;
typedef struct { mpc_t a, b; mpfr_prec_t prec; } MpcAlloc;
#define MPC_REUSE1(NAME, API)                                                  \
  static void NAME(void *p, long n) {                                          \
    MpcReuse *c = p;                                                           \
    for (long i = 0; i < n; i++) {                                             \
      API(c->r, c->a, MPC_RNDNN);                                              \
      g_sink += (long double)mpfr_get_d(mpc_realref(c->r), MPFR_RNDN);         \
    }                                                                          \
  }
#define MPC_REUSE2(NAME, API)                                                  \
  static void NAME(void *p, long n) {                                          \
    MpcReuse *c = p;                                                           \
    for (long i = 0; i < n; i++) {                                             \
      API(c->r, c->a, c->b, MPC_RNDNN);                                        \
      g_sink += (long double)mpfr_get_d(mpc_realref(c->r), MPFR_RNDN);         \
    }                                                                          \
  }
#define MPC_ALLOC1(NAME, API)                                                  \
  static void NAME(void *p, long n) {                                          \
    MpcAlloc *c = p;                                                           \
    mpc_t r;                                                                   \
    for (long i = 0; i < n; i++) {                                             \
      mpc_init2(r, c->prec);                                                   \
      API(r, c->a, MPC_RNDNN);                                                 \
      g_sink += (long double)mpfr_get_d(mpc_realref(r), MPFR_RNDN);            \
      mpc_clear(r);                                                            \
    }                                                                          \
  }
#define MPC_ALLOC2(NAME, API)                                                  \
  static void NAME(void *p, long n) {                                          \
    MpcAlloc *c = p;                                                           \
    mpc_t r;                                                                   \
    for (long i = 0; i < n; i++) {                                             \
      mpc_init2(r, c->prec);                                                   \
      API(r, c->a, c->b, MPC_RNDNN);                                           \
      g_sink += (long double)mpfr_get_d(mpc_realref(r), MPFR_RNDN);            \
      mpc_clear(r);                                                            \
    }                                                                          \
  }
MPC_REUSE2(mpc_mul_reuse, mpc_mul)
MPC_REUSE2(mpc_div_reuse, mpc_div)
MPC_REUSE1(mpc_sqrt_reuse, mpc_sqrt)
MPC_REUSE1(mpc_exp_reuse, mpc_exp)
MPC_REUSE1(mpc_ln_reuse, mpc_log)
MPC_REUSE1(mpc_sin_reuse, mpc_sin)
MPC_ALLOC2(mpc_mul_alloc, mpc_mul)
MPC_ALLOC2(mpc_div_alloc, mpc_div)
MPC_ALLOC1(mpc_sqrt_alloc, mpc_sqrt)
MPC_ALLOC1(mpc_exp_alloc, mpc_exp)
MPC_ALLOC1(mpc_ln_alloc, mpc_log)
MPC_ALLOC1(mpc_sin_alloc, mpc_sin)

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
  printf("UniMath %s vs GMP/MPFR/MPC; ns/op, lower is faster\n",
         unimath_version());
  printf("  ratio = UniMath / oracle  (<1.0 => UniMath faster); BigFloat and complex-256 at 256 bits\n");
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

  /* Complex over float64 vs MPC at 53 bits. Ratio against orc-reuse: the
     value ABI allocates nothing, so orc-alloc would charge MPC for a model
     UniMath never pays for. */
  {
    printf("  -- complex, float64 value ABI vs MPC at 53 bits"
           " (ratio vs orc-reuse) --\n");
    struct { const char *name; int binary; bench_fn um, reuse, alloc; long n; } ops[] = {
      {"Complex mul f64",  1, um_cx_mul,  mpc_mul_reuse,  mpc_mul_alloc,  200000},
      {"Complex div f64",  1, um_cx_div,  mpc_div_reuse,  mpc_div_alloc,  200000},
      {"Complex sqrt f64", 0, um_cx_sqrt, mpc_sqrt_reuse, mpc_sqrt_alloc, 100000},
      {"Complex exp f64",  0, um_cx_exp,  mpc_exp_reuse,  mpc_exp_alloc,  100000},
      {"Complex ln f64",   0, um_cx_ln,   mpc_ln_reuse,   mpc_ln_alloc,   100000},
      {"Complex sin f64",  0, um_cx_sin,  mpc_sin_reuse,  mpc_sin_alloc,  100000},
    };
    for (size_t i = 0; i < sizeof(ops) / sizeof(ops[0]); i++) {
      (void)ops[i].binary;
      UmCx u = {unimath_complex_from_f64(1.5, 0.75),
                unimath_complex_from_f64(3.0, -1.25)};
      MpcReuse g;
      mpc_init2(g.a, 53); mpc_init2(g.b, 53); mpc_init2(g.r, 53);
      mpc_set_d_d(g.a, 1.5, 0.75, MPC_RNDNN);
      mpc_set_d_d(g.b, 3.0, -1.25, MPC_RNDNN);
      MpcAlloc ga;
      mpc_init2(ga.a, 53); mpc_init2(ga.b, 53); ga.prec = 53;
      mpc_set_d_d(ga.a, 1.5, 0.75, MPC_RNDNN);
      mpc_set_d_d(ga.b, 3.0, -1.25, MPC_RNDNN);
      row_reuse(ops[i].name, timeit(ops[i].um, &u, ops[i].n),
                timeit(ops[i].reuse, &g, ops[i].n),
                timeit(ops[i].alloc, &ga, ops[i].n));
      mpc_clear(g.a); mpc_clear(g.b); mpc_clear(g.r);
      mpc_clear(ga.a); mpc_clear(ga.b);
    }
  }
  /* Complex over BigFloat vs MPC at 256 bits. Handle ABI on both sides, so
     the ratio is against orc-alloc as elsewhere in this file. */
  {
    printf("  -- complex, BigFloat handle ABI vs MPC at 256 bits"
           " (ratio vs orc-alloc) --\n");
    struct { const char *name; bench_fn um, reuse, alloc; long n; } ops[] = {
      {"Complex mul 256",  um_cxbf_mul,  mpc_mul_reuse,  mpc_mul_alloc,  20000},
      {"Complex div 256",  um_cxbf_div,  mpc_div_reuse,  mpc_div_alloc,  20000},
      {"Complex sqrt 256", um_cxbf_sqrt, mpc_sqrt_reuse, mpc_sqrt_alloc, 5000},
      {"Complex exp 256",  um_cxbf_exp,  mpc_exp_reuse,  mpc_exp_alloc,  2000},
      {"Complex ln 256",   um_cxbf_ln,   mpc_ln_reuse,   mpc_ln_alloc,   5000},
      {"Complex sin 256",  um_cxbf_sin,  mpc_sin_reuse,  mpc_sin_alloc,  2000},
    };
    for (size_t i = 0; i < sizeof(ops) / sizeof(ops[0]); i++) {
      UmCxBf u = {unimath_complex_bigfloat_from_f64(1.5, 0.75),
                  unimath_complex_bigfloat_from_f64(3.0, -1.25)};
      MpcReuse g;
      mpc_init2(g.a, 256); mpc_init2(g.b, 256); mpc_init2(g.r, 256);
      mpc_set_d_d(g.a, 1.5, 0.75, MPC_RNDNN);
      mpc_set_d_d(g.b, 3.0, -1.25, MPC_RNDNN);
      MpcAlloc ga;
      mpc_init2(ga.a, 256); mpc_init2(ga.b, 256); ga.prec = 256;
      mpc_set_d_d(ga.a, 1.5, 0.75, MPC_RNDNN);
      mpc_set_d_d(ga.b, 3.0, -1.25, MPC_RNDNN);
      row(ops[i].name, timeit(ops[i].um, &u, ops[i].n),
          timeit(ops[i].reuse, &g, ops[i].n),
          timeit(ops[i].alloc, &ga, ops[i].n));
      unimath_complex_bigfloat_destroy(u.a);
      unimath_complex_bigfloat_destroy(u.b);
      mpc_clear(g.a); mpc_clear(g.b); mpc_clear(g.r);
      mpc_clear(ga.a); mpc_clear(ga.b);
    }
  }

  printf("  checksum = %Lg (keeps every result live)\n", g_sink);
  unimath_cleanup();
  return 0;
}