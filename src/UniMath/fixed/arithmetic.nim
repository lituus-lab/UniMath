# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Fixed-point arithmetic. `+`/`-` are integer ops on the data (same scale).
## `*` and `/` use an exact `BigInt` intermediate so the double-width product
## and the pre-scaled dividend never lose bits, then range-check back to `T`.
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

func `/`*[T; FracBits: static[int]](a, b: Fixed[T, FracBits]): Fixed[T,
    FracBits] {.contractual.} =
  ## Quotient via an exact `BigInt` intermediate: `(a.data shl FracBits) div
  ## b.data`, then range-checked back to `T`. Division by zero raises
  ## `DivByZeroDefect` (from the BigInt `div`); `OverflowDefect` if the result
  ## does not fit `T`. No inline `ensure:` (recursion doctrine — see `*`).
  body:
    let bigRes: BigInt = (toBigInt(a.data) shl Natural(FracBits)) div toBigInt(b.data)
    result.data = fromBigIntChecked(bigRes, T)
