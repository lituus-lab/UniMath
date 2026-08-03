# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Fixed-precision addition and subtraction: schoolbook limb-by-limb with
## carry/borrow propagation. Wrapping; the carry/borrow-out is returned.
import ./limbs
import ./primitives
import ./fixed_int
import contracts

func add*[Bits: static int, T: AnyFixed[Bits]](a, b: T): tuple[res: T,
    overflow: bool] {.contractual, inline.} =
  ## Wrapping sum and the raw carry out of the most significant limb.
  ensure:
    result.res.limbs[0] == a.limbs[0] + b.limbs[0]
  body:
    var carry = ZeroLimb
    for i in 0 ..< a.limbs.len:
      var newCarry: Limb
      result.res.limbs[i] = addC(carry, a.limbs[i], b.limbs[i], newCarry)
      carry = newCarry
    result.overflow = (carry > ZeroLimb)

func `+`*[Bits: static int, T: AnyFixed[Bits]](a, b: T): T {.inline.} =
  let (res, overflow) = add(a, b)
  when defined(checkedArithmetic):
    if overflow:
      raise newException(OverflowDefect, "FixedInt addition overflow: " &
          $Bits & " bits")
  res

func sub*[Bits: static int, T: AnyFixed[Bits]](a, b: T): tuple[res: T,
    underflow: bool] {.contractual, inline.} =
  ## Wrapping difference and the borrow-out.
  ensure:
    result.res.limbs[0] == a.limbs[0] - b.limbs[0]
  body:
    var borrow = ZeroLimb
    for i in 0 ..< a.limbs.len:
      result.res.limbs[i] = subB(borrow, a.limbs[i], b.limbs[i], borrow)
    result.underflow = (borrow > ZeroLimb)

func `-`*[Bits: static int, T: AnyFixed[Bits]](a, b: T): T {.inline.} =
  let (res, underflow) = sub(a, b)
  when defined(checkedArithmetic):
    if underflow:
      raise newException(OverflowDefect, "FixedInt subtraction underflow: " &
          $Bits & " bits")
  res

func `-`*[Bits: static int](a: FixedInt[Bits]): FixedInt[Bits] {.inline.} =
  ## Two's-complement negation: `0 - a`.
  initFixedInt[Bits](0) - a

