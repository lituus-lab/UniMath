# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Compile-time look-up-table trigonometry for fixed-point. A 256-entry sine
## table is generated at compile time and indexed in O(1) with no RAM cost —
## suited to small microcontrollers. `|sin|, |cos| <= 1`, so every entry and
## every convex interpolation of two entries stays in `[-2^FracBits, 2^FracBits]`;
## the bound postcondition holds on the non-raising path (the `getPiFixedLut`
## overflow guard raises first beyond the type's safe limit).
import std/math
import contracts
import ../fixed
import ../arithmetic

type
  InterpolationType* = enum
    itNone   ## Nearest-neighbour (fastest, ideal for 8-bit)
    itLinear ## Linear interpolation (smooth, ideal for 32-bit)

const DefaultLutSize* = 256
  ## The index arithmetic `a*256*2^FracBits` fits `int64` only for
  ## `FracBits <= 52`; beyond that the modulus `2*pi*2^FracBits` overflows
  ## `int64`, so use the BigFloat `sin`/`cos` instead.

# Per-storage safe `FracBits` limit: the modulus `2*pi*2^FracBits` must fit the
# signed type and the index arithmetic must fit int64. Selected by overload
# resolution (a per-width bound, not duck-typing).
func maxLutFrac*(T: typedesc[int16]): int {.inline.} = 12
func maxLutFrac*(T: typedesc[int32]): int {.inline.} = 28
func maxLutFrac*(T: typedesc[int64]): int {.inline.} = 52
func maxLutFrac*(T: typedesc): int {.inline.} = 52

func getPiFixedLut*[T; FracBits: static[int]](): Fixed[T, FracBits] {.inline.} =
  ## `pi` in fixed-point. Raises `OverflowDefect` (body `raise`, survives
  ## release) when `FracBits` exceeds the storage type's safe limit — the
  ## modulus would otherwise wrap and index out of range.
  mixin fromFloat
  let maxFrac = maxLutFrac(T)
  if FracBits > maxFrac:
    raise newException(OverflowDefect,
      "sin_lut/cos_lut require FracBits <= " & $maxFrac &
      " for this storage type; use BigFloat sin/cos for higher precision")
  let scale = float(pow2f64(FracBits))
  initFixed[T, FracBits](fromFloat(T, 3.14159265358979323846 * scale))

func generateSinLut[T; FracBits: static[int]](): array[DefaultLutSize, T] =
  mixin fromFloat
  for i in 0 ..< DefaultLutSize:
    let angleRad = float(i) * (2.0 * PI / float(DefaultLutSize))
    let scale = pow2f64(FracBits)
    result[i] = fromFloat(T, sin(angleRad) * scale)

template getSinLut(T: typedesc; FracBits: static[int]): array[DefaultLutSize, T] =
  const table = generateSinLut[T, FracBits]()
  table

func sin_lut*[T; FracBits: static[int]](angle: Fixed[T, FracBits];
    interp: static[InterpolationType] = itNone): Fixed[T,
        FracBits] {.contractual.} =
  ## LUT sine, bounded by the representable unit (`|result.data| <= 2^FracBits`).
  ensure:
    result.data >= -((T(1)) shl FracBits) and result.data <= ((T(
        1)) shl FracBits)
  body:
    let piFix = getPiFixedLut[T, FracBits]()
    let twoPiData = piFix.data shl 1
    var a = angle.data

    if a < 0 or a >= twoPiData:
      a = a mod twoPiData
      if a < 0: a += twoPiData

    let lut = getSinLut(T, FracBits)

    when interp == itNone:
      # Index in `uint64`, not the storage type: `a*256` overflows `int16`/
      # `int32` at the higher FracBits the LUT permits. `a` is normalised to
      # `[0, twoPiData)`, so `a*256 < 2^(FracBits+11) < 2^63` fits `uint64`
      # for every permitted `(T, FracBits)`; the quotient is `< 256`.
      let a64 = uint64(a)
      let twoPiU = uint64(twoPiData)
      let idx = int(((a64 * uint64(DefaultLutSize) + (
          twoPiU div 2)) div twoPiU) mod
                    uint64(DefaultLutSize))
      return initFixed[T, FracBits](lut[idx])
    else:
      # Linear interpolation. The numerator `a*256*2^FracBits` is a 128-bit
      # value divided by `twoPi` with `divmod128by64`; the per-entry weight
      # `diff*frac` uses `mulShiftRightSigned`. Both stay exact up to the
      # `FracBits <= 52` limit enforced by `getPiFixedLut`.
      # `verifyFracBits` allows 0, and `p shr (64 - FracBits)` would then shift
      # by the full operand width -- undefined in the generated C.
      static: doAssert FracBits >= 1,
        "itLinear needs FracBits >= 1; use itNone for a Q0 format"
      let p = uint64(a) * uint64(DefaultLutSize)
      let nHi = p shr (64 - FracBits)
      let nLo = p shl FracBits
      let twoPiU = uint64(twoPiData)
      let ratioScaled = int64(divmod128by64(nHi, nLo, twoPiU).quo)
      let idx0 = int(ratioScaled shr FracBits) mod DefaultLutSize
      let idx1 = (idx0 + 1) mod DefaultLutSize

      let frac = int64(uint64(ratioScaled) and ((uint64(1) shl FracBits) - 1))
      let v0 = int64(lut[idx0])
      let v1 = int64(lut[idx1])
      let diff = v1 - v0
      let interpVal = v0 + mulShiftRightSigned(diff, frac, FracBits)
      return initFixed[T, FracBits](T(interpVal))

func cos_lut*[T; FracBits: static[int]](angle: Fixed[T, FracBits];
    interp: static[InterpolationType] = itNone): Fixed[T,
        FracBits] {.contractual.} =
  ## `cos(angle) = sin(angle + pi/2)`. Same bound as `sin_lut`.
  ensure:
    result.data >= -((T(1)) shl FracBits) and result.data <= ((T(
        1)) shl FracBits)
  body:
    # Normalize first, as `sin_lut` does: the range-checked Fixed `+` otherwise
    # raises for any angle within pi/2 of the storage maximum, so the two entry
    # points would accept different domains.
    let piFix = getPiFixedLut[T, FracBits]()
    let twoPiData = piFix.data shl 1
    var a = angle.data mod twoPiData
    if a < default(T): a = a + twoPiData
    return sin_lut(initFixed[T, FracBits](a) +
                   initFixed[T, FracBits](piFix.data shr 1), interp)
