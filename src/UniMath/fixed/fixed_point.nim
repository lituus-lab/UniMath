# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Fixed-point core type. A `Fixed[T, FracBits]` is an integer `data` scaled by
## `2^FracBits`: the stored `data` represents the real value `data / 2^FracBits`.
## `T` is the backing integer (int32, int64, or BigInt) so the same Q-format
## arithmetic spans fixed-precision and arbitrary-precision storage.
import ../arithmetic

type
  Fixed*[T; FracBits: static[int]] = object
    ## Q-format fixed-point number. `T` holds the raw bits; `FracBits` is the
    ## fractional width.
    data*: T

# Compile-time guard on the `Fixed[T, FracBits]` shape: `FracBits` is
# non-negative (a negative width would shift by a negative amount — UB on the
# `shl`/mask). The storage-width limit is NOT enforced here: the LUT path
# deliberately instantiates `Fixed[int16, 20]` and lets the range-checked
# narrowing (`narrowChecked`) raise `OverflowDefect` at runtime, which the
# overflow-guard tests rely on. Mirrors `verifyBits` in `arithmetic/fixed_int`.
template verifyFracBits(T: typedesc; FracBits: static[int]) =
  static: doAssert FracBits >= 0, "FracBits must be non-negative"

func initFixed*[T; FracBits: static[int]](data: T): Fixed[T,
    FracBits] {.inline.} =
  ## Build a fixed-point value from its raw internal representation.
  verifyFracBits(T, FracBits)
  result.data = data

# Overflow-guarded construction. `toFixed` must not silently wrap an
# out-of-range shifted value: the standard integer widths and `BigInt` route
# through an exact `BigInt` intermediate and a range-checked narrowing that
# raises `OverflowDefect` in debug AND release (a body-raise domain guard, not a
# debug-only `require:`). Dispatch is by `typedesc` overload on the storage `T`.

func toBig(val: SomeSignedInt): BigInt {.inline.} =
  initBigInt(val)
func toBig(val: SomeUnsignedInt): BigInt {.inline.} =
  fromUInt(val)

func narrowChecked(b: BigInt; T: typedesc[SomeSignedInt]): T {.inline.} =
  ## Narrow a `BigInt` to signed storage; raise `OverflowDefect` (all modes)
  ## outside `low(T) .. high(T)`.
  let v = b.toInt64()
  if v < low(T) or v > high(T):
    raise newException(OverflowDefect,
      "toFixed: " & $v & " notin " & $low(T) & " .. " & $high(T))
  T(v)
func narrowChecked(b: BigInt; T: typedesc[SomeUnsignedInt]): T {.inline.} =
  ## Narrow a `BigInt` to unsigned storage; raise `OverflowDefect` (all modes)
  ## when negative or above `high(T)`.
  let v = b.toUInt64()
  if v > high(T):
    raise newException(OverflowDefect, "toFixed: " & $v & " > " & $high(T))
  T(v)
func narrowChecked(b: BigInt; T: typedesc[BigInt]): BigInt {.inline.} =
  b

func storeShifted(val: SomeInteger; T: typedesc[SomeSignedInt];
    bits: int): T {.inline.} =
  narrowChecked(toBig(val) shl Natural(bits), T)
func storeShifted(val: SomeInteger; T: typedesc[SomeUnsignedInt];
    bits: int): T {.inline.} =
  narrowChecked(toBig(val) shl Natural(bits), T)
func storeShifted(val: SomeInteger; T: typedesc[BigInt];
    bits: int): BigInt {.inline.} =
  toBig(val) shl Natural(bits)

