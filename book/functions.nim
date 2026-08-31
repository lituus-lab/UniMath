# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[math, strformat]
import lituus_theme
import UniMath

nbInit(theme = useNimibook)
useLituus()
nb.title = "Functions"

nbText: """
## Roots

Integer square root via the digit-by-digit algorithm (no division, safe on
`BigInt`), and a generic Newton-Raphson square root that works over every
`OrderedField` — `float64`, `BigFloat`, `Rational`, `Fixed`. Both raise
`ValueError` on a negative input; the C ABI clamps instead of raising.
"""

nbCode:
  let iroot = isqrt(initBigInt(1_000_000))
  echo "isqrt(1_000_000) = ", toDecimal(iroot)
  let nsF = sqrtNewtonGeneric(2.0)
  echo "sqrtNewtonGeneric(2.0) = ", nsF
  let nsBf = sqrtNewtonGeneric(initBigFloat(2.0, 128))
  echo "sqrtNewtonGeneric(BigFloat 2.0) = ", toFloat64(nsBf)

nbText: """
### References

- Wikipedia: [Integer square root](https://en.wikipedia.org/wiki/Integer_square_root)
- Wikipedia: [Newton's method](https://en.wikipedia.org/wiki/Newton%27s_method)
"""

nbText: """
## Exponential

Taylor series for `exp(x)` and `ln(1+x)`, plus a generic `ln(z)` built on the
area-hyperbolic-tangent series (`z = (1+x)/(1-x)`). All three are generic over
`Field` / `OrderedField`; the logs raise `ValueError` out of domain.

**Limitation, and it is a hard one.** The substitution sends
`u = (z-1)/(z+1)` toward 1 as `z` grows, and the `atanh` series converges like
`u^(2n+1)/(2n+1)`, so the term count needed explodes. Measured, for twelve
correct digits:

| `z` | `u` | terms needed |
|---|---|---|
| 2 | 0.333 | 15 — the default |
| 10 | 0.818 | 200 |
| 10³ | 0.998 | 20 000 |
| 10⁶ | 0.999998 | not reached at 100 000 |

`terms` defaults to 15, and **past `z = 10` the result is wrong rather than
refused**: no exception, no defect, just a plausible number. Raising `terms` is
not a remedy beyond small `z`. Scale the argument into range first — for
`z = m·2^k`, `ln z = ln m + k·ln 2` — or use `ln` from `std/math` on float64.
This function earns its place on exact backends near 1, not as a general
logarithm.

The block below shows the default failing, and shows that 200 terms does not
rescue `z = 10⁶` either.
"""

nbCode:
  echo "expTaylor(1.0) = ", expTaylor(1.0)
  echo "lnGeneric(2.0) = ", lnGeneric(2.0)
  # The default term count is exhausted past z = 10, and says nothing about it.
  for z in [10.0, 1e6]:
    echo "lnGeneric(", z, ") = ", lnGeneric(z),
         "  with 200 terms = ", lnGeneric(z, terms = 200)
  let bfLn = lnGeneric(initBigFloat(2.0, 128))
  echo "lnGeneric(BigFloat 2.0) = ", toFloat64(bfLn)

nbText: """
### References

- Wikipedia: [Taylor series](https://en.wikipedia.org/wiki/Taylor_series)
- Wikipedia: [Inverse hyperbolic functions](https://en.wikipedia.org/wiki/Inverse_hyperbolic_functions) —
  the area-hyperbolic-tangent series `ln(z)` is built on.
"""

nbText: """
## Trigonometry

Four cores, each for a different precision/cost trade-off: a generic Taylor
`sin`/`cos`/`atan` (any `Field`, float64 here), fixed-point CORDIC
(`sin`/`cos`/`atan2`, shifts only — no multiply), a compile-time 256-entry LUT
(`sin`/`cos`, O(1) with no RAM cost), and a Chebyshev minimax `tan`. The
fixed-point cores run on `Fixed[int64, 32]` (Q31.32).
"""

