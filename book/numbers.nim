# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[math, strformat]
import lituus_theme
import UniMath

nbInit(theme = useNimibook)
useLituus()
nb.title = "Exact numbers"

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
"""

nbSave
