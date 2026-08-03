# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Roots tests: integer square root (digit-by-digit) over built-in integers
## and `BigInt`, and the generic Newton-Raphson square root over every
## `OrderedField` (float64, `BigFloat`, `Rational`, `Fixed`).
import std/[unittest, math]
import UniMath

suite "isqrt — digit-by-digit":
  test "built-in integers":
    check isqrt(0'i64) == 0
    check isqrt(1'i64) == 1
    check isqrt(3'i64) == 1
    check isqrt(4'i64) == 2
    check isqrt(8'i64) == 2
    check isqrt(15'i64) == 3
    check isqrt(16'i64) == 4
    check isqrt(1_000_000'i64) == 1000
  test "BigInt":
    check isqrt(initBigInt(0)) == initBigInt(0)
    check isqrt(initBigInt(1)) == initBigInt(1)
    check isqrt(initBigInt(15)) == initBigInt(3)
    check isqrt(initBigInt(16)) == initBigInt(4)
    check isqrt(initBigInt(1_000_000)) == initBigInt(1000)
    # r*r <= n < (r+1)*(r+1) for a non-square.
    let n = initBigInt(1_000_000_000)
    let r = isqrt(n)
    check r * r <= n and n < (r + initBigInt(1)) * (r + initBigInt(1))
  test "negative raises ValueError":
    expect ValueError:
      discard isqrt(-1'i64)
    expect ValueError:
      discard isqrt(initBigInt(-1))

suite "sqrtNewtonGeneric — across OrderedFields":
  test "float64":
    check abs(sqrtNewtonGeneric(4.0) - 2.0) < 1e-12
    check abs(sqrtNewtonGeneric(2.0) - sqrt(2.0)) < 1e-12
    check sqrtNewtonGeneric(0.0) == 0.0
  test "BigFloat":
    let p = 128
    check abs(toFloat64(sqrtNewtonGeneric(initBigFloat(4.0, p))) - 2.0) < 1e-20
    check abs(toFloat64(sqrtNewtonGeneric(initBigFloat(2.0, p))) - sqrt(2.0)) < 1e-20
    check toFloat64(sqrtNewtonGeneric(initBigFloat(0.0, p))) == 0.0
  test "Rational":
    # Exact rational Newton never hits sqrt(4)=2 in finite steps — the
    # iterates stay exact with growing denominators — so cap the iterations
    # (5 converges to ~3e-15) and check the float approximation, not num/den.
    let r = sqrtNewtonGeneric(fromInt(Rational[int64], 4), 5)
    check abs(toFloat64(r) - 2.0) < 1e-9
    let z = sqrtNewtonGeneric(fromInt(Rational[int64], 0))
    check z.isZero
  test "Fixed":
    let s = sqrtNewtonGeneric(fromInt(Fixed[int64, 32], 4))
    check toFloat64(s) == 2.0
  test "negative raises ValueError":
    expect ValueError:
      discard sqrtNewtonGeneric(-1.0)
    expect ValueError:
      discard sqrtNewtonGeneric(initBigFloat(-1.0, 128))
    expect ValueError:
      discard sqrtNewtonGeneric(fromInt(Rational[int64], -1))
