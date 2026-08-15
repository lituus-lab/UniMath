# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import nimib

nbInit
nb.title = "UniMath"

nbText: """
# UniMath

A multi-precision numeric library: arbitrary-precision integers, fixed-point,
big floats, rationals, and intervals, with the transcendental and
special-function algorithms over them. Exposed across three surfaces —
**Nim**, a **C ABI**, and a **Python** binding.

This page is a nimib book: every Nim block below is compiled and run when the
book is built, and the output shown is what the code actually produced. A change
that breaks the API breaks the docs build, so the two cannot drift apart.

## Who this book is for

Nim developers who need arithmetic beyond what `float64`/`int64` can represent
exactly or without overflow: exact fractions, correctly-rounded arbitrary
precision, or a guaranteed enclosure of a rounding error. No numerical-analysis
background is assumed — each section states what problem its type or algorithm
solves before showing it.

## How to read this book

Read top to bottom: each section only uses types and functions introduced
above it.

1. **Types** — BigInt, Fixed, BigFloat, Rational, Interval: the five ways
   this library represents a number.
2. **EFT** — the error-free-transform primitive the analysis layer below
   is built on.
3. **Algorithms** — Roots, Exponential, Trigonometry, Hyperbolic, Special:
   one section per family of transcendental/special-function algorithm,
   each generic over the types above.
4. **Dispatch and integration** — Constants, Reduction, float_math,
   rational_math, conversions, math_router: how the algorithms above are
   assembled into the actual per-backend `sin`/`exp`/`sqrt`/... API and how
   values move between backends.

A reader only interested in one type or algorithm can jump straight to its
section: every code example is self-contained (imports and all), so nothing
earlier is required to run it.

## Notation

- `Fixed[T, FracBits]`: Q-format fixed-point — an integer of type `T` holding
  the real value scaled by `2^FracBits`. `Fixed[int64, 32]` is written
  `Q32.32` below (32 integer bits, 32 fractional bits).
- `BigFloat`'s `precision` argument (e.g. `initBigFloat(2.0, 128)`) is the
  mantissa width in bits, not decimal digits; the default is 256.
- `rmNearest`/`rmUp`/`rmDown`: rounding modes — round to nearest, or round so
  the result is guaranteed `>=`/`<=` the exact value (used to build
  `Interval` enclosures).
- The C ABI never raises: out-of-range input clamps (`Fixed`) or returns a
  sentinel (`NaN` interval, null handle) instead of an exception crossing the
  language boundary. Only the Nim and Python surfaces raise.

## The Nim surface

The umbrella module re-exports every public submodule.
"""

nbCode:
  import UniMath

  echo "version ", UniMathVersion

nbText: """
## BigInt

Arbitrary-precision sign-magnitude integers. Construction from literals,
arithmetic, and the two string forms — `$` (hexadecimal, base 16 maps directly
to limbs) and `toDecimal` (base 10, the human / oracle form).
"""

nbCode:
  let a = initBigInt(-123456789)
  let b = initBigInt(1_000_000_000_000) * initBigInt(1_000_000_000_000) # 1e24
  echo "a = ", a, " (decimal: ", toDecimal(a), ")"
  echo "b = ", toDecimal(b)
  echo "a * b = ", toDecimal(a * b)
  echo "b div 7 = ", toDecimal(b div initBigInt(7))
  echo "b mod 7 = ", toDecimal(b mod initBigInt(7))

nbText: """
### References

- Wikipedia: [Arbitrary-precision arithmetic](https://en.wikipedia.org/wiki/Arbitrary-precision_arithmetic)
"""

nbText: """
## Fixed

Q-format fixed-point: a `Fixed[T, FracBits]` is an integer scaled by
`2^FracBits`. `+`/`-` are integer ops on the data; `*` and `/` use an exact
`BigInt` intermediate so the double-width product and the pre-scaled dividend
never lose bits, then range-check back to the storage type.
"""

nbCode:
  let x = toFixed[int64, 32](3)
  let y = toFixed[int64, 32](2)
  echo "x + y = ", toFloat64(x + y)
  echo "x * y = ", toFloat64(x * y)
  echo "x / y = ", toFloat64(x / y)
  echo "floor(3.75) = ", toFloat64(floor(toFixed[int64, 32](3.75)))

