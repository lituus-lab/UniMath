# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/unittest
import UniMath

suite "Rational construction":
  test "simplifies to lowest terms":
    let r = initRational(4, 8)
    check r.num == 1 and r.den == 2
    let s = initRational(6, 9)
    check s.num == 2 and s.den == 3
  test "sign moves into the numerator":
    let r = initRational(1, -2)
    check r.num == -1 and r.den == 2
    let s = initRational(-3, -9)
    check s.num == 1 and s.den == 3
  test "zero is canonical 0/1":
    let r = initRational(0, 5)
    check r.num == 0 and r.den == 1
    check r.isZero
  test "denominator zero raises":
    expect(Defect):
      discard initRational(1, 0)
  test "unchecked stores verbatim":
    let r = initRationalUnchecked(2, 4)
    check r.num == 2 and r.den == 4

suite "Rational over BigInt":
  test "constructs and simplifies":
    let r = initRational(initBigInt(4), initBigInt(8))
    check r.num == initBigInt(1) and r.den == initBigInt(2)
  test "fromInt typedesc is n/1":
    let r = fromInt(Rational[BigInt], 7)
    check r.num == initBigInt(7) and r.den == initBigInt(1)
    check fromInt(Rational[BigInt], 1).isOne
  test "large products stay exact":
    let big = initBigInt(1_000_000_000_000) * initBigInt(1_000_000_000_000)
    let r = initRational(big, initBigInt(1_000_000_000_000))
    check r.num == initBigInt(1_000_000_000_000) and r.den == initBigInt(1)

suite "Rational arithmetic":
  test "add sub":
    let a = initRational(1, 2)
    let b = initRational(1, 3)
    check a + b == initRational(5, 6)
    check a - b == initRational(1, 6)
  test "mul div":
    let a = initRational(2, 3)
    let b = initRational(4, 5)
    check a * b == initRational(8, 15)
    check a / b == initRational(10, 12)
  test "unary negation and abs":
    let a = initRational(3, 4)
    check (-a) == initRational(-3, 4)
    check abs(initRational(-3, 4)) == initRational(3, 4)
  test "division by zero raises":
    expect(Defect):
      discard initRational(1, 2) / initRational(0, 1)
  test "coprime-denominator addition reduces":
    check initRational(1, 2) + initRational(1, 6) == initRational(2, 3)

suite "Rational comparison":
  test "trichotomy":
    check cmp(initRational(1, 2), initRational(1, 3)) == 1
    check cmp(initRational(1, 3), initRational(1, 2)) == -1
    check cmp(initRational(2, 4), initRational(1, 2)) == 0
  test "operators":
    check initRational(1, 2) < initRational(2, 3)
    check initRational(2, 3) > initRational(1, 2)
    check initRational(1, 2) <= initRational(1, 2)
    check initRational(1, 2) >= initRational(1, 3)
  test "mixed rational vs integer":
    check initRational(1, 2) < 1
    check initRational(1, 1) == 1
  test "BigInt cross-multiply ordering":
    let big = initBigInt(1_000_000_000_000) * initBigInt(1_000_000_000_000)
    check initRational(big, initBigInt(2)) > initRational(big, initBigInt(3))

suite "Rational gcd/lcm":
  test "gcd":
    check gcd(12, 8) == 4
    check gcd(initBigInt(12), initBigInt(8)) == initBigInt(4)
    check gcd(7, 0) == 7
  test "lcm":
    check lcm(4, 6) == 12
    check lcm(0, 5) == 0
  test "gcd of MinInt and zero raises":
    expect(Defect):
      discard gcd(low(int64), 0)
  test "denominator MinInt raises on sign flip":
    expect(Defect):
      discard initRational(1, low(int64))

suite "Rational toFloat64":
  test "approximate conversion":
    check toFloat64(initRational(1, 2)) == 0.5
    check toFloat64(initRational(1, 3)) == 1.0 / 3.0
    check toFloat64(initRational(-3, 4)) == -0.75
