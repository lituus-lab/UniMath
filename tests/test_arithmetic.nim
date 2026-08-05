# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/unittest
import UniMath

suite "limbs":
  test "width":
    check LimbBits == 64
    check LimbBytes == 8
    check MaxLimb == high(uint64)
    check ZeroLimb == 0'u64
    check OneLimb == 1'u64

suite "FixedUInt[64]":
  test "construction and zero":
    check isZero(initFixedUInt[64](0'u64))
    check not isZero(initFixedUInt[64](42'u64))
  test "add wraps":
    let a = initFixedUInt[64](high(uint64))
    let b = initFixedUInt[64](1'u64)
    check (a + b) == initFixedUInt[64](0'u64)
    let (res, ovf) = add(a, b)
    check ovf
    check res == initFixedUInt[64](0'u64)
  test "sub borrows":
    let a = initFixedUInt[64](0'u64)
    let b = initFixedUInt[64](1'u64)
    check (a - b) == initFixedUInt[64](high(uint64))
  test "mul low half":
    let a = initFixedUInt[64](0xFFFF_FFFF_FFFF_FFFF'u64)
    let b = initFixedUInt[64](0xFFFF_FFFF_FFFF_FFFF'u64)
    check (a * b) == initFixedUInt[64](1'u64)
  test "fullMul is exact":
    let a = initFixedUInt[64](0xFFFF_FFFF_FFFF_FFFF'u64)
    let prod = fullMul(a, a)
    check prod.limbs[0] == 1'u64
    check prod.limbs[1] == high(uint64) - 1
  test "divMod reconstruction":
    let a = initFixedUInt[64](1_000_000_017'u64)
    let b = initFixedUInt[64](7'u64)
    let (q, r) = divMod(a, b)
    check q * b + r == a
    check r < b
  test "divMod by zero raises":
    expect(DivByZeroDefect):
      discard divMod(initFixedUInt[64](5'u64), initFixedUInt[64](0'u64))
  test "shifts":
    let a = initFixedUInt[64](0x1'u64)
    check (a shl 4) == initFixedUInt[64](0x10'u64)
    check (initFixedUInt[64](0xF0'u64) shr 4) == initFixedUInt[64](0x0F'u64)
  test "bitwise":
    let a = initFixedUInt[64](0xFF00'u64)
    let b = initFixedUInt[64](0x0FF0'u64)
    check (a and b) == initFixedUInt[64](0x0F00'u64)
    check (a or b) == initFixedUInt[64](0xFFF0'u64)
    check (a xor b) == initFixedUInt[64](0xF0F0'u64)

suite "FixedInt[64]":
  test "negation":
    let a = initFixedInt[64](5)
    check (-a) == initFixedInt[64](-5)
    check isNegative(initFixedInt[64](-1))
    check not isNegative(initFixedInt[64](1))
  test "abs":
    check abs(initFixedInt[64](-5)) == initFixedUInt[64](5)
    check abs(initFixedInt[64](5)) == initFixedUInt[64](5)
  test "signed divMod truncates toward zero":
    check divMod(initFixedInt[64](-7), initFixedInt[64](2)) ==
      (q: initFixedInt[64](-3), r: initFixedInt[64](-1))
    check divMod(initFixedInt[64](7), initFixedInt[64](-2)) ==
      (q: initFixedInt[64](-3), r: initFixedInt[64](1))
  test "MinInt div -1 raises":
    expect(OverflowDefect):
      discard divMod(initFixedInt[64](low(int64)), initFixedInt[64](-1))
  test "MinInt div 1 is MinInt (representable)":
    check divMod(initFixedInt[64](low(int64)), initFixedInt[64](1)) ==
      (q: initFixedInt[64](low(int64)), r: initFixedInt[64](0))
  test "arithmetic shr sign-extends":
    check (initFixedInt[64](-8) shr 1) == initFixedInt[64](-4)
    check (initFixedInt[64](-1) shr 100) == initFixedInt[64](-1)

suite "BigUInt":
  test "construction":
    check isZero(initBigUInt(0'u64))
    check initBigUInt(42'u64).limbs == @[Limb(42)]
    let fromSeq = initBigUInt(@[Limb(5), Limb(0)])
    check fromSeq.limbs == @[Limb(5)] # high zero limb trimmed
  test "add/sub":
    let a = initBigUInt(1_000_000_000_000'u64)
    let b = initBigUInt(1'u64)
    check (a + b) == initBigUInt(1_000_000_000_001'u64)
    check (a - b) == initBigUInt(999_999_999_999'u64)
  test "sub underflow raises":
    expect(Defect):
      discard initBigUInt(1'u64) - initBigUInt(2'u64)
  test "mul zero propagation":
    check (initBigUInt(0'u64) * initBigUInt(123'u64)) == initBigUInt(0'u64)
    let a = initBigUInt(1_000_000'u64)
    check (a * initBigUInt(1_000_000'u64)) == initBigUInt(1_000_000_000_000'u64)
  test "divMod reconstruction":
    let a = initBigUInt(1_000_000_017'u64)
    let b = initBigUInt(7'u64)
    let (q, r) = divMod(a, b)
    check q * b + r == a
    check r < b
  test "divMod multi-limb divisor reaches divModKnuth":
    # Every single-limb divisor takes the divModLimb fast path, leaving Knuth's
    # qhat correction and add-back branches uncovered. The first divisor has its
    # top bit set (s == 0, no normalization shift), the second does not.
    let a = initBigUInt(@[Limb(0x0123456789ABCDEF'u64),
                          Limb(0xFEDCBA9876543210'u64),
                          Limb(0x1111222233334444'u64)])
    for b in [initBigUInt(@[Limb(0xFFFFFFFFFFFFFFFF'u64),
                            Limb(0x8000000000000000'u64)]),
              initBigUInt(@[Limb(1'u64), Limb(1'u64)]),
              initBigUInt(@[Limb(0'u64), Limb(0'u64), Limb(
                  0x0000000000000003'u64)])]:
      let (q, r) = divMod(a, b)
      check q * b + r == a
      check r < b
  test "shifts and bitwise":
    let a = initBigUInt(0xFF'u64)
    check (a shl 8) == initBigUInt(0xFF00'u64)
    check (initBigUInt(0xFF00'u64) shr 8) == initBigUInt(0xFF'u64)
    check (initBigUInt(0xFF00'u64) and initBigUInt(0x0FF0'u64)) ==
      initBigUInt(0x0F00'u64)
  test "bitLength":
    check bitLength(initBigUInt(0'u64)) == 0
    check bitLength(initBigUInt(1'u64)) == 1
    check bitLength(initBigUInt(@[ZeroLimb, OneLimb])) == 65 # 2^64, two limbs

  test "Karatsuba matches schoolbook":
    var la = newSeq[Limb](40)
    var lb = newSeq[Limb](40)
    for i in 0 ..< 40:
      la[i] = Limb(i.uint64 * 12345 + 7) and MaxLimb
      lb[i] = Limb(i.uint64 * 99991 + 3) and MaxLimb
    let a = initBigUInt(la)
    let b = initBigUInt(lb)
    let school = mul(a, b, Schoolbook)
    let karat = mul(a, b, Karatsuba)
    check karat == school
    check (a * b) == school # Auto selects Karatsuba past the threshold

suite "BigInt":
  test "construction and sign":
    check isZero(initBigInt(0))
    check initBigInt(-5).isNegative
    check not initBigInt(5).isNegative
  test "add/sub signs":
    check (initBigInt(-5) + initBigInt(5)) == initBigInt(0)
    check (initBigInt(-5) - initBigInt(-5)) == initBigInt(0)
    check (initBigInt(-3) + initBigInt(-4)) == initBigInt(-7)
    check (initBigInt(3) + initBigInt(-7)) == initBigInt(-4)
  test "mul":
    check (initBigInt(-3) * initBigInt(4)) == initBigInt(-12)
    check (initBigInt(-3) * initBigInt(-4)) == initBigInt(12)
  test "divMod":
    check divMod(initBigInt(-7), initBigInt(2)) ==
      (q: initBigInt(-3), r: initBigInt(-1))
    check divMod(initBigInt(7), initBigInt(-2)) ==
      (q: initBigInt(-3), r: initBigInt(1))
  test "comparison":
    check initBigInt(-5) < initBigInt(0)
    check initBigInt(-5) < initBigInt(-4)
    check initBigInt(5) == initBigInt(5)
  test "unary negation preserves zero":
    check -initBigInt(0) == initBigInt(0)
    check -initBigInt(7) == initBigInt(-7)
  test "shr floor semantics":
    check (initBigInt(-8) shr 1) == initBigInt(-4)
    check (initBigInt(-7) shr 1) == initBigInt(-4) # floor(-7/2) = -4

suite "wide helpers":
  test "mul128":
    let r = mul128(high(uint64), high(uint64))
    check r.lo == 1'u64
    check r.hi == high(uint64) - 1
  test "cmpMul128":
    check cmpMul128(2, 3, 5, 1) == 1 # 6 > 5
    check cmpMul128(2, 3, 6, 1) == 0 # 6 == 6
    check cmpMul128(2, 3, 7, 1) == -1 # 6 < 7
  test "absToU64 MinInt-safe":
    check absToU64(low(int64)) == (1'u64 shl 63)
    check absToU64(-1'i64) == 1'u64
    check absToU64(5'i64) == 5'u64
  test "pow2f64":
    check pow2f64(0) == 1.0
    check pow2f64(10) == 1024.0
    check pow2f64(1024) == Inf
    check pow2f64(-1075) == 0.0
  test "mulShiftRightSigned":
    check mulShiftRightSigned(1_000_000, 1_000_000, 10) == 976_562_500 # floor(1e12/1024)
    expect(ValueError):
      discard mulShiftRightSigned(1, 1, -1)
  test "mulShiftRightSigned discards to 0, not -1, for a zero product":
    # One operand negative makes the sign flag true even when the product is 0,
    # whose floor is 0 at any shift.
    check mulShiftRightSigned(0, -5, 128) == 0
    check mulShiftRightSigned(-5, 0, 200) == 0
    check mulShiftRightSigned(-5, 3, 128) == -1
    check mulShiftRightSigned(5, 3, 128) == 0
  test "divmod128by64":
    let (q, r) = divmod128by64(0'u64, 1_000_000_017'u64, 7'u64)
    check q == 142_857_145
    check r == 2'u64
    expect(Defect):
      discard divmod128by64(1'u64, 0'u64, 0'u64)

suite "float_conv":
  test "exact below 2^53":
    check toFloat64(initBigUInt(0'u64)) == 0.0
    check toFloat64(initBigUInt(1'u64)) == 1.0
    check toFloat64(initBigUInt(1'u64 shl 52)) == float64(1'u64 shl 52)
  test "large rounds correctly":
    let v = initBigUInt(1'u64 shl 53) + initBigUInt(1'u64)
    check toFloat64(v) == float64(1'u64 shl 53) # ties-to-even drops the 1
  test "BigInt sign":
    check toFloat64(initBigInt(-5)) == -5.0
    check toFloat64(initBigInt(0)) == 0.0

suite "formatting":
  test "toHex":
    check $initBigUInt(0'u64) == "0x0"
    check $initBigUInt(0xFF'u64) == "0xFF"
    check $initBigInt(-0xFF) == "-0xFF"
  test "toDecimal":
    check toDecimal(initBigUInt(0'u64)) == "0"
    check toDecimal(initBigUInt(1_000_000_017'u64)) == "1000000017"
    check toDecimal(initBigInt(-1_000_000_017)) == "-1000000017"

suite "concepts":
  test "zero/one":
    check zero(BigInt) == initBigInt(0)
    check one(BigInt) == initBigInt(1)
    check zero(int) == 0
    check one(int) == 1

  test "RealField accepts every geometric scalar":
    # The scalar contract UniLinalg.Vector constrains on: ordered field plus
    # sqrt and abs, all reachable through `import UniMath` alone (this file
    # does NOT import std/math). float sqrt is re-exported by UniMath/roots,
    # abs(float) is in system, and the exact types bring their own overloads.
    check float64 is RealField
    check float32 is RealField
    check Fixed[int64, 32] is RealField
    check Rational[int64] is RealField
    check BigFloat is RealField