nbText: """
### References

- Wikipedia: [Fixed-point arithmetic](https://en.wikipedia.org/wiki/Fixed-point_arithmetic)
- Wikipedia: [Q (number format)](https://en.wikipedia.org/wiki/Q_(number_format))
"""

nbText: """
## BigFloat

Arbitrary-precision floating point: `mantissa * 2^exponent` with a sign, the
mantissa normalized to `precision` bits (top bit set) or zero. Operators
round to nearest; directed rounding (`rmUp`/`rmDown`) bounds the exact result
from above/below. `toFloat64` is correctly rounded with subnormal bit-packing.
"""

nbCode:
  let fa = initBigFloat(10.0, 64)
  let fb = initBigFloat(3.0, 64)
  echo "fa + fb = ", toFloat64(fa + fb)
  echo "fa * fb = ", toFloat64(fa * fb)
  echo "fa / fb = ", toFloat64(fa / fb)
  let one = initBigFloat(1.0)
  let three = initBigFloat(3.0)
  echo "1/3 rounded up >= nearest: ", cmp(divRounded(one, three, 256, rmUp),
                                         divRounded(one, three, 256,
                                             rmNearest)) >= 0

nbText: """
### References

- Wikipedia: [Floating-point arithmetic](https://en.wikipedia.org/wiki/Floating-point_arithmetic)
- Wikipedia: [IEEE 754](https://en.wikipedia.org/wiki/IEEE_754) — the rounding-mode
  contract `rmNearest`/`rmUp`/`rmDown` follow.
"""

nbText: """
## Rational

Exact fractions `Rational[T]` over any integer-like `T` (built-in integers and
`BigInt`). The denominator is always positive and the fraction irreducible, so
equality is a direct field compare and arithmetic cross-simplifies before
multiplying. `Rational[BigInt]` is unbounded exact arithmetic.
"""

nbCode:
  let ra = initRational(initBigInt(1), initBigInt(2))
  let rb = initRational(initBigInt(1), initBigInt(3))
  echo "1/2 + 1/3 = ", toFloat64(ra + rb)
  echo "1/2 * 1/3 = ", toFloat64(ra * rb)
  echo "1/2 / 1/3 = ", toFloat64(ra / rb)
  let red = initRational(initBigInt(4), initBigInt(8))
  echo "4/8 reduces: num=", toDecimal(red.num), " den=", toDecimal(red.den)

nbText: """
### References

- Wikipedia: [Rational number](https://en.wikipedia.org/wiki/Rational_number)
"""

nbText: """
## Interval

Directed-rounding intervals `Interval[T] = object` (lower, upper). Each binary
op widens with `nextDown`/`nextUp` so the result encloses the exact value; `/`
raises `DivByZeroDefect` when the divisor straddles zero. Trigonometric ranges
scan maxima and minima independently. Transcendentals widen by two ulps for the
host libm, or one ulp under `-d:correctlyRoundedLibm` when linked to a correctly
rounded backend.
"""

nbCode:
  import UniMath
  import std/math
  let ia = initInterval(1.0, 2.0)
  let ib = initInterval(3.0, 4.0)
  let isum = ia + ib
  let iprod = ia * ib
  echo "ia + ib = [", isum.lower, ", ", isum.upper, "]"
  echo "ia * ib = [", iprod.lower, ", ", iprod.upper, "]"
  let isq = sqrt(initInterval(4.0, 9.0))
  echo "sqrt([4, 9]) = [", isq.lower, ", ", isq.upper, "]"
  let isin = sin(initInterval(0.0, PI))
  echo "sin([0, pi]) = [", isin.lower, ", ", isin.upper, "]"

nbText: """
### References

- Wikipedia: [Interval arithmetic](https://en.wikipedia.org/wiki/Interval_arithmetic)
"""

nbText: """
## EFT

Error-free transforms, re-exported from the `UniAccurate` engine: `twoSum` and
`twoProduct` split a float op into its rounded result and the exact residual,
and the Shewchuk expansion arithmetic accumulates those residuals into a
non-overlapping sequence that represents the real value exactly. UniMath adds no
EFT code of its own — the engine owns it, including its `ua_*` C ABI.
"""

nbCode:
  let (s, e) = twoSum(1.0, 2.0)
  echo "twoSum(1, 2) = (", s, ", ", e, ")"
  let ex = growExpansion([1.0, 2.0], 3.0)
  echo "estimate([1,2] grown by 3) = ", estimate(ex)

