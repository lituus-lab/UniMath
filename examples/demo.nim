# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## End-to-end demo exercising every backend through the umbrella: BigInt,
## Fixed, BigFloat, Rational, the BigFloat / Rational / Fixed transcendentals,
## and the cross-type conversions. Built by `nimble example`.
import std/strutils
import UniMath

echo "UniMath " & UniMathVersion

# ---- BigInt: arbitrary-precision integer arithmetic ----
var acc = initBigInt(1)
for i in 1 .. 20:
  acc = acc * initBigInt(i)
echo "20! = ", toDecimal(acc)
echo "(2^64)^2 = ", toDecimal((initBigInt(1) shl 64) * (initBigInt(1) shl 64))

# ---- Fixed: Q32.32 fixed-point arithmetic (exact BigInt intermediate) ----
let x = toFixed[int64, 32](3)
let y = toFixed[int64, 32](2)
echo "3 + 2 = ", toFloat64(x + y)
echo "3 * 2 = ", toFloat64(x * y)
echo "3 / 2 = ", toFloat64(x / y)

# ---- BigFloat: range-reduced transcendentals (256-bit) ----
echo "sin(1)   = ", toFloat64(sin(initBigFloat(1.0), 30))
echo "exp(1)   = ", toFloat64(exp(initBigFloat(1.0), 30))
echo "ln(2)    = ", toFloat64(ln(initBigFloat(2.0), 30))
echo "sqrt(2)  = ", toFloat64(sqrt(initBigFloat(2.0)))

# ---- Rational: exact fractions over BigInt ----
let r = initRational(initBigInt(1), initBigInt(3))
echo "1/3 + 1/3 + 1/3 = ", toFloat64(r + r + r)

# ---- math_router: Fixed auto-dispatch transcendentals (Q32.32) ----
import UniMath/math_router
echo "fixed sqrt(2) = ", toFloat64(math_router.sqrt(toFixed[int64, 32](2.0)))
echo "fixed atan(1) = ", toFloat64(math_router.atan(toFixed[int64, 32](1.0)))

# ---- conversions: cross-type round-trips ----
import UniMath/conversions
echo "0.1 -> Rational -> float64 = ", toFloat64(conversions.toRationalExact(0.1))
echo "Fixed 2.5 -> Rational = ", toFloat64(conversions.toRational(
    toFixed[int64, 32](2.5)))

