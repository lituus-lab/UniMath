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
  test "$ is num/den, matching std/rationals":
    check $initRational(3, 4) == "3/4"
    check $initRational(-1, 2) == "-1/2"

suite "Rational over BigInt":
  test "constructs and simplifies":
    let r = initRational(initBigInt(4), initBigInt(8))
    check r.num == initBigInt(1) and r.den == initBigInt(2)
  test "fromInt typedesc is n/1":
    let r = fromInt(Rational[BigInt], 7)
    check r.num == initBigInt(7) and r.den == initBigInt(1)
    check fromInt(Rational[BigInt], 1).isOne
  test "$ delegates to BigInt's own $ (hex)":
    check $initRational(initBigInt(1), initBigInt(2)) == "0x1/0x2"
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

suite "BigInt gcd overload matches the generic Euclidean loop":
  # `gcd` has a BigInt overload that finishes in machine words once both
  # operands fit a limb. It must agree with the generic loop everywhere,
  # including the multi-limb path it falls back to and the sign normalisation.

  func genericGcd(a, b: BigInt): BigInt =
    ## The generic algorithm, spelled out so the test does not depend on
    ## which overload the compiler selects.
    var u = a
    var v = b
    let zero = initBigInt(0)
    while v != zero:
      let r = u mod v
      u = v
      v = r
    if u < zero: -u else: u

  proc probe(a, b: BigInt) =
    let got = gcd(a, b)
    let want = genericGcd(a, b)
    if got != want:
      checkpoint "gcd(" & $a & ", " & $b & ") gave " & $got & ", want " & $want
    check got == want
    # Non-negative, and a true common divisor when non-zero.
    check not got.isNegative
    if not got.isZero:
      check (a mod got).isZero
      check (b mod got).isZero

  test "small values, both signs, including zero":
    for x in [0, 1, -1, 2, -2, 6, -6, 12, 18, -18, 97, 1024, 123456, 789012]:
      for y in [0, 1, -1, 2, -2, 6, -6, 12, 18, -18, 97, 1024, 123456, 789012]:
        probe(initBigInt(x), initBigInt(y))

  test "values straddling the single-limb boundary":
    let big = initBigInt(1) shl 64
    for shift in [0, 1, 63, 64, 65, 127, 128]:
      let a = (initBigInt(3) shl Natural(shift)) + initBigInt(1)
      let b = (initBigInt(5) shl Natural(shift)) + initBigInt(1)
      probe(a, b)
      probe(a, big)
      probe(big, a)
      probe(-a, b)
      probe(a, -b)

  test "multi-limb operands with a large common factor":
    let factor = (initBigInt(1) shl 100) + initBigInt(17)
    probe(factor * initBigInt(123456789), factor * initBigInt(987654321))
    probe(factor * factor, factor * initBigInt(3))

  test "randomised, single and multi limb":
    var state = 0x9E3779B97F4A7C15'u64
    proc nextBig(limbs: int): BigInt =
      var xs = newSeq[Limb](limbs)
      for i in 0 ..< limbs:
        state = state * 6364136223846793005'u64 + 1442695040888963407'u64
        xs[i] = state
      initBigInt(initBigUInt(xs), (state and 1'u64) == 1'u64)
    for trial in 0 .. 300:
      probe(nextBig(1), nextBig(1))
      probe(nextBig(2), nextBig(1))
      probe(nextBig(3), nextBig(2))
