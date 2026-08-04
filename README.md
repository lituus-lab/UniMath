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

```
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
nimble benchReadme    # bench, then splice a headline table into this README for this machine
nimble testOracle     # GMP/MPFR oracle tests (needs libmpfr/libgmp; not in the gate)
```

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

<!-- bench:machine=macosx-apple-m4 -->
**BigInt / Fixed arithmetic**

| op | ns/op | ops/sec |
|---|---|---|
| BigInt add (64-bit) | 27.950 | 35778175. |
| BigInt mul (64-bit) | 29.150 | 34305317. |
| BigInt mul (1024-bit) | 321.950 | 3106072. |
| BigInt div (64/32-bit) | 71.700 | 13947001. |
| isqrt (BigInt, ~120-bit) | 8860.080 | 112866. |
| Fixed Q32.32 add | 0.769 | 1300390117. |
| Fixed Q32.32 mul | 75.532 | 13239422. |
| Fixed Q32.32 div | 116.905 | 8553954. |

**Transcendentals**

| op | ns/op | ops/sec |
|---|---|---|
| BigFloat sin(1) | 6734.850 | 148481. |
| BigFloat exp(1) | 8629.500 | 115882. |
| BigFloat ln(2) | 2247.500 | 444939. |
| BigFloat sqrt(2) | 1483.600 | 674036. |
| BigFloat arctan(1) | 60371.150 | 16564. |
| Fixed sin(1) (router) | 170.570 | 5862696. |
| Fixed atan(1) (router) | 283.200 | 3531073. |
| Fixed sqrt(2) (router) | 1250.680 | 799565. |
| Fixed exp(1) (router) | 465.060 | 2150260. |
| Rational sin(1/2) | 12043.500 | 83032. |
| Rational sqrt(2) | 12198.600 | 81977. |

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
