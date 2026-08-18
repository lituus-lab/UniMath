<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# UniMath

A multi-precision numeric library: arbitrary-precision integers, fixed-point,
big floats, rationals, and intervals, with the transcendental and
special-function algorithms over them. Exposed in Nim, a C ABI, and Python.

## What's inside

- **Exact integers & fixed-point** — `BigInt` (arbitrary-precision, `arithmetic/`)
  and `Fixed[T, Frac]` (Q-format fixed-point).
- **Big floats & rationals** — `BigFloat` (arbitrary-precision, `float/`) and
  `Rational[T]` (exact fractions, `rational/`, reduced to lowest terms).
- **Intervals** — `Interval[T]` (`interval/`) with directed-rounding
  arithmetic and transcendentals.
- **Native float64 facade** (`native_float.nim`) — zero-wrapper-overhead
  access to host-libm roots, logarithms, exponentials, trigonometry and
  hypotenuse operations for higher-level Uni* consumers.
- **Transcendentals** (`exponential/`, `trigonometry/`, `hyperbolic/`,
  `special/`, `roots/`) — the same algorithms (sin/cos/exp/ln/sqrt/atan/...)
  implemented across three backends: `BigFloat` (`float_math.nim`), `Fixed`
  (`math_router.nim`), and `Rational[BigInt]` (`rational_math.nim`).
- **Complex numbers** — `Complex[T]` (`complex/`) pairs any `Field` component,
  and its arithmetic needs nothing more. The modulus, argument, roots and
  transcendentals in `complex_math.nim` ask for an ordered component carrying
  `sqrt`/`abs`/`arctan2` on top, which `float32`/`float64`, `BigFloat`,
  `Rational[T]` and `Fixed[T, FracBits]` supply.
  `csqrt(-1.0)` is `0+1i` where the real `sqrt` refuses;
  from Python, where the return type can follow the value, `unimath.sqrt(-1)`
  returns `1j` and `unimath.sqrt(4)` returns `2.0`.
- **Error-free transforms** (`eft.nim`) — a re-export of UniAccurate's EFT
  primitives (`twoSum`, `twoProduct`, Shewchuk expansions); UniMath adds no
  EFT code of its own (ADR-0006).

## The Uni* family

