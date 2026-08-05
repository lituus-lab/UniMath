# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Chebyshev/minimax polynomial approximation for `tan` on fixed-point. A
## minimax polynomial spreads the error evenly across `[-pi/4, pi/4]` instead
## of concentrating it at the edges like a Taylor series, so it needs fewer
## terms for the same peak error. Range-reduce `x` to `[-pi/4, pi/4]` first.
## The result tracks the true `tan(x)` to the polynomial's design accuracy but
## is not bound by an exact identity, so the core proc is `{.contractual.}` with
## `body:` and no `ensure:` — the precision envelope is verified externally.
import contracts
import ../fixed
import ../arithmetic

# Signed fixed-point `mul` then arithmetic `shr`: fixed-width integers use the
# 128-bit `mulShiftRightSigned` (the product `~2^(2*FracBits)` overflows `int64`
# for `FracBits >= 32`); `BigInt` is arbitrary-precision so native `*` then `shr`
# is exact. A per-storage-type overload set on the storage `T`.
func mulShrSigned*(a, b: SomeInteger, T: typedesc, shift: int): T {.inline.} =
  # Range-checked, not a plain `T(...)` conversion: that wraps in silence under
  # -d:danger, while this layer's guards are documented to survive release.
  let v = mulShiftRightSigned(int64(a), int64(b), shift)
  if v < low(T) or v > high(T):
    raise newException(OverflowDefect,
      "mulShrSigned: " & $v & " notin " & $low(T) & " .. " & $high(T))
  T(v)

func mulShrSigned*(a, b: BigInt, T: typedesc, shift: int): BigInt {.inline.} =
  (a * b) shr shift

func tanChebyshev*[T; FracBits: static[int]](
    x: Fixed[T, FracBits]): Fixed[T, FracBits] {.contractual.} =
  ## `tan(x)` via a minimax polynomial on `[-pi/4, pi/4]`. The coefficient
  ## products use `mulShrSigned` (a 128-bit intermediate for fixed-width
  ## integers, native for `BigInt`) so the `~2^(2*FracBits)` product does not
  ## overflow `int64` for `FracBits >= 32`.
  body:
    mixin fromFloat
    # tan(x) ~ x + C1*x^3 + C2*x^5 + C3*x^7 on [-pi/4, pi/4].
    let scale = float(pow2f64(FracBits))
    let c1 = fromFloat(T, 0.3333314036 * scale)
    let c2 = fromFloat(T, 0.1333923995 * scale)
    let c3 = fromFloat(T, 0.0533740603 * scale)

    let x2 = x * x
    let x3 = x2 * x
    let x5 = x3 * x2
    let x7 = x5 * x2

    let term1 = x
    let term3 = initFixed[T, FracBits](mulShrSigned(x3.data, c1, T, FracBits))
    let term5 = initFixed[T, FracBits](mulShrSigned(x5.data, c2, T, FracBits))
    let term7 = initFixed[T, FracBits](mulShrSigned(x7.data, c3, T, FracBits))
    result = term1 + term3 + term5 + term7
