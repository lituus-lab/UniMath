# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[math, strformat]
import lituus_theme
import UniMath

nbInit(theme = useNimibook)
useLituus()
nb.title = "Dispatch"

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

Auto-dispatch `Fixed[int64, 32]` (Q31.32) transcendentals. Each call selects a
core by algorithm: CORDIC for `sin`/`cos`/`atan2`, Chebyshev for `tan`,
hyperbolic-CORDIC scaling-and-squaring for `exp`, the area-hyperbolic-tangent
series after power-of-two reduction for `ln`, exponential identities for
`sinh`/`cosh`/`tanh`, and Newton for `sqrt`. The router is generic over
`Fixed[T, FracBits]`; here it runs at Q31.32. Exponential scaling and squaring
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

nbText: """
"""

nbSave