UniMath is layer 2 of `lituus-lab`'s `Uni*` family: a set of Nim libraries,
each with a C ABI and a Python binding, unified by a shared dependency DAG and
documentation/testing conventions. See
[lituus-lab/.github](https://github.com/lituus-lab/.github) for the family's
purpose and philosophy. UniMath depends on UniAccurate (layer 1) for its
error-free transforms; UniLinalg (layer 3) depends on UniMath in turn, for
`Vector`'s exact-precision arithmetic.

## Provenance & development

The numeric types and transcendental algorithms here are textbook (long
division, CORDIC-style range reduction, Taylor/continued-fraction
transcendentals) — no original numerics, gathered from the references cited
throughout `book/index.nim` and cross-checked against GMP/MPFR
(`tests`/`nimble testOracle`) and the float64 `math` oracle
(`nimble bench`'s parity section).

Development used LLM/agent assistance extensively, on the terms described
below. One visible consequence: this repo's git history is short and linear,
with commits landing close together in time — that reflects an LLM/agent
rewrite pass over a pre-existing design (the six non-linalg packages absorbed
from an earlier `UniversalMath` monorepo, see ADR-0005), not the numerics
being designed at that speed from a blank page.

## Layout

```text
src/UniMath.nim              umbrella module
src/UniMath/<pkg>.nim        sub-umbrella per package (arithmetic, fixed, ...)
src/UniMath/<pkg>/*.nim      package modules
src/UniMath/c_api.nim        C ABI
include/UniMath.h            hand-written C header
tests/ tests/c/             Nim + C ABI tests
examples/                    Nim + C demos
py/                          Cython binding + pytest
ADRs/                        0001 sibling deps, 0002 license, 0003 engine&shell,
                             0004 conventions (+ domain ADRs 0005-0009)
.github/workflows/ci.yml     3-OS Nim matrix + C ABI + Python
```

## Build

```bash
nimble install -y
nimble test           # Nim, debug (contracts active)
nimble testRelease    # Nim, release (contracts compiled away)
nimble testAll        # debug + release + C ABI
nimble ctest          # C ABI: static lib + tests/c
nimble cexample       # C demo
nimble example        # Nim demo
nimble pyTest         # Cython + pytest
nimble coverage       # gcov + lcov -> coverage/
nimble book           # nimib book -> book/index.html
nimble docs           # book + API reference -> pages/
nimble bench          # perf + precision-parity benchmarks (not in the gate)
nimble benchmarkNativeFloatBaseline # 3-run direct-libm/facade comparison
nimble benchReadme    # bench, then splice a headline table into this README for this machine
nimble testOracle     # GMP/MPFR oracle tests (needs libmpfr/libgmp; not in the gate)
```

## Native float64 mathematics

`import UniMath` is sufficient for ordinary machine mathematics. UniMath
re-exports Nim's `std/math` API, so consumers use the normal overloaded names
(`sqrt`, `sin`, `cos`, `sinh`, `erf`, `gamma`, `floor`, `frexp`, and the rest)
without importing `std/math` separately. UniMath adds `log1p`, `expm1`, and
`sinCos`; the latter evaluates its argument once and returns `(sin, cos)`.

The operations retain host-libm IEEE-754 behavior. They do not promise
bit-identical last bits across operating systems. C uses explicit
`unimath_f64_*` symbols because C has no overloads, while Python exposes the
same surface through `NativeFloat`.

The deliberate exclusions are `std/math.gcd` and `std/math.lcm`: UniMath
already provides its own exact generic implementations, including `BigInt`,
and exporting both versions would create ambiguous overloads rather than
useful float64 operations.

## Benchmarks

`nimble bench` times the exact-integer/fixed-point core (`bench_arithmetic.nim`)
and the transcendentals across all three backends (`bench_transcendentals.nim`),
plus a precision-parity check of `BigFloat` against the float64 `math` oracle.
`nimble benchReadme` runs the same suite and additionally writes the table
below, tagged to the machine it ran on (`<!-- bench:machine=... -->` — see
`bench/export_readme.nim`). Re-running on the same machine replaces only that
machine's block; a second machine (say a FreeBSD/Zen4 box,
`UNIMATH_BENCH_MACHINE` env var to name it explicitly) adds its own block
alongside, so this table can carry more than one machine's numbers at once
without either overwriting the other.

<!-- bench:insert -->

<!-- bench:machine=freebsd-amd64 -->
**BigInt / Fixed arithmetic**

| op | ns/op | ops/sec |
|---|---|---|
| BigInt add (64-bit) | 29.534 | 33859011. |
| BigInt mul (64-bit) | 29.733 | 33632370. |
| BigInt mul (1024-bit) | 231.563 | 4318484. |
| BigInt div (64/32-bit) | 76.490 | 13073563. |
| isqrt (BigInt, ~120-bit) | 206.162 | 4850563. |
| Fixed Q32.32 add | 0.785 | 1274304166. |
| Fixed Q32.32 mul | 1.377 | 726332457. |
| Fixed Q32.32 div | 3.346 | 298839755. |

**Transcendentals**

| op | ns/op | ops/sec |
|---|---|---|
| BigFloat sin(1) | 4929.291 | 202869. |
| BigFloat exp(1) | 4188.186 | 238767. |
| BigFloat ln(2) | 620.450 | 1611733. |
| BigFloat sqrt(2) | 880.789 | 1135346. |
| BigFloat arctan(1) | 306.114 | 3266756. |
| Fixed sin(1) (router) | 231.363 | 4322203. |
| Fixed atan(1) (router) | 270.896 | 3691449. |
| Fixed sqrt(2) (router) | 126.286 | 7918557. |
| Fixed exp(1) (router) | 692.202 | 1444666. |
| Rational sin(1/2) | 7245.063 | 138025. |
| Rational sqrt(2) | 6427.000 | 155594. |
| Complex[float64] mul | 0.523 | 1912720644. |
| Complex[float64] div | 1.886 | 530085816. |
| Complex[float64] abs | 2.741 | 364885666. |
| Complex[float64] sqrt | 5.439 | 183854960. |
| Complex[float64] exp | 14.145 | 70694720. |
| Complex[float64] ln | 18.367 | 54445520. |
| Complex[BigFloat] mul | 365.006 | 2739681. |
| Complex[BigFloat] abs | 1222.019 | 818318. |
| Complex[BigFloat] sqrt | 2423.948 | 412550. |
| Complex[BigFloat] exp | 14931.119 | 66974. |
| Complex[Rational] mul (exact) | 2757.600 | 362634. |
| Complex[Rational] pow 8 (exact) | 14016.394 | 71345. |

**Precision parity: BigFloat (256-bit) vs float64 `math`**

| op | got (BigFloat, 256-bit) | oracle (float64) | \|err\| |
|---|---|---|---|
| sin(1) | 0.841470984807897 | 0.841470984807897 | 0.00e+00 |
| cos(1) | 0.540302305868140 | 0.540302305868140 | 0.00e+00 |
| exp(1) | 2.718281828459045 | 2.718281828459046 | 4.44e-16 |
| ln(2) | 0.693147180559945 | 0.693147180559945 | 0.00e+00 |
| sqrt(2) | 1.414213562373095 | 1.414213562373095 | 0.00e+00 |
| arctan(1) | 0.785398163397448 | 0.785398163397448 | 0.00e+00 |
| arctan(0.5) | 0.463647609000806 | 0.463647609000806 | 0.00e+00 |
| complex sqrt(-3+4i) re | 1.000000000000000 | 1.000000000000000 | 0.00e+00 |
| complex sqrt(-3+4i) im | 2.000000000000000 | 2.000000000000000 | 0.00e+00 |
| complex ln(-3+4i) re | 1.609437912434100 | 1.609437912434100 | 0.00e+00 |
| complex ln(-3+4i) im | 2.214297435588181 | 2.214297435588181 | 0.00e+00 |
| complex abs(-3+4i) | 5.000000000000000 | 5.000000000000000 | 0.00e+00 |

**UniMath vs GMP/MPFR/MPC** (`nimble benchSpeed`) -- `orc` is the native oracle (`-reuse`: init once and overwrite, the fastest idiomatic usage; `-alloc`: init+free every call, matching UniMath's per-op handle allocation). The ratio column names which one it divides by: the handle surfaces are measured against `orc-alloc`, the by-value `Complex[float64]` against `orc-reuse`, since it allocates nothing. Below 1.0 means UniMath is faster:

```text
UniMath 1.0.0 vs GMP/MPFR/MPC; ns/op, lower is faster
  ratio = UniMath / oracle  (<1.0 => UniMath faster); BigFloat and complex-256 at 256 bits
  ----------------------------------------------------------------------------------------------
  BigInt mul 64-bit      | uni      81.71 | orc-reuse       7.06 | orc-alloc     107.42 | uni/orc-alloc 0.76
  BigInt mul 1024-bit    | uni     252.48 | orc-reuse     117.51 | orc-alloc     215.48 | uni/orc-alloc 1.17
  BigInt div 1024/64     | uni     211.32 | orc-reuse      41.25 | orc-alloc     139.19 | uni/orc-alloc 1.52
  BigInt div 1024/512    | uni     337.10 | orc-reuse     114.54 | orc-alloc     212.54 | uni/orc-alloc 1.59
  BigFloat sin           | uni    4861.26 | orc-reuse    1657.73 | orc-alloc    1739.05 | uni/orc-alloc 2.80
  BigFloat exp           | uni    4073.69 | orc-reuse    1719.85 | orc-alloc    1818.73 | uni/orc-alloc 2.24
  BigFloat ln            | uni     631.55 | orc-reuse    2540.87 | orc-alloc    2656.58 | uni/orc-alloc 0.24
  BigFloat sqrt          | uni     884.32 | orc-reuse     138.42 | orc-alloc     264.26 | uni/orc-alloc 3.35
  -- complex, float64 value ABI vs MPC at 53 bits (ratio vs orc-reuse) --
  Complex mul f64        | uni       4.68 | orc-reuse      78.13 | orc-alloc     275.40 | uni/orc-reuse 0.06
  Complex div f64        | uni       4.96 | orc-reuse    1363.45 | orc-alloc    1545.60 | uni/orc-reuse 0.0036
  Complex sqrt f64       | uni       7.49 | orc-reuse     532.18 | orc-alloc     719.73 | uni/orc-reuse 0.01
  Complex exp f64        | uni      14.16 | orc-reuse    2750.37 | orc-alloc    2941.28 | uni/orc-reuse 0.0051
  Complex ln f64         | uni      23.64 | orc-reuse    2169.04 | orc-alloc    2367.06 | uni/orc-reuse 0.01
  Complex sin f64        | uni      27.59 | orc-reuse    2804.43 | orc-alloc    2992.73 | uni/orc-reuse 0.0098
  -- complex, BigFloat handle ABI vs MPC at 256 bits (ratio vs orc-alloc) --
  Complex mul 256        | uni     424.42 | orc-reuse     142.86 | orc-alloc     351.78 | uni/orc-alloc 1.21
  Complex div 256        | uni    1044.91 | orc-reuse    1878.80 | orc-alloc    2054.83 | uni/orc-alloc 0.51
  Complex sqrt 256       | uni    2832.99 | orc-reuse    1078.95 | orc-alloc    1285.85 | uni/orc-alloc 2.20
  Complex exp 256        | uni   15441.36 | orc-reuse    5155.53 | orc-alloc    5293.39 | uni/orc-alloc 2.92
  Complex ln 256         | uni   55293.55 | orc-reuse   12282.22 | orc-alloc   12454.82 | uni/orc-alloc 4.44
  Complex sin 256        | uni   13134.16 | orc-reuse    5177.07 | orc-alloc    5368.99 | uni/orc-alloc 2.45
  checksum = 4.77938e+24 (keeps every result live)
```


<!-- /bench:machine=freebsd-amd64 -->

<!-- bench:machine=macosx-apple-m4 -->
**BigInt / Fixed arithmetic**

| op | ns/op | ops/sec |
|---|---|---|
| BigInt add (64-bit) | 26.925 | 37140204. |
| BigInt mul (64-bit) | 28.830 | 34686091. |
| BigInt mul (1024-bit) | 317.700 | 3147624. |
| BigInt div (64/32-bit) | 69.880 | 14310246. |
| isqrt (BigInt, ~120-bit) | 8792.660 | 113731. |
| Fixed Q32.32 add | 0.720 | 1388888889. |
| Fixed Q32.32 mul | 74.648 | 13396206. |
| Fixed Q32.32 div | 120.520 | 8297378. |

**Transcendentals**

| op | ns/op | ops/sec |
|---|---|---|
| BigFloat sin(1) | 7228.300 | 138345. |
| BigFloat exp(1) | 9038.450 | 110638. |
| BigFloat ln(2) | 2303.300 | 434160. |
| BigFloat sqrt(2) | 1176.425 | 850033. |
| BigFloat arctan(1) | 58179.650 | 17188. |
| Fixed sin(1) (router) | 165.470 | 6043392. |
| Fixed atan(1) (router) | 267.460 | 3738877. |
| Fixed sqrt(2) (router) | 1180.920 | 846797. |
| Fixed exp(1) (router) | 475.300 | 2103934. |
| Rational sin(1/2) | 12012.450 | 83247. |
| Rational sqrt(2) | 11642.250 | 85894. |
| Complex[float64] mul | 1.577 | 634115409. |
| Complex[float64] div | 2.635 | 379506641. |
| Complex[float64] abs | 2.748 | 363901019. |
| Complex[float64] sqrt | 3.192 | 313283208. |
| Complex[float64] exp | 5.484 | 182348651. |
| Complex[float64] ln | 11.784 | 84860828. |
| Complex[BigFloat] mul | 313.050 | 3194378. |
| Complex[BigFloat] abs | 1494.500 | 669120. |
| Complex[BigFloat] sqrt | 3039.800 | 328969. |
| Complex[BigFloat] exp | 21399.400 | 46730. |
| Complex[Rational] mul (exact) | 4083.500 | 244888. |
| Complex[Rational] pow 8 (exact) | 30692.800 | 32581. |

**Precision parity: BigFloat (256-bit) vs float64 `math`**

| op | got (BigFloat, 256-bit) | oracle (float64) | \|err\| |
|---|---|---|---|
| sin(1) | 0.841470984807897 | 0.841470984807897 | 0.00e+00 |
| cos(1) | 0.540302305868140 | 0.540302305868140 | 0.00e+00 |
| exp(1) | 2.718281828459045 | 2.718281828459045 | 0.00e+00 |
| ln(2) | 0.693147180559945 | 0.693147180559945 | 0.00e+00 |
| sqrt(2) | 1.414213562373095 | 1.414213562373095 | 0.00e+00 |
| arctan(1) | 0.785398163397448 | 0.785398163397448 | 0.00e+00 |
| arctan(0.5) | 0.463647609000806 | 0.463647609000806 | 5.55e-17 |
| complex sqrt(-3+4i) re | 1.000000000000000 | 1.000000000000000 | 0.00e+00 |
| complex sqrt(-3+4i) im | 2.000000000000000 | 2.000000000000000 | 0.00e+00 |
| complex ln(-3+4i) re | 1.609437912434100 | 1.609437912434100 | 0.00e+00 |
| complex ln(-3+4i) im | 2.214297435588181 | 2.214297435588181 | 0.00e+00 |
| complex abs(-3+4i) | 5.000000000000000 | 5.000000000000000 | 0.00e+00 |

**UniMath vs GMP/MPFR/MPC** (`nimble benchSpeed`) -- `orc` is the native oracle (`-reuse`: init once and overwrite, the fastest idiomatic usage; `-alloc`: init+free every call, matching UniMath's per-op handle allocation). The ratio column names which one it divides by: the handle surfaces are measured against `orc-alloc`, the by-value `Complex[float64]` against `orc-reuse`, since it allocates nothing. Below 1.0 means UniMath is faster:

```text
UniMath 1.0.0 vs GMP/MPFR/MPC; ns/op, lower is faster
  ratio = UniMath / oracle  (<1.0 => UniMath faster); BigFloat and complex-256 at 256 bits
  ----------------------------------------------------------------------------------------------
  BigInt mul 64-bit      | uni      91.41 | orc-reuse       3.51 | orc-alloc      15.87 | uni/orc-alloc 5.76
  BigInt mul 1024-bit    | uni     357.05 | orc-reuse      79.65 | orc-alloc      92.41 | uni/orc-alloc 3.86
  BigInt div 1024/64     | uni     262.24 | orc-reuse      35.61 | orc-alloc      46.63 | uni/orc-alloc 5.62
  BigInt div 1024/512    | uni     388.05 | orc-reuse      86.32 | orc-alloc     100.20 | uni/orc-alloc 3.87
  BigFloat sin           | uni    6561.50 | orc-reuse     857.50 | orc-alloc     854.50 | uni/orc-alloc 7.68
  BigFloat exp           | uni    8628.00 | orc-reuse    1169.50 | orc-alloc    1186.50 | uni/orc-alloc 7.27
  BigFloat ln            | uni    2250.85 | orc-reuse    1860.75 | orc-alloc    1873.60 | uni/orc-alloc 1.20
  BigFloat sqrt          | uni    1176.20 | orc-reuse      93.80 | orc-alloc     110.80 | uni/orc-alloc 10.62
  -- complex, float64 value ABI vs MPC at 53 bits (ratio vs orc-reuse) --
  Complex mul f64        | uni       4.26 | orc-reuse      51.81 | orc-alloc      81.53 | uni/orc-reuse 0.08
  Complex div f64        | uni       4.96 | orc-reuse     336.75 | orc-alloc     369.41 | uni/orc-reuse 0.01
  Complex sqrt f64       | uni       5.73 | orc-reuse     152.32 | orc-alloc     184.13 | uni/orc-reuse 0.04
  Complex exp f64        | uni       8.21 | orc-reuse    1256.15 | orc-alloc    1285.10 | uni/orc-reuse 0.01
  Complex ln f64         | uni      15.73 | orc-reuse     735.00 | orc-alloc     763.39 | uni/orc-reuse 0.02
  Complex sin f64        | uni      13.11 | orc-reuse    1197.92 | orc-alloc    1223.23 | uni/orc-reuse 0.01
  -- complex, BigFloat handle ABI vs MPC at 256 bits (ratio vs orc-alloc) --
  Complex mul 256        | uni     394.60 | orc-reuse     106.40 | orc-alloc     143.85 | uni/orc-alloc 2.74
  Complex div 256        | uni    1093.55 | orc-reuse     598.50 | orc-alloc     636.45 | uni/orc-alloc 1.72
  Complex sqrt 256       | uni    3376.00 | orc-reuse     442.40 | orc-alloc     487.60 | uni/orc-alloc 6.92
  Complex exp 256        | uni   21073.50 | orc-reuse    3111.50 | orc-alloc    3169.00 | uni/orc-alloc 6.65
  Complex ln 256         | uni   85099.20 | orc-reuse    7845.20 | orc-alloc    7907.20 | uni/orc-alloc 10.76
  Complex sin 256        | uni   21831.00 | orc-reuse    2702.50 | orc-alloc    2727.00 | uni/orc-alloc 8.01
  checksum = 4.77935e+24 (keeps every result live)
```


<!-- /bench:machine=macosx-apple-m4 -->

## CI

`test`, `cabi` and `python` on ubuntu/macOS/Windows. `consume-cabi` and
`consume-wheel` rebuild against the published artifacts on a machine without Nim,
so what ships is what was tested. `coverage` and `docs` run on ubuntu.

`dco` blocks PRs missing a `Signed-off-by` trailer; `commitizen` blocks PRs whose
commits or title are not [Conventional Commits](https://www.conventionalcommits.org/)
(`CONTRIBUTING.md`).

The same gates run locally with pre-commit: `pip install pre-commit && pre-commit install`
(`CONTRIBUTING.md`).

`docs` publishes to GitHub Pages only from a public repo.

## AI-assisted contributions

Assistance from AI/LLM tools is welcome on the same terms as any other
contribution.

- **Accountability.** The human contributor is the author and remains fully
  responsible for the change. The DCO sign-off (`Signed-off-by`) is the mechanism:
  by signing you certify the content is yours or properly licensed — this covers
  AI-assisted work, provided you can stand behind it.
- **No third-party contamination.** Ensure AI output introduces no code from a
  third party without a compatible license and attribution. If an LLM reproduced
  protected material, do not submit it.
- **Correctness is yours.** The gates (tests, `nimble lint`, conventional commits,
  pre-commit) catch a lot, but you own the result — review and verify what you
  commit.
- **Atomic commits.** Each commit is one logical change. A PR may stack
  several atomic commits (one per element, say) — one monolithic big-bang
  commit is not.
- **Disclosure.** State in the PR whether AI assistance was used (see the PR
  template). It is not a hard requirement — the DCO remains the gate.

## License

Apache-2.0 (`LICENSE`). DCO sign-off on every commit (`CONTRIBUTING.md`).
