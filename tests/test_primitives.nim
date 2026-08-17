# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Differential tests for the limb-level primitives.
##
## These had no direct coverage: `mulWide`, `mulAdd`, `addC` and `subB` were
## exercised only through big-integer multiplication and division, where a
## carry bug shows up as a wrong quotient several layers away from its cause.
## They are the hottest and lowest-level code in the library and the easiest
## place to break silently, so they get their own oracle here.
##
## THE ORACLE IS INDEPENDENT ON PURPOSE. The reference below decomposes into
## **16-bit** chunks, where the implementation uses 32-bit halves and the
## platform fast paths use a single 128-bit multiply. Three different
## decompositions have no shared arithmetic to be wrong in the same way; a
## reference that reused the implementation's own splitting would agree with it
## bug for bug.
##
## Every 16x16 product is at most 65535^2, and a column accumulates at most
## four of them plus a carry, so the reference never leaves the exact range of
## `uint64` and needs no wide type of its own.

import std/[unittest, strutils]
import UniMath/arithmetic/limbs
import UniMath/arithmetic/primitives
import UniMath/arithmetic/big_int
import UniMath/arithmetic/bitwise_big
import UniMath/arithmetic/subtraction_big
import UniMath/arithmetic/wide

# ---- the independent reference ---------------------------------------------

func refMul128(a, b: uint64): tuple[hi, lo: uint64] =
  ## `a * b` as a 128-bit value, via 16-bit schoolbook.
  var ac, bc: array[4, uint64]
  for i in 0 .. 3:
    ac[i] = (a shr (16 * i)) and 0xFFFF'u64
    bc[i] = (b shr (16 * i)) and 0xFFFF'u64
  var col: array[8, uint64]
  for i in 0 .. 3:
    for j in 0 .. 3:
      col[i + j] += ac[i] * bc[j]
  var digit: array[8, uint64]
  var carry = 0'u64
  for k in 0 .. 7:
    let v = col[k] + carry
    digit[k] = v and 0xFFFF'u64
    carry = v shr 16
  doAssert carry == 0, "a 64x64 product cannot exceed 128 bits"
  var lo, hi = 0'u64
  for k in 0 .. 3:
    lo = lo or (digit[k] shl (16 * k))
    hi = hi or (digit[k + 4] shl (16 * k))
  (hi, lo)