func bigFromFloat64(f: float64): BigInt =
  ## Exact integer extraction from a finite `float64`, truncating toward zero
  ## (matches Nim's `int(float)` cast). Inf/NaN raise `OverflowDefect`. Lets
  ## `toFixed(SomeFloat)` range-check the scaled value instead of a lossy
  ## `T(scaled)` cast that wraps silently under `-d:danger`.
  let bits = cast[uint64](f)
  let sign = (bits shr 63) != 0
  let rawExp = int((bits shr 52) and 0x7FF'u64)
  let rawMant = bits and ((uint64(1) shl 52) - 1)
  if rawExp == 0x7FF:
    raise newException(OverflowDefect,
      "toFixed: non-finite float (Inf/NaN) has no integer value")
  var mag: BigUInt
  var exp: int
  if rawExp == 0:
    mag = initBigUInt(rawMant)
    exp = -1074
  else:
    mag = initBigUInt(rawMant or (uint64(1) shl 52))
    exp = rawExp - 1075
  var intMag: BigUInt
  if exp >= 0:
    intMag = mag shl Natural(exp)
  else:
    intMag = mag shr Natural(-exp)
  result = initBigInt(intMag, isNegative = sign)

func storeFloat(val: SomeFloat; T: typedesc[SomeSignedInt];
    bits: int): T {.inline.} =
  let scale = pow2f64(bits)
  narrowChecked(bigFromFloat64(val * scale), T)
func storeFloat(val: SomeFloat; T: typedesc[SomeUnsignedInt];
    bits: int): T {.inline.} =
  let scale = pow2f64(bits)
  narrowChecked(bigFromFloat64(val * scale), T)
func storeFloat(val: SomeFloat; T: typedesc[BigInt];
    bits: int): BigInt {.inline.} =
  let scale = pow2f64(bits)
  bigFromFloat64(val * scale)

func toFixed*[T; FracBits: static[int]](val: SomeInteger): Fixed[T, FracBits] =
  ## Build from an integer: `data = val shl FracBits`. Raises `OverflowDefect`
  ## (all modes) when the shifted value does not fit `T`.
  verifyFracBits(T, FracBits)
  result.data = storeShifted(val, T, FracBits)

func toFixed*[T; FracBits: static[int]](val: SomeFloat): Fixed[T, FracBits] =
  ## Build from a float: `data = trunc(val * 2^FracBits)`. The scaled value is
  ## extracted exactly and range-checked against `T`, raising `OverflowDefect`
  ## (all modes) when it does not fit.
  verifyFracBits(T, FracBits)
  result.data = storeFloat(val, T, FracBits)

func toInt*[T; FracBits: static[int]](a: Fixed[T, FracBits]): T {.inline.} =
  ## Integer part (discard fractional bits).
  a.data shr FracBits

func fracPart*[T; FracBits: static[int]](a: Fixed[T, FracBits]): T {.inline.} =
  ## Fractional bits.
  let one = T(1)
  let mask = (one shl FracBits) - one
  a.data and mask

# Concept construction: `fromInt(Fixed[T,FB], n)` / `fromFloat(Fixed[T,FB], f)`
# let generic series bounded by `Field` build coefficients without an injected
# constructor.
func fromInt*[T; FracBits: static[int]](TT: typedesc[Fixed[T, FracBits]];
    v: int): Fixed[T, FracBits] {.inline.} =
  toFixed[T, FracBits](v)

func fromFloat*[T; FracBits: static[int]](TT: typedesc[Fixed[T, FracBits]];
    v: float64): Fixed[T, FracBits] {.inline.} =
  toFixed[T, FracBits](v)

type
  Fixed32* = Fixed[int32, 16] ## Q16.16
  Fixed64* = Fixed[int64, 32] ## Q32.32
  GeoFPN* = Fixed64 ## geographic coordinates (WGS84)
  CartesianFPN* = Fixed[int64, 16] ## Q48.16, cartesian coordinates
  GeometryFPN* = Fixed64 ## default geometry type

# Opt-in narrowing converters (`Fixed64(2)`, `Fixed64(2.0)`). The canonical
# direction is the explicit `toFixed`; implicit conversions across packages
# collide, so they are gated by `-d:umConverters`.
when defined(umConverters):
  converter toFixed64FromInt*(val: SomeInteger): Fixed64 {.inline.} =
    toFixed[int64, 32](val)
  converter toFixed64FromFloat*(val: SomeFloat): Fixed64 {.inline.} =
    toFixed[int64, 32](val)
  converter toFixed32FromInt*(val: SomeInteger): Fixed32 {.inline.} =
    toFixed[int32, 16](val)
  converter toFixed32FromFloat*(val: SomeFloat): Fixed32 {.inline.} =
    toFixed[int32, 16](val)