nbText: """
### References

- Wikipedia: [2Sum](https://en.wikipedia.org/wiki/2Sum) — the `twoSum`
  error-free transform (Møller–Knuth).
- Wikipedia: [Kahan summation algorithm](https://en.wikipedia.org/wiki/Kahan_summation_algorithm) —
  the same compensated-summation family.
- Shewchuk, J.R. "Adaptive Precision Floating-Point Arithmetic and Fast Robust
  Geometric Predicates," *Discrete & Computational Geometry* 18, 305–363
  (1997) — the expansion arithmetic (`growExpansion`,
  `fastExpansionSumZeroElim`, `scaleExpansionZeroElim`).
"""

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
area-hyperbolic-tangent series (`z = (1+x)/(1-x)`), which converges for every
positive `z`. All three are generic over `Field` / `OrderedField`; the logs
raise `ValueError` out of domain.
"""

nbCode:
  echo "expTaylor(1.0) = ", expTaylor(1.0)
  echo "lnGeneric(2.0) = ", lnGeneric(2.0)
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
fixed-point cores run on `Fixed[int64, 32]` (Q32.32).
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
only for `|z| <= sum atanh(2^-i) ~ 1.1182` and raises `ValueError` beyond it
(the BigFloat `exp`/`sinh`/`cosh` handle larger arguments via
scaling-and-squaring). Iterations at `i = 4, 13, 40, 121` are repeated for
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
## float_math

Range-reduced `BigFloat` transcendentals over the generic cores. The Taylor
primitives converge only for small arguments, so `sin`/`cos` fold the argument
into `[-pi/4, pi/4]` via the octant identities; `exp` scales by `2^k` and
squares back; `ln` brings the mantissa into `[sqrt(1/2), sqrt(2)]` so the atanh
series converges fast. With no explicit `terms` argument, each function derives
its budget from the reduced argument and the precision carried by the value;
passing a positive budget still overrides that choice. The identities below
hold to the working precision.
"""

nbCode:
  echo "sin(1.0) = ", toFloat64(sin(initBigFloat(1.0)))
  echo "cos(1.0) = ", toFloat64(cos(initBigFloat(1.0)))
  let fmS = sin(initBigFloat(0.7))
  let fmC = cos(initBigFloat(0.7))
  echo "sin^2 + cos^2 = ", toFloat64(fmS * fmS + fmC * fmC)
  echo "exp(1.0) = ", toFloat64(exp(initBigFloat(1.0)))
  echo "ln(2.0) = ", toFloat64(ln(initBigFloat(2.0)))
  echo "ln(exp(1.0)) = ", toFloat64(ln(exp(initBigFloat(1.0))))
  echo "sqrt(2.0) = ", toFloat64(sqrt(initBigFloat(2.0)))
  echo "arctan(1.0) = ", toFloat64(arctan(initBigFloat(1.0)))
  echo "arctan2(1,1) = ", toFloat64(arctan2(initBigFloat(1.0), initBigFloat(
      1.0)))
  echo "pow(2.0, 0.5) = ", toFloat64(pow(initBigFloat(2.0), initBigFloat(0.5)))
  echo "pow_int(2.0, 10) = ", toFloat64(pow(initBigFloat(2.0), 10))

nbText: """
## rational_math

Transcendentals over `Rational[T]` dispatched on the generic Taylor / atanh /
Newton cores. Each term is an exact rational; the truncation at `terms` makes
the value approximate (not the arithmetic). The `int64` backend bounds the
denominators (keep `terms` small — squaring or compound identities overflow
past `~1e9` denominators); `Rational[BigInt]` is unbounded. `pi` enters as the
`355/113` convergent (~2.7e-7), avoiding the Machin-formula overflow.
"""

nbCode:
  let rmX = initRational(initBigInt(1), initBigInt(4))
  echo "sin(1/4) = ", toFloat64(sin(rmX))
  echo "cos(1/4) = ", toFloat64(cos(rmX))
  echo "exp(1/4) = ", toFloat64(exp(rmX, 10))
  echo "ln(2) = ", toFloat64(ln(initRational(initBigInt(2), initBigInt(1)), 10))
  echo "sqrt(2) = ", toFloat64(sqrt(initRational(initBigInt(2), initBigInt(1))))
  echo "atan(1/3) = ", toFloat64(atan(initRational(initBigInt(1), initBigInt(3))))
  echo "atan2(1,3) = ", toFloat64(atan2(initRational(initBigInt(1), initBigInt(
      1)), initRational(initBigInt(3), initBigInt(1))))
  echo "pow(2,1/2) = ", toFloat64(pow(initRational(initBigInt(2), initBigInt(
      1)), initRational(initBigInt(1), initBigInt(2)), 10))

