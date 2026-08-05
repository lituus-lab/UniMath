# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Limb-array ops. The bitwise arrays go through intrinsics under `-d:simd`
## (NEON/SSE2) and through the scalar fallback otherwise; both must match the
## plain limb operators. Run with `nimble testSimd` to exercise the intrinsics.
import std/unittest
import UniMath

proc refAnd(a, b: openArray[Limb]): seq[Limb] =
  result = newSeq[Limb](a.len)
  for i in 0 ..< a.len: result[i] = a[i] and b[i]

proc refOr(a, b: openArray[Limb]): seq[Limb] =
  result = newSeq[Limb](a.len)
  for i in 0 ..< a.len: result[i] = a[i] or b[i]

proc refXor(a, b: openArray[Limb]): seq[Limb] =
  result = newSeq[Limb](a.len)
  for i in 0 ..< a.len: result[i] = a[i] xor b[i]

suite "limb arrays":
  test "addCArray":
    let a = @[Limb(1), Limb(high(uint64)), Limb(0)]
    let b = @[Limb(1), Limb(1), Limb(5)]
    var res: seq[Limb]
    var carry: Limb
    addCArray(a, b, res, carry)
    check res == @[Limb(2), Limb(0), Limb(6)]
    check carry == 0
  test "subBArray":
    let a = @[Limb(0), Limb(0), Limb(5)]
    let b = @[Limb(1), Limb(0), Limb(0)]
    var res: seq[Limb]
    var borrow: Limb
    subBArray(a, b, res, borrow)
    check res == @[Limb(high(uint64)), Limb(high(uint64)), Limb(4)]
    check borrow == 0
  test "mulArray":
    let a = @[Limb(2), Limb(0)]
    let b = @[Limb(3), Limb(0)]
    var res: seq[Limb]
    mulArray(a, b, res)
    check res == @[Limb(6), Limb(0), Limb(0), Limb(0)]
  test "andArray matches scalar":
    let a = @[Limb(0xFF00), Limb(0x0FF0), Limb(0xF0F0), Limb(0x1234), Limb(0xABCD)]
    let b = @[Limb(0x0FF0), Limb(0xFF00), Limb(0x0F0F), Limb(0x4321), Limb(0xDCBA)]
    var res: seq[Limb]
    andArray(a, b, res)
    check res == refAnd(a, b)
  test "orArray matches scalar":
    let a = @[Limb(0xFF00), Limb(0x0FF0), Limb(0xF0F0), Limb(0x1234), Limb(0xABCD)]
    let b = @[Limb(0x0FF0), Limb(0xFF00), Limb(0x0F0F), Limb(0x4321), Limb(0xDCBA)]
    var res: seq[Limb]
    orArray(a, b, res)
    check res == refOr(a, b)
  test "xorArray matches scalar":
    let a = @[Limb(0xFF00), Limb(0x0FF0), Limb(0xF0F0), Limb(0x1234), Limb(0xABCD)]
    let b = @[Limb(0x0FF0), Limb(0xFF00), Limb(0x0F0F), Limb(0x4321), Limb(0xDCBA)]
    var res: seq[Limb]
    xorArray(a, b, res)
    check res == refXor(a, b)

suite "simd info":
  test "features string is non-empty":
    check getSimdFeatures().len > 0
  test "supported flag is a bool":
    let s = simdBitwiseSupported()
    check s == true or s == false
