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
                             0004 conventions (+ domain ADRs 0005-0008)
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
| BigInt add (64-bit) | 37.722 | 26509596. |
| BigInt mul (64-bit) | 33.380 | 29958418. |
| BigInt mul (1024-bit) | 612.207 | 1633434. |
| BigInt div (64/32-bit) | 82.826 | 12073573. |
| isqrt (BigInt, ~120-bit) | 9567.438 | 104521. |
| Fixed Q32.32 add | 0.813 | 1230004736. |
| Fixed Q32.32 mul | 83.183 | 12021722. |
| Fixed Q32.32 div | 128.563 | 7778294. |

**Transcendentals**

| op | ns/op | ops/sec |
|---|---|---|
| BigFloat sin(1) | 6645.985 | 150467. |
| BigFloat exp(1) | 6651.714 | 150337. |
| BigFloat ln(2) | 704.486 | 1419474. |
| BigFloat sqrt(2) | 1063.126 | 940622. |
| BigFloat arctan(1) | 389.143 | 2569748. |
| Fixed sin(1) (router) | 233.577 | 4281248. |
| Fixed atan(1) (router) | 347.185 | 2880311. |
| Fixed sqrt(2) (router) | 1255.499 | 796496. |
| Fixed exp(1) (router) | 688.569 | 1452288. |
| Rational sin(1/2) | 13551.526 | 73792. |
| Rational sqrt(2) | 12664.432 | 78961. |

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

**UniMath vs GMP/MPFR** (`nimble benchSpeed`) -- `orc` is the GMP/MPFR oracle (`-reuse`: init once and overwrite, the fastest idiomatic oracle usage; `-alloc`: init+free every call, matching UniMath's per-op handle allocation). `uni/orc-alloc` is the ratio; below 1.0 would mean UniMath is faster -- it is not, here:

```text
UniMath 1.0.0 vs GMP/MPFR (256-bit BigFloat); ns/op, lower is faster
  ratio = UniMath / oracle-alloc  (<1.0 => UniMath faster)
  ----------------------------------------------------------------------------------------------
  BigInt mul 64-bit      | uni      86.87 | orc-reuse       7.36 | orc-alloc     109.59 | uni/orc-alloc 0.79
  BigInt mul 1024-bit    | uni     580.97 | orc-reuse     118.99 | orc-alloc     220.91 | uni/orc-alloc 2.63
  BigInt div 1024/64     | uni     209.50 | orc-reuse      42.66 | orc-alloc     143.61 | uni/orc-alloc 1.46
  BigInt div 1024/512    | uni     419.85 | orc-reuse     118.70 | orc-alloc     221.52 | uni/orc-alloc 1.90
  BigFloat sin           | uni    6772.22 | orc-reuse    1731.81 | orc-alloc    1791.65 | uni/orc-alloc 3.78
  BigFloat exp           | uni    6797.13 | orc-reuse    1826.01 | orc-alloc    1889.94 | uni/orc-alloc 3.60
  BigFloat ln            | uni     772.45 | orc-reuse    2596.84 | orc-alloc    2713.01 | uni/orc-alloc 0.28
  BigFloat sqrt          | uni    1090.77 | orc-reuse     122.87 | orc-alloc     240.20 | uni/orc-alloc 4.54
  checksum = 4.77935e+24 (keeps every result live)
```


<!-- /bench:machine=freebsd-amd64 -->

<!-- bench:machine=macosx-apple-m4 -->
**BigInt / Fixed arithmetic**

| op | ns/op | ops/sec |
|---|---|---|
| BigInt add (64-bit) | 27.625 | 36199095. |
| BigInt mul (64-bit) | 29.200 | 34246575. |
| BigInt mul (1024-bit) | 480.700 | 2080300. |
| BigInt div (64/32-bit) | 76.120 | 13137152. |
| isqrt (BigInt, ~120-bit) | 9451.820 | 105800. |
| Fixed Q32.32 add | 0.758 | 1319261214. |
| Fixed Q32.32 mul | 81.946 | 12203158. |
| Fixed Q32.32 div | 125.000 | 8000000. |

**Transcendentals**

| op | ns/op | ops/sec |
|---|---|---|
| BigFloat sin(1) | 8398.250 | 119072. |
| BigFloat exp(1) | 7153.450 | 139793. |
| BigFloat ln(2) | 753.800 | 1326612. |
| BigFloat sqrt(2) | 1020.225 | 980176. |
| BigFloat arctan(1) | 430.200 | 2324500. |
| Fixed sin(1) (router) | 177.020 | 5649079. |
| Fixed atan(1) (router) | 322.420 | 3101545. |
| Fixed sqrt(2) (router) | 1318.800 | 758265. |
| Fixed exp(1) (router) | 521.740 | 1916663. |
| Rational sin(1/2) | 12818.500 | 78012. |
| Rational sqrt(2) | 12594.600 | 79399. |

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

**UniMath vs GMP/MPFR** (`nimble benchSpeed`) -- `orc` is the GMP/MPFR oracle (`-reuse`: init once and overwrite, the fastest idiomatic oracle usage; `-alloc`: init+free every call, matching UniMath's per-op handle allocation). `uni/orc-alloc` is the ratio; below 1.0 would mean UniMath is faster -- it is not, here:

```text
UniMath 1.0.0 vs GMP/MPFR (256-bit BigFloat); ns/op, lower is faster
  ratio = UniMath / oracle-alloc  (<1.0 => UniMath faster)
  ----------------------------------------------------------------------------------------------
  BigInt mul 64-bit      | uni      80.26 | orc-reuse       4.07 | orc-alloc      17.59 | uni/orc-alloc 4.56
  BigInt mul 1024-bit    | uni     469.71 | orc-reuse     112.91 | orc-alloc      98.46 | uni/orc-alloc 4.77
  BigInt div 1024/64     | uni     282.27 | orc-reuse      39.24 | orc-alloc      48.24 | uni/orc-alloc 5.85
  BigInt div 1024/512    | uni     412.60 | orc-reuse      93.75 | orc-alloc     106.68 | uni/orc-alloc 3.87
  BigFloat sin           | uni    6508.00 | orc-reuse    1243.50 | orc-alloc     855.00 | uni/orc-alloc 7.61
  BigFloat exp           | uni    6440.00 | orc-reuse    1505.50 | orc-alloc    1325.00 | uni/orc-alloc 4.86
  BigFloat ln            | uni     781.40 | orc-reuse    1979.25 | orc-alloc    2015.40 | uni/orc-alloc 0.39
  BigFloat sqrt          | uni    1007.60 | orc-reuse     101.00 | orc-alloc     122.20 | uni/orc-alloc 8.25
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
