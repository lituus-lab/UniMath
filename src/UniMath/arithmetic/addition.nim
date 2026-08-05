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

func signBit[Bits: static int, T: AnyFixed[Bits]](v: T): Limb {.inline.} =
  ## Top bit of the top limb. Sub-limb widths are sign-extended across the limb
  ## (see `fixed_int.narrow`), so this is the nominal sign bit for every `Bits`.
  v.limbs[^1] shr (LimbBits - 1)

func `+`*[Bits: static int, T: AnyFixed[Bits]](a, b: T): T {.inline.} =
  let (res, overflow) = add(a, b)
  # Narrow before testing: for a sub-limb width the raw limb still holds bits
  # the nominal type cannot, and both tests below read the narrowed value.
  result = narrow(res)
  when defined(checkedArithmetic):
    # The carry out of the top limb is the unsigned condition. For the signed
    # instantiation it is neither necessary nor sufficient -- `-1 + 1` carries
    # out with an in-range result, `high + 1` does not carry and wraps -- so the
    # signed test is: equal operand signs, differing result sign.
    when T is FixedInt[Bits]:
      if signBit(a) == signBit(b) and signBit(result) != signBit(a):
        raise newException(OverflowDefect, "FixedInt addition overflow: " &
            $Bits & " bits")
    else:
      # Below a limb there is no carry out to read -- FixedUInt[8](255) + 1
      # fills bit 8 of a 64-bit limb -- so the discarded bits are the signal.
      if overflow or discardedByNarrowing(res, result):
        raise newException(OverflowDefect, "FixedUInt addition overflow: " &
            $Bits & " bits")

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
  result = narrow(res)
  when defined(checkedArithmetic):
    # Signed counterpart of `+`: differing operand signs, result sign unlike the
    # minuend. The borrow-out is the unsigned condition only.
    when T is FixedInt[Bits]:
      if signBit(a) != signBit(b) and signBit(result) != signBit(a):
        raise newException(OverflowDefect, "FixedInt subtraction overflow: " &
            $Bits & " bits")
    else:
      if underflow or discardedByNarrowing(res, result):
        raise newException(OverflowDefect, "FixedUInt subtraction underflow: " &
            $Bits & " bits")

func `-`*[Bits: static int](a: FixedInt[Bits]): FixedInt[Bits] {.inline.} =
  ## Two's-complement negation: `0 - a`.
  initFixedInt[Bits](0) - a