nbCode:
  echo "sinTaylor(0.5) = ", sinTaylor(0.5)
  echo "cosTaylor(0.5) = ", cosTaylor(0.5)
  echo "atanTaylor(0.5) = ", atanTaylor(0.5)
  let cdAngle = toFixed[int64, 32](0.5)
  echo "sinCordic(0.5) = ", toFloat64(sinCordic(cdAngle))
  echo "cosCordic(0.5) = ", toFloat64(cosCordic(cdAngle))
  let trOne = toFixed[int64, 32](1.0)
  echo "atan2Cordic(1,1) = ", toFloat64(atan2Cordic(trOne, trOne))
  echo "sin_lut(0.5) = ", toFloat64(sin_lut(cdAngle))
  echo "tanChebyshev(0.5) = ", toFloat64(tanChebyshev(cdAngle))

nbText: """
### References

- Wikipedia: [Taylor series](https://en.wikipedia.org/wiki/Taylor_series)
- Wikipedia: [CORDIC](https://en.wikipedia.org/wiki/CORDIC)
- Wikipedia: [Lookup table](https://en.wikipedia.org/wiki/Lookup_table)
- Wikipedia: [Minimax approximation algorithm](https://en.wikipedia.org/wiki/Minimax_approximation_algorithm) —
  the Chebyshev minimax `tan`.
"""

nbText: """
## Hyperbolic

Fixed-point CORDIC hyperbolic mode: `sinh`/`cosh`/`tanh`/`exp` via
`atanh(2^-i)` rotations (shifts only). Hyperbolic CORDIC is not periodic and
`exp` grows without bound, so there is no range reduction — the core converges
only for `|z| <= 1.1182` and raises `ValueError` beyond it. That bound is
`sum atanh(2^-i)` with the repeat steps counted twice; the plain sum is 1.0555
(the BigFloat `exp`/`sinh`/`cosh` handle larger arguments via
scaling-and-squaring). Repeat iterations come from the recurrence, not a fixed list: `Q31.32` reaches
`i = 4, 13`, and wider `FracBits` also reach 40, 121, 364. They are repeated for
convergence.
"""

nbCode:
  let hbOne = toFixed[int64, 32](1.0)
  echo "expCordic(1.0) = ", toFloat64(expCordic(hbOne))
  echo "sinhCordic(1.0) = ", toFloat64(sinhCordic(hbOne))
  echo "coshCordic(1.0) = ", toFloat64(coshCordic(hbOne))
  echo "tanhCordic(1.0) = ", toFloat64(tanhCordic(hbOne))

nbText: """
### References

- Wikipedia: [CORDIC](https://en.wikipedia.org/wiki/CORDIC) — hyperbolic
  rotation mode (Walther's extension).
- Wikipedia: [Hyperbolic functions](https://en.wikipedia.org/wiki/Hyperbolic_functions)
"""

nbText: """
## Special

Orthogonal polynomials (Chebyshev T/U, Legendre, Hermite) via three-term
recurrences; `erf` via a term-ratio series on `|x| <= 1` and an `erfc` continued
fraction outside it; Bessel `J0` via its term-ratio series; and
`Gamma` via the Lanczos approximation (g=7, n=9, `< 1e-10` relative error). The
complete beta function is evaluated in the logarithmic domain, and the
regularized incomplete beta uses a bounded continued fraction with a symmetry
transform. Its domain is `0 <= x <= 1` with positive finite, non-subnormal
shape parameters
whose sum remains representable as `float64` and does not exceed the explicit
v1 limit `MaximumRegularizedBetaShapeSum` (200,000), except for the analytic
`a == 1` or `b == 1` cases.
series advance by term-ratio recurrence, so the denominator factorial is never
formed as an integer. `Gamma` has no zeros — only poles at the non-positive
integers, where the Nim core raises `ValueError` (the C ABI returns `NaN`).
"""