func refAdd(a, b, carryIn: uint64): tuple[sum, carry: uint64] =
  ## `a + b + carryIn` in 16-bit chunks, so the carry-out is computed rather
  ## than inferred from a wraparound comparison.
  var sum = 0'u64
  var carry = carryIn
  for k in 0 .. 3:
    let av = (a shr (16 * k)) and 0xFFFF'u64
    let bv = (b shr (16 * k)) and 0xFFFF'u64
    let v = av + bv + carry
    sum = sum or ((v and 0xFFFF'u64) shl (16 * k))
    carry = v shr 16
  (sum, carry)

func refSub(a, b, borrowIn: uint64): tuple[diff, borrow: uint64] =
  var diff = 0'u64
  var borrow = borrowIn
  for k in 0 .. 3:
    let av = (a shr (16 * k)) and 0xFFFF'u64
    let bv = (b shr (16 * k)) and 0xFFFF'u64
    let v = av - bv - borrow
    diff = diff or ((v and 0xFFFF'u64) shl (16 * k))
    borrow = (v shr 16) and 1'u64
  (diff, borrow)

# ---- operand corpus --------------------------------------------------------

const edgeCases: seq[uint64] = @[
  0'u64, 1'u64, 2'u64,
  0xFFFF'u64, 0x10000'u64,         # 16-bit chunk boundary
  0xFFFFFFFF'u64, 0x100000000'u64, # 32-bit half boundary
  0xFFFFFFFFFFFFFFFF'u64,          # all ones
  0xFFFFFFFFFFFFFFFE'u64,
  0x8000000000000000'u64,          # top bit only
  0x7FFFFFFFFFFFFFFF'u64,
  0xAAAAAAAAAAAAAAAA'u64, 0x5555555555555555'u64,
  0x0123456789ABCDEF'u64, 0xFEDCBA9876543210'u64,
]

iterator randomLimbs(count: int): uint64 =
  ## A fixed LCG, not `std/random`: a failure has to be reproducible from the
  ## test name alone, and comparable between two machines.
  var state = 0x853C49E6748FEA9B'u64
  for _ in 0 ..< count:
    state = state * 6364136223846793005'u64 + 1442695040888963407'u64
    # Both halves stirred, so the corpus is not biased toward small values.
    yield state xor (state shr 29)

suite "limb primitives — mulWide":

  test "edge cases against the 16-bit reference":
    for a in edgeCases:
      for b in edgeCases:
        var hi: Limb
        let lo = mulWide(a, b, hi)
        let want = refMul128(a, b)
        checkpoint "a = 0x" & a.toHex & "  b = 0x" & b.toHex
        check lo == want.lo
        check hi == want.hi

  test "randomized against the 16-bit reference":
    var operands: seq[uint64]
    for x in randomLimbs(400): operands.add x
    for a in operands:
      for b in operands[0 ..< 40]:
        var hi: Limb
        let lo = mulWide(a, b, hi)
        let want = refMul128(a, b)
        if lo != want.lo or hi != want.hi:
          checkpoint "a = 0x" & a.toHex & "  b = 0x" & b.toHex
          check lo == want.lo
          check hi == want.hi

  test "squares of every power of two":
    # (2^i)*(2^j) lands the single set bit on every position of the 128-bit
    # result, including exactly on the hi/lo seam.
    for i in 0 .. 63:
      for j in 0 .. 63:
        let a = 1'u64 shl i
        let b = 1'u64 shl j
        var hi: Limb
        let lo = mulWide(a, b, hi)
        let k = i + j
        let wantLo = if k < 64: 1'u64 shl k else: 0'u64
        let wantHi = if k >= 64: 1'u64 shl (k - 64) else: 0'u64
        if lo != wantLo or hi != wantHi:
          checkpoint "2^" & $i & " * 2^" & $j
          check lo == wantLo
          check hi == wantHi

suite "limb primitives — mulWidePortable and the native path agree":

  test "the portable decomposition matches the 16-bit reference":
    # The fallback is what non-amd64, non-gcc/clang and `-d:noInt128` builds
    # run. It has to be checked in its own right, not only as whatever
    # `mulWide` happens to select on the machine running the suite.
    for a in edgeCases:
      for b in edgeCases:
        var hi: Limb
        let lo = mulWidePortable(a, b, hi)
        let want = refMul128(a, b)
        checkpoint "a = 0x" & a.toHex & "  b = 0x" & b.toHex
        check lo == want.lo
        check hi == want.hi

  test "native and portable agree bit for bit":
    # On a build with no native path this is the portable one compared against
    # itself, which is why the check above exists separately. Where there IS a
    # native path, this is what catches a fast path that is fast and wrong.
    checkpoint "hasNativeWide = " & $hasNativeWide &
               ", hasInt128 = " & $hasInt128 & ", hasUmul128 = " & $hasUmul128
    var operands = edgeCases
    for x in randomLimbs(300): operands.add x
    for a in operands:
      for b in operands[0 ..< 60]:
        var hiN, hiP: Limb
        let loN = mulWide(a, b, hiN)
        let loP = mulWidePortable(a, b, hiP)
        if loN != loP or hiN != hiP:
          checkpoint "a = 0x" & a.toHex & "  b = 0x" & b.toHex
          check loN == loP
          check hiN == hiP

  test "native and portable agree on every power-of-two pair":
    for i in 0 .. 63:
      for j in 0 .. 63:
        var hiN, hiP: Limb
        let loN = mulWide(1'u64 shl i, 1'u64 shl j, hiN)
        let loP = mulWidePortable(1'u64 shl i, 1'u64 shl j, hiP)
        if loN != loP or hiN != hiP:
          checkpoint "2^" & $i & " * 2^" & $j
          check loN == loP
          check hiN == hiP

suite "limb primitives — mulAdd":

  test "edge cases: (a*b) + c + carry against the reference":
    for a in edgeCases:
      for b in edgeCases:
        for c in [0'u64, 1'u64, 0xFFFFFFFFFFFFFFFF'u64]:
          for carryIn in [0'u64, 1'u64, 0xFFFFFFFFFFFFFFFF'u64]:
            var carry = carryIn
            let got = mulAdd(a, b, c, carry)
            # Reference: the 128-bit product, then two 128-bit additions.
            let p = refMul128(a, b)
            let s1 = refAdd(p.lo, c, 0)
            let h1 = refAdd(p.hi, s1.carry, 0)
            let s2 = refAdd(s1.sum, carryIn, 0)
            let h2 = refAdd(h1.sum, s2.carry, 0)
            checkpoint "a=0x" & a.toHex & " b=0x" & b.toHex &
                       " c=0x" & c.toHex & " carry=0x" & carryIn.toHex
            check got == s2.sum
            check carry == h2.sum
            # The documented invariant: no overflow past the high limb.
            check h1.carry == 0
            check h2.carry == 0

  test "the maximal case cannot overflow the carry limb":
    # (2^64-1)^2 + (2^64-1) + (2^64-1) = 2^128 - 1 exactly: the tightest input
    # there is, and the one the doc comment's claim rests on.
    let m = 0xFFFFFFFFFFFFFFFF'u64
    var carry = m
    let got = mulAdd(m, m, m, carry)
    check got == m
    check carry == m

  test "randomized against the reference":
    var operands: seq[uint64]
    for x in randomLimbs(120): operands.add x
    for a in operands:
      for b in operands[0 ..< 20]:
        let c = a xor 0x5DEECE66D'u64
        let carryIn = b xor 0xB'u64
        var carry = carryIn
        let got = mulAdd(a, b, c, carry)
        let p = refMul128(a, b)
        let s1 = refAdd(p.lo, c, 0)
        let h1 = refAdd(p.hi, s1.carry, 0)
        let s2 = refAdd(s1.sum, carryIn, 0)
        let h2 = refAdd(h1.sum, s2.carry, 0)
        if got != s2.sum or carry != h2.sum:
          checkpoint "a=0x" & a.toHex & " b=0x" & b.toHex
          check got == s2.sum
          check carry == h2.sum

suite "limb primitives — addC and subB":

  test "addC against the reference, edges and carries":
    for a in edgeCases:
      for b in edgeCases:
        for carryIn in [0'u64, 1'u64]:
          var carryOut: Limb
          let got = addC(carryIn, a, b, carryOut)
          let want = refAdd(a, b, carryIn)
          checkpoint "a=0x" & a.toHex & " b=0x" & b.toHex & " cin=" & $carryIn
          check got == want.sum
          check carryOut == want.carry

  test "subB against the reference, edges and borrows":
    for a in edgeCases:
      for b in edgeCases:
        for borrowIn in [0'u64, 1'u64]:
          var borrowOut: Limb
          let got = subB(borrowIn, a, b, borrowOut)
          let want = refSub(a, b, borrowIn)
          checkpoint "a=0x" & a.toHex & " b=0x" & b.toHex & " bin=" & $borrowIn
          check got == want.diff
          check borrowOut == want.borrow

  test "addC carry-out is 0 or 1, never a wider value":
    # `carryOut = c1 or c2` would be 2 if both could fire at once; they cannot,
    # and this is the check that says so rather than the comment.
    for a in edgeCases:
      for b in edgeCases:
        for carryIn in [0'u64, 1'u64]:
          var carryOut: Limb
          discard addC(carryIn, a, b, carryOut)
          check carryOut <= 1'u64

  test "add then subtract round-trips":
    for a in edgeCases:
      for b in edgeCases:
        var carryOut, borrowOut: Limb
        let s = addC(0, a, b, carryOut)
        let d = subB(0, s, b, borrowOut)
        # a + b - b == a in the low limb, and the borrow undoes the carry.
        check d == a
        check borrowOut == carryOut

suite "allocation-free bit inspection":

  # Checked against the `a and ((1 shl n) - 1)` and `(a shr k).toUInt64()`
  # expressions they replace in the rounding paths.

  proc sample(): seq[BigUInt] =
    result = @[
      initBigUInt(0'u64),
      initBigUInt(1'u64),
      initBigUInt(0xFFFFFFFFFFFFFFFF'u64),
      initBigUInt(@[0'u64, 1'u64]), # bit 64 only
      initBigUInt(@[0'u64, 0'u64, 0x8000000000000000'u64]), # bit 191 only
      initBigUInt(@[0xFFFFFFFFFFFFFFFF'u64, 0x0123456789ABCDEF'u64,
                    0xFEDCBA9876543210'u64, 0x8000000000000000'u64]),
      initBigUInt(@[0'u64, 0'u64, 0'u64, 1'u64]),
    ]

  test "lowBitsNonZero matches the mask-and-compare it replaces":
    let one = initBigUInt(1'u64)
    for a in sample():
      for n in 0 .. 260:
        let want =
          if n <= 0: false
          else: not isZero(a and ((one shl Natural(n)) - one))
        if a.lowBitsNonZero(n) != want:
          checkpoint "n = " & $n & "  limbs = " & $a.limbs.len
          check a.lowBitsNonZero(n) == want

  test "bitWindow matches a masked shift":
    # The reference masks to 64 bits first: `toUInt64` raises past one limb.
    # Covers windows beyond the 54-bit one the production call site uses.
    let mask64 = initBigUInt(0xFFFFFFFFFFFFFFFF'u64)
    for a in sample():
      for k in 0 .. 260:
        let want = ((a shr Natural(k)) and mask64).toUInt64()
        if a.bitWindow(Natural(k)) != want:
          checkpoint "k = " & $k & "  limbs = " & $a.limbs.len
          check a.bitWindow(Natural(k)) == want

  test "bitWindow at a limb boundary folds in no neighbour":
    # k mod 64 == 0 is the case where `shl (64 - 0)` would be undefined in C.
    let a = initBigUInt(@[0xAAAAAAAAAAAAAAAA'u64, 0x5555555555555555'u64])
    check a.bitWindow(0) == 0xAAAAAAAAAAAAAAAA'u64
    check a.bitWindow(64) == 0x5555555555555555'u64
    check a.bitWindow(128) == 0'u64

  test "past the top is zero, not garbage":
    let a = initBigUInt(1'u64)
    check a.bitWindow(64) == 0'u64
    check a.bitWindow(1000) == 0'u64
    check not a.lowBitsNonZero(0)
    check a.lowBitsNonZero(1)

suite "limb primitives — clzLimb":

  test "leading zeros of every power of two":
    for i in 0 .. 63:
      check clzLimb(1'u64 shl i) == 63 - i

  test "zero is the documented special case":
    check clzLimb(0'u64) == LimbBits

  test "a set top bit is zero regardless of the rest":
    for x in randomLimbs(200):
      check clzLimb(x or 0x8000000000000000'u64) == 0
