# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Fixed-point arithmetic. `+`/`-` are integer ops on the data (same scale).
## `*` and `/` need the double-width product and the pre-scaled dividend to keep
## every bit, then range-check back to `T`.
##
## For BigInt storage that means an exact `BigInt` intermediate. For MACHINE
## storage it does not: the product of two `int64` is 128 bits, which
## `mulWide` produces in registers, and building three `BigInt`s to hold it cost
## 89 ns against 0.8 ns for `Fixed.+`. The signed overload below takes the
## direct route and the generic one keeps the `BigInt` intermediate.
import ./fixed_point
import ../arithmetic
import contracts

# Storage dispatch: lift a storage value to an exact `BigInt` (`BigInt`
# passthrough; signed via `int64`, unsigned via `uint64` so the high bit stays
# unsigned), and narrow a `BigInt` back with an explicit `low(T) .. high(T)`
# range check that raises `OverflowDefect` (all modes). Nim's range-checked
# `T(v)` conversion compiles away under `-d:release` for storage narrower than
# int64/uint64, so relying on it would silently wrap; the body-raise survives.

func toBigInt*(data: BigInt): BigInt {.inline.} = data
func toBigInt*(data: SomeSignedInt): BigInt {.inline.} = fromInt(int64(data))
func toBigInt*(data: SomeUnsignedInt): BigInt {.inline.} = fromUInt(uint64(data))

func fromBigIntChecked*(b: BigInt, T: typedesc[BigInt]): BigInt {.contractual, inline.} =
  ## `BigInt` passthrough (no narrowing, no overflow). Body-only: the result is
  ## the input, so there is no postcondition to assert (recursion doctrine).
  body:
    b

func fromBigIntChecked*(b: BigInt, T: typedesc[
    SomeSignedInt]): T {.contractual.} =
  ## Range-checked narrowing to signed storage. Body-only: the overflow guard
  ## is a domain guard that lives in the body so it survives release/danger.
  body:
    let v = b.toInt64()
    if v < low(T) or v > high(T):
      raise newException(OverflowDefect,
        "fromBigIntChecked: " & $v & " notin " & $low(T) & " .. " & $high(T))
    T(v)

func fromBigIntChecked*(b: BigInt, T: typedesc[
    SomeUnsignedInt]): T {.contractual.} =
  ## Range-checked narrowing to unsigned storage. Body-only — same rationale as
  ## the signed overload.
  body:
    let v = b.toUInt64()
    if v > high(T):
      raise newException(OverflowDefect,
        "fromBigIntChecked: " & $v & " > " & $high(T))
    T(v)

# Overflow-checked same-width storage arithmetic for Fixed `+`/`-`/unary `-`.
# These stay in the storage type (no `BigInt` allocation — fixed-point keeps its
# speed) and only add the overflow guard, so `+`/`-` raise `OverflowDefect` out
# of range just like `*`/`/` (which widen and so use a `BigInt` intermediate).
# `when` selects one branch per `T`, so only the taken branch is type-checked.
func addChk[T](a, b: T): T {.inline.} =
  when T is BigInt:
    result = a + b
  elif T is SomeSignedInt:
    if (b > 0 and a > high(T) - b) or (b < 0 and a < low(T) - b):
      raise newException(OverflowDefect, "Fixed addition overflow")
    result = a + b
  elif T is SomeUnsignedInt:
    if b > high(T) - a:
      raise newException(OverflowDefect, "Fixed addition overflow")
    result = a + b
  else:
    result = a + b

func subChk[T](a, b: T): T {.inline.} =
  when T is BigInt:
    result = a - b
  elif T is SomeSignedInt:
    if (b < 0 and a > high(T) + b) or (b > 0 and a < low(T) + b):
      raise newException(OverflowDefect, "Fixed subtraction overflow")
    result = a - b
  elif T is SomeUnsignedInt:
    if a < b:
      raise newException(OverflowDefect, "Fixed subtraction overflow")
    result = a - b
  else:
    result = a - b

func negChk[T](a: T): T {.inline.} =
  when T is BigInt:
    result = -a
  elif T is SomeSignedInt:
    if a == low(T):
      raise newException(OverflowDefect, "Fixed negation overflow")
    result = -a
  elif T is SomeUnsignedInt:
    if a != 0:
      raise newException(OverflowDefect, "Fixed negation overflow (unsigned)")
    result = a
  else:
    result = -a

func `+`*[T; FracBits: static[int]](a, b: Fixed[T, FracBits]): Fixed[T,
    FracBits] {.contractual, inline.} =
  ## Sum. Same-width integer `+` on the data, overflow-checked (raises
  ## `OverflowDefect` out of range, consistent with `*`/`/`). No inline
  ## `ensure:` (recursion doctrine): the sum identity for `BigInt` storage
  ## would compare via the contracted `cmp`.
  body:
    result.data = addChk(a.data, b.data)