nbCode:
  import UniMath
  import std/math
  import UniMath/special/gamma
  import UniMath/special/error_functions
  proc spSqrt(v: float64): float64 {.noSideEffect.} = math.sqrt(v)
  proc spExp(v: float64): float64 {.noSideEffect.} = math.exp(v)
  echo "chebyshevT(2, 0.5) = ", chebyshevT(2, 0.5)
  echo "legendreP(2, 0.5) = ", legendreP(2, 0.5)
  echo "hermiteH(3, 0.5) = ", hermiteH(3, 0.5)
  echo "erf(0.5) = ", erfTaylor(0.5, 15, PI, spSqrt)
  echo "erf(3.0) = ", error_functions.erf(3.0, 32, PI, spSqrt, spExp)
  echo "Gamma(5) = ", gammaLanczosFloat(5.0)
  echo "Beta(2, 3) = ", beta(2.0, 3.0)
  echo "I_0.2(2, 5) = ", regularizedIncompleteBeta(0.2, 2.0, 5.0)
  echo "factorial(5) = ", gamma.factorial[float64](5)
  echo "J0(0.5) = ", besselJ0(0.5, 15)

nbText: """
### References

- Wikipedia: [Chebyshev polynomials](https://en.wikipedia.org/wiki/Chebyshev_polynomials)
- Wikipedia: [Legendre polynomials](https://en.wikipedia.org/wiki/Legendre_polynomials)
- Wikipedia: [Hermite polynomials](https://en.wikipedia.org/wiki/Hermite_polynomials)
- Wikipedia: [Error function](https://en.wikipedia.org/wiki/Error_function)
- Wikipedia: [Lanczos approximation](https://en.wikipedia.org/wiki/Lanczos_approximation)
- Wikipedia: [Bessel function](https://en.wikipedia.org/wiki/Bessel_function)
"""

nbText: """
## Constants

`pi` and `e` at the precision of the backend: `BigFloat` computes them
genuinely arbitrary-precision (Machin's formula `16*atan(1/5) - 4*atan(1/239)`
for `pi`, the `exp(1)` series for `e`) — a float64 literal would cap the
constant at ~53 correct bits. `Fixed` grids of `<= 52` fractional bits take the
float64 literal, exact at the grid resolution.
"""

nbCode:
  echo "piBigFloat(256) = ", toFloat64(piBigFloat(256))
  echo "eBigFloat(256) = ", toFloat64(eBigFloat(256))
  echo "piFixed Q32 = ", toFloat64(piFixed[int64, 32]())
  echo "eFixed Q32 = ", toFloat64(eFixed[int64, 32]())

nbText: """
### References

- Wikipedia: [Machin-like formula](https://en.wikipedia.org/wiki/Machin-like_formula)
- Wikipedia: [E (mathematical constant)](https://en.wikipedia.org/wiki/E_(mathematical_constant))
"""

nbText: """
## Reduction

Argument range reduction for `BigFloat` transcendentals. The generic Taylor
primitives converge only for small arguments, so `sin`/`cos` reduce `x` to
`[-pi, pi]` by `r = x - round(x/2pi)·2pi` (stage 1), then fold `|r|` into
`[0, pi/4]` via the octant identities; `exp` scales by `2^k` and squares back.
This module holds the shared infrastructure: power-of-two scaling, the cached
`pi`, `floor`/`round` over `BigFloat`, and `reduceModTwoPi`.
"""

nbCode:
  import UniMath
  import std/math
  echo "scaleByPow2(1.0, 2) = ", toFloat64(scaleByPow2(initBigFloat(1.0), 2))
  echo "floorBigFloat(2.7) = ", toFloat64(floorBigFloat(initBigFloat(2.7)))
  echo "roundBigFloat(2.5) = ", toFloat64(roundBigFloat(initBigFloat(2.5)))
  echo "reduceModTwoPi(2pi+0.5) = ", toFloat64(reduceModTwoPi(initBigFloat(2.0 *
      PI + 0.5)))

nbText: """
### References

- Wikipedia: [Trigonometric functions](https://en.wikipedia.org/wiki/Trigonometric_functions) —
  periodicity is why the Taylor cores need reduction before evaluating.
"""

nbText: """
"""

nbSave
