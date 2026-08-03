# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Fixed-precision integers: `FixedInt[Bits]` (signed, two's complement) and
## `FixedUInt[Bits]` (unsigned), stored as a stack array of limbs, little-endian.
## `Bits` is a static int, so the layout and loop trips are compile-time fixed.
import ./limbs

type
  FixedInt*[Bits: static int] = object
    limbs*: array[(Bits + LimbBits - 1) div LimbBits, Limb]

  FixedUInt*[Bits: static int] = object
    limbs*: array[(Bits + LimbBits - 1) div LimbBits, Limb]

  AnyFixed*[Bits: static int] = FixedUInt[Bits] | FixedInt[Bits]

template verifyBits*(Bits: static int) =
  static:
    doAssert Bits > 0, "FixedInt must have at least 1 bit."

func initFixedUInt*[Bits: static int](val: SomeUnsignedInt): FixedUInt[
    Bits] {.inline.} =
  ## Build a `FixedUInt` from a built-in unsigned int. For `Bits < LimbBits`
  ## the value is masked to the nominal width: `divMod` reads only the low
  ## `Bits` bits, so an unmasked limb (e.g. `initFixedUInt[8](300)`) would break
  ## `q*b+r == a`. For `Bits >= LimbBits` the mask is a no-op.
  verifyBits(Bits)
  when Bits < LimbBits:
    const mask = (Limb(1) shl Bits) - 1
    result.limbs[0] = Limb(val) and mask
  else:
    result.limbs[0] = Limb(val)

func initFixedInt*[Bits: static int](val: SomeSignedInt): FixedInt[
    Bits] {.inline.} =
  ## Build a `FixedInt` from a built-in signed int. For `Bits < LimbBits` the
  ## value is two's-complement-wrapped to the nominal width and sign-extended
  ## across the limb (same `divMod` rationale as `initFixedUInt`). For
  ## `Bits >= LimbBits` the remaining limbs are sign-filled.
  verifyBits(Bits)
  when Bits < LimbBits:
    const mask = (Limb(1) shl Bits) - 1
    let lo = Limb(val) and mask
    if (lo shr (Bits - 1)) != 0:
      result.limbs[0] = lo or (not mask)
    else:
      result.limbs[0] = lo
  else:
    result.limbs[0] = Limb(val)
    if val < 0:
      for i in 1 ..< result.limbs.len:
        result.limbs[i] = MaxLimb
    else:
      for i in 1 ..< result.limbs.len:
        result.limbs[i] = ZeroLimb

func fromInt*[Bits: static int](T: typedesc[FixedInt[Bits]], v: int): FixedInt[
    Bits] {.inline.} =
  ## Concept-construction path (see `concepts.nim`).
  initFixedInt[Bits](v)

func fromInt*[Bits: static int](T: typedesc[FixedUInt[Bits]],
    v: int): FixedUInt[Bits] {.inline.} =
  ## Concept-construction path (see `concepts.nim`).
  initFixedUInt[Bits](uint64(v))

func numLimbs*[Bits: static int](T: typedesc[FixedInt[Bits] | FixedUInt[
    Bits]]): int {.compileTime.} =
  ## Limb count for `Bits`.
  (Bits + LimbBits - 1) div LimbBits

func isZero*(x: FixedUInt | FixedInt): bool {.inline.} =
  ## True when every limb is zero.
  for i in 0 ..< x.limbs.len:
    if x.limbs[i] != ZeroLimb:
      return false
  true

func toUnsigned*[Bits: static int](a: FixedInt[Bits]): FixedUInt[
    Bits] {.inline.} =
  ## Bit-level cast signed -> unsigned.
  cast[FixedUInt[Bits]](a)

func toSigned*[Bits: static int](a: FixedUInt[Bits]): FixedInt[
    Bits] {.inline.} =
  ## Bit-level cast unsigned -> signed.
  cast[FixedInt[Bits]](a)

func isNegative*[Bits: static int](a: FixedInt[Bits]): bool {.inline.} =
  ## True when the sign bit (MSB) is set.
  const signShift = LimbBits - 1
  (a.limbs[^1] shr signShift) != 0

func abs*[Bits: static int](a: FixedInt[Bits]): FixedUInt[Bits] {.inline.} =
  ## `|a|` as a `FixedUInt`. Two's-complement negation `(not a) + 1` is done
  ## inline (addition is not imported here, to keep the layer acyclic).
  if isNegative(a):
    var negated: FixedInt[Bits]
    for i in 0 ..< a.limbs.len:
      negated.limbs[i] = not a.limbs[i]
    var carry = OneLimb
    for i in 0 ..< negated.limbs.len:
      let sum = negated.limbs[i] + carry
      negated.limbs[i] = sum
      carry = if sum < carry: OneLimb else: ZeroLimb
    negated.toUnsigned()
  else:
    a.toUnsigned()