func `-`*[T; FracBits: static[int]](a, b: Fixed[T, FracBits]): Fixed[T,
    FracBits] {.contractual, inline.} =
  ## Difference, overflow-checked (see `+`). No inline `ensure:` (recursion
  ## doctrine — see `+`).
  body:
    result.data = subChk(a.data, b.data)

func `-`*[T; FracBits: static[int]](a: Fixed[T, FracBits]): Fixed[T,
    FracBits] {.contractual, inline.} =
  ## Unary negation, overflow-checked (see `+`). No inline `ensure:` (recursion
  ## doctrine): the zero postcondition for `BigInt` storage delegates to the
  ## contracted `cmp`.
  body:
    result.data = negChk(a.data)


func mulShiftFloor(a, b: int64, k: int): tuple[value: int64, fits: bool] =
  ## `floor(a * b / 2^k)` in 128 bits, and whether it lands inside `int64`.
  ##
  ## FLOOR, not truncation. The `BigInt` route this replaces used `BigInt.shr`,
  ## which is an arithmetic shift, so a negative product rounds AWAY from zero
  ## whenever a bit is dropped. Truncating instead would be an off-by-one on
  ## negative values only -- the kind of difference that hides until it does
  ## not.
  ##
  ## Portable: `mulWide` plus `uint64` shifts. Magnitudes are taken through
  ## `-(x + 1) + 1` so `low(int64)`, where `-x` overflows, is not a special
  ## case.
  let negative = (a < 0) != (b < 0)
  let am = if a < 0: uint64(-(a + 1)) + 1'u64 else: uint64(a)
  let bm = if b < 0: uint64(-(b + 1)) + 1'u64 else: uint64(b)
  var hi: Limb
  let lo = mulWide(am, bm, hi)

  var sh, shHi: uint64
  var dropped: bool
  if k == 0:
    sh = lo; shHi = hi; dropped = false
  elif k < LimbBits:
    sh = (lo shr k) or (hi shl (LimbBits - k))
    shHi = hi shr k
    dropped = (lo and ((1'u64 shl k) - 1)) != 0
  elif k < 2 * LimbBits:
    let k2 = k - LimbBits
    sh = if k2 == 0: hi else: hi shr k2
    shHi = 0
    dropped = lo != 0 or (k2 > 0 and (hi and ((1'u64 shl k2) - 1)) != 0)
  else:
    # Past the width of the product: everything shifts out. Spelled here rather
    # than left to `hi shr k2`, which is undefined once k2 reaches LimbBits.
    # `divShiftTruncPortable` already guards its own shift the same way.
    sh = 0; shHi = 0
    dropped = lo != 0 or hi != 0

  if shHi != 0: return (0'i64, false)

  if negative:
    # floor(-m / 2^k) = -ceil(m / 2^k).
    var mag = sh
    if dropped:
      if mag == high(uint64): return (0'i64, false)
      mag += 1
    if mag > uint64(high(int64)) + 1'u64: return (0'i64, false)
    if mag == uint64(high(int64)) + 1'u64: return (low(int64), true)
    (-int64(mag), true)
  else:
    if sh > uint64(high(int64)): return (0'i64, false)
    (int64(sh), true)

func `*`*[T; FracBits: static[int]](a, b: Fixed[T, FracBits]): Fixed[T,
    FracBits] {.contractual.} =
  ## Product via an exact `BigInt` intermediate: `(a.data * b.data) shr
  ## FracBits`, then range-checked back to `T` (no `float64` detour, which
  ## corrupts values above `2^53`). Raises `OverflowDefect` if the scaled
  ## result does not fit `T`. No inline `ensure:` (recursion doctrine — the
  ## sign postcondition for `BigInt` storage delegates to the contracted `cmp`);
  ## the exact identity is exercised by `test_fixed`.
  body:
    let bigRes: BigInt = (toBigInt(a.data) * toBigInt(b.data)) shr Natural(FracBits)
    result.data = fromBigIntChecked(bigRes, T)

func `*`*[T: SomeSignedInt; FracBits: static[int]](a, b: Fixed[T,
    FracBits]): Fixed[T, FracBits] {.contractual.} =
  ## Product for machine signed storage: one 64x64 -> 128 multiply and a shift,
  ## no `BigInt` intermediate. Identical results to the generic overload --
  ## including the floor rounding of a negative product and every
  ## `OverflowDefect` -- verified over `low`/`high` boundaries and randomised
  ## operands in `test_fixed`.
  body:
    # FracBits reaches the C helpers as a shift count; both are undefined past
    # the width of the 128-bit intermediate. `static[int]` makes this free.
    static: doAssert FracBits >= 0 and FracBits < 2 * LimbBits,
      "Fixed FracBits must be in 0 ..< " & $(2 * LimbBits)
    let r = mulShiftFloor(int64(a.data), int64(b.data), FracBits)
    if not r.fits:
      raise newException(OverflowDefect,
        "Fixed.*: product does not fit int64 storage")
    if r.value < int64(low(T)) or r.value > int64(high(T)):
      raise newException(OverflowDefect,
        "Fixed.*: " & $r.value & " notin " & $low(T) & " .. " & $high(T))
    result.data = T(r.value)


func divShiftTrunc(a, b: int64, k: int): tuple[value: int64, fits: bool] =
  ## `trunc(a * 2^k / b)` in 128 bits, and whether it lands inside `int64`.
  ##
  ## TRUNCATION, not floor -- and deliberately not the same rounding as
  ## `mulShiftFloor`. The `BigInt` route this replaces divides MAGNITUDES and
  ## applies the sign afterwards, so it truncates toward zero, where `BigInt.shr`
  ## in the multiply is an arithmetic shift and floors. The two operators really
  ## do round differently, and matching each one is the point.
  ##
  ## Division by zero raises here, as it did from the `BigInt` divide.
  ##
  ## Where the toolchain has a 128-bit integer, C99's `/` already truncates
  ## toward zero -- 1.60x faster than the explicit `udiv128` below, because the
  ## compiler sees the divisor fits 64 bits and emits a hardware divide instead
  ## of calling libgcc. The body below is the fallback and stays tested under
  ## `-d:noInt128`.
  if b == 0:
    raise newException(DivByZeroDefect, "Fixed./: division by zero")
  when hasInt128:
    var v: int64
    if fixedShiftDiv(a, b, cint(k), v) != 0:
      return (v, true)
    return (0'i64, false)
  let negative = (a < 0) != (b < 0)
  let am = if a < 0: uint64(-(a + 1)) + 1'u64 else: uint64(a)
  let bm = if b < 0: uint64(-(b + 1)) + 1'u64 else: uint64(b)

  # dividend = am << k, as a 128-bit (hi, lo).
  var hi, lo: uint64
  if k == 0:
    hi = 0'u64
    lo = am
  elif k < LimbBits:
    hi = am shr (LimbBits - k)
    lo = am shl k
  else:
    let k2 = k - LimbBits
    if k2 >= LimbBits:
      if am != 0'u64: return (0'i64, false)
      hi = 0'u64
    else:
      if k2 > 0 and (am shr (LimbBits - k2)) != 0'u64: return (0'i64, false)
      hi = am shl k2
    lo = 0'u64

  # `udiv128` needs hi < divisor; otherwise the quotient needs more than 64
  # bits and cannot fit the storage anyway.
  if hi >= bm: return (0'i64, false)
  let (q, _) = udiv128(hi, lo, bm)

  if negative:
    if q > uint64(high(int64)) + 1'u64: return (0'i64, false)
    if q == uint64(high(int64)) + 1'u64: return (low(int64), true)
    (-int64(q), true)
  else:
    if q > uint64(high(int64)): return (0'i64, false)
    (int64(q), true)

func `/`*[T; FracBits: static[int]](a, b: Fixed[T, FracBits]): Fixed[T,
    FracBits] {.contractual.} =
  ## Quotient via an exact `BigInt` intermediate: `(a.data shl FracBits) div
  ## b.data`, then range-checked back to `T`. Division by zero raises
  ## `DivByZeroDefect` (from the BigInt `div`); `OverflowDefect` if the result
  ## does not fit `T`. No inline `ensure:` (recursion doctrine — see `*`).
  body:
    let bigRes: BigInt = (toBigInt(a.data) shl Natural(FracBits)) div toBigInt(b.data)
    result.data = fromBigIntChecked(bigRes, T)

func `/`*[T: SomeSignedInt; FracBits: static[int]](a, b: Fixed[T,
    FracBits]): Fixed[T, FracBits] {.contractual.} =
  ## Quotient for machine signed storage: one 128/64 divide, no `BigInt`
  ## intermediate. Identical results to the generic overload -- including the
  ## truncation toward zero and every `OverflowDefect` -- verified over
  ## boundary and randomised operands in `test_fixed`.
  body:
    # FracBits reaches the C helpers as a shift count; both are undefined past
    # the width of the 128-bit intermediate. `static[int]` makes this free.
    static: doAssert FracBits >= 0 and FracBits < 2 * LimbBits,
      "Fixed FracBits must be in 0 ..< " & $(2 * LimbBits)
    let r = divShiftTrunc(int64(a.data), int64(b.data), FracBits)
    if not r.fits:
      raise newException(OverflowDefect,
        "Fixed./: quotient does not fit int64 storage")
    if r.value < int64(low(T)) or r.value > int64(high(T)):
      raise newException(OverflowDefect,
        "Fixed./: " & $r.value & " notin " & $low(T) & " .. " & $high(T))
    result.data = T(r.value)