nbText: """
### References

- Wikipedia: [Milü](https://en.wikipedia.org/wiki/Mil%C3%BC) — the `355/113`
  convergent used for `pi`.
"""

nbText: """
## math_router

Auto-dispatch `Fixed[int64, 32]` (Q32.32) transcendentals. Each call selects a
core by algorithm: CORDIC for `sin`/`cos`/`atan2`, Chebyshev for `tan`,
hyperbolic-CORDIC scaling-and-squaring for `exp`, the area-hyperbolic-tangent
series after power-of-two reduction for `ln`, exponential identities for
`sinh`/`cosh`/`tanh`, and Newton for `sqrt`. The router is generic over
`Fixed[T, FracBits]`; here it runs at Q32.32. Exponential scaling and squaring
removes the raw hyperbolic CORDIC convergence limit; `tanh` covers the full
fixed-point domain and saturates only when the exact result rounds to `+/-1`.
"""

nbCode:
  import UniMath
  import UniMath/math_router
  let mrOne = toFixed[int64, 32](1.0)
  let mrHalf = toFixed[int64, 32](0.5)
  echo "sin(0.5) = ", toFloat64(math_router.sin(mrHalf))
  echo "cos(0.5) = ", toFloat64(math_router.cos(mrHalf))
  echo "tan(0.5) = ", toFloat64(math_router.tan(mrHalf))
  echo "exp(1.0) = ", toFloat64(math_router.exp(mrOne))
  echo "ln(1.5) = ", toFloat64(math_router.ln(toFixed[int64, 32](1.5)))
  echo "sqrt(2.0) = ", toFloat64(math_router.sqrt(toFixed[int64, 32](2.0)))
  echo "atan(1.0) = ", toFloat64(math_router.atan(mrOne))
  echo "atan2(1,1) = ", toFloat64(math_router.atan2(mrOne, mrOne))
  echo "sinh(1.0) = ", toFloat64(math_router.sinh(mrOne))
  echo "cosh(1.0) = ", toFloat64(math_router.cosh(mrOne))
  echo "tanh(1.0) = ", toFloat64(math_router.tanh(mrOne))
  echo "pow(1.5, 1) = ", toFloat64(math_router.pow(toFixed[int64, 32](1.5), mrOne))

nbText: """
## conversions

The cross-type matrix across the backends. Each proc documents its exactness
contract: `toRationalExact`/`toRationalBig` (float64 -> exact Rational, the
latter unbounded), `toBigFloat` (Rational -> rounded BigFloat with a selectable
rounding mode, or Fixed -> exact BigFloat), `toBigInt` (truncation toward zero),
`toFixed` (Rational/BigFloat -> truncated Fixed, raises on overflow), and
`toInterval` (a widened enclosure of the exact value).
"""

nbCode:
  import UniMath
  import UniMath/conversions
  let cvF = toFixed[int64, 32](2.5)
  echo "Fixed 2.5 -> Rational = ", toFloat64(conversions.toRational(cvF))
  echo "Rational 1/3 -> BigFloat = ", toFloat64(conversions.toBigFloat(
      initRational(1'i64, 3'i64), 64))
  echo "BigFloat 42.75 -> BigInt = ", toDecimal(conversions.toBigInt(
      initBigFloat(42.75, 64)))
  echo "Rational 7/2 -> BigInt = ", toDecimal(conversions.toBigInt(
      initRational(7'i64, 2'i64)))
  echo "BigFloat 2.5 -> Fixed = ", toFloat64(conversions.toFixed[int64, 32](
      initBigFloat(2.5, 128)))
  let cvI = conversions.toInterval(initBigFloat(2.5, 128))
  echo "BigFloat 2.5 -> Interval = [", cvI.lower, ", ", cvI.upper, "]"
  echo "float64 0.1 -> Rational = ", toFloat64(conversions.toRationalExact(0.1))

nbSave
